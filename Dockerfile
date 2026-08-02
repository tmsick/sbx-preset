# syntax=docker/dockerfile:1

# Custom template for Docker Sandboxes.
# Templates must extend an existing agent environment rather than an
# arbitrary base image, so we FROM docker/sandbox-templates:<variant>
# instead of a generic image. The variant is parameterized so the same
# Dockerfile can build a claude-code-based image or a shell-based one
# (the agent-less variant used by `sbx run shell`).
#
# Defaults to claude-code; pass --build-arg BASE_VARIANT=shell to build
# the agent-less variant used by `sbx run shell` instead.
ARG BASE_VARIANT=claude-code
FROM docker/sandbox-templates:${BASE_VARIANT}

# System package installation must be done as root.
USER root

# The default `sh -c` swallows a mid-pipe failure, so a broken download
# in the `curl | sh` below would still produce a green build. Opt into
# pipefail for the rest of the build.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# curl and ca-certificates are needed by the mise installer.
#
# libatomic1 is needed because pnpm's standalone binary (and some other
# Node.js single-executable builds) dynamically link against
# libatomic.so.1, which isn't part of the minimal Ubuntu base. Without
# it, the binary fails at runtime with "error while loading shared
# libraries: libatomic.so.1: cannot open shared object file".
# See https://github.com/pnpm/pnpm/issues/11531.
RUN apt-get update -y \
    && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    libatomic1 \
    && rm -rf /var/lib/apt/lists/*

# Install mise with the official installer, which is what mise documents
# for container images (its apt repository is aimed at interactive
# workstation use).
#
# Pinned so rebuilding the image doesn't silently pick up a new mise
# release; override with --build-arg MISE_VERSION=... to try another one.
# The installer has no "latest" keyword -- left unset it falls back to a
# release number baked into the script itself, which would tie the build
# to whenever mise.run happened to be fetched. Naming a release other
# than that baked-in one also moves the download from mise's own host to
# GitHub releases; both paths verify a checksum.
ARG MISE_VERSION=v2026.8.0

# MISE_INSTALL_PATH overrides the installer's per-user default of
# ~/.local/bin/mise. This step runs as root, so the default would hide
# the binary in /root; /usr/local/bin is on both root's and agent's PATH.
#
# Both variables are deliberately kept out of the image environment: the
# installer reads them, so an ENV would silently pin and redirect any
# `curl https://mise.run | sh` an agent runs inside the sandbox later.
# ARG is build-only, and the path is scoped to the installer process.
RUN curl -fsSL https://mise.run | MISE_INSTALL_PATH=/usr/local/bin/mise sh \
    && mise --version

# Put mise's shims on PATH for every process in the sandbox.
#
# A shell snippet is not enough here: the base image sources ~/.bashrc
# only from interactive shells, and points BASH_ENV at its own
# /etc/sandbox-persistent.sh, so the non-interactive `bash -c` / `sh -c`
# invocations an agent uses to run commands would miss it. A Dockerfile
# ENV applies to every process regardless of shell.
#
# Tools land in the agent user's home. sbx does not mount over
# /home/agent -- the sandbox rootfs is a single overlay, and only the
# workspace, /var/lib/docker and a few /etc files are bind-mounted --
# so tools installed at build time stay visible at runtime.
ENV PATH="/home/agent/.local/share/mise/shims:${PATH}"

# Shims resolve commands but do not apply mise's [env] variables or
# hooks, so interactive shells still get a real activation. mise
# documents having both as safe.
#
# Runtimes installed later via `mise install` land under
# ~/.local/share/mise, so this part must run as agent, not root.
USER agent
RUN echo 'eval "$(mise activate bash)"' >> /home/agent/.bashrc

# Bake the user's Claude Code preset. preset/ is keyed by agent -- sbx
# supports several -- and preset/claude/ mirrors ~/.claude/, so
# preset/claude/CLAUDE.md and preset/claude/rules/*.md land exactly where
# Claude Code already looks for them and nothing has to be wired up.
# Copying into the existing directory merges, leaving the base image's own
# contents alone.
#
# CLAUDE.md and rules/ are the only parts of ~/.claude that survive into a
# running sandbox. sbx rewrites ~/.claude/settings.json and ~/.claude.json
# when it creates the sandbox, and bind-mounts ~/.claude/skills from the
# store that `sbx skills import` seeds, so settings, MCP servers and skills
# cannot be baked in from here. Settings would have to go to
# /etc/claude-code/managed-settings.json instead, which sbx does not touch.
#
# preset/claude/ holds personal configuration and is gitignored except for
# the .gitkeep that keeps this COPY working on a fresh clone. Its contents
# must be real files: a symlink pointing outside the build context
# (dotfiles, say) is not something Docker can follow.
COPY --chown=agent:agent preset/claude/ /home/agent/.claude/
