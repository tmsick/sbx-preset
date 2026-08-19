# syntax=docker/dockerfile:1

# Custom Docker Sandboxes template: mise on top of the stock agent environment.
# Must extend docker/sandbox-templates:<tag>, not a generic base image.
# BASE_VARIANT is passed straight through as the upstream tag -- no implicit
# suffixing -- so it must be a tag docker/sandbox-templates actually publishes.
#
# Defaults to claude-code-docker; --build-arg BASE_VARIANT=shell-docker gives
# the agent-less variant used by `sbx run shell`.
#
# The `-docker` tags are the ones that matter for `sbx create`/`run`: only
# they bake in a full Docker Engine (privileged mode, dedicated
# /var/lib/docker volume, dockerd autostart), the same one those commands use
# by default. The plain tags (`claude-code`, `shell`) exist upstream too but
# drop Docker entirely -- pass one only if you know you don't need nested
# Docker.
ARG BASE_VARIANT=claude-code-docker
FROM docker/sandbox-templates:${BASE_VARIANT} AS base

USER root

# Opt into pipefail so a broken `curl | sh` below still fails the build.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# curl/ca-certificates: mise installer. libatomic1: needed at runtime by pnpm's
# standalone binary (and other Node.js SEA builds), missing on the minimal
# Ubuntu base (https://github.com/pnpm/pnpm/issues/11531). fish: the sandbox's
# default shell, set below. direnv: deliberately apt, not mise -- mise's own
# docs say not to manage direnv through mise, since both hook PATH per
# directory and can conflict (https://mise.jdx.dev/direnv.html).
RUN apt-get update -y \
    && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    libatomic1 \
    fish \
    direnv \
    && rm -rf /var/lib/apt/lists/*

# Make fish the agent user's shell (usermod, not chsh -- no tty at build time).
RUN usermod --shell /usr/bin/fish agent
ENV SHELL=/usr/bin/fish

# Official installer, per mise's guidance for containers. Pinned so a rebuild
# doesn't silently pick up a new release; override with --build-arg
# MISE_VERSION=... to try another one.
ARG MISE_VERSION=v2026.8.9

# Install as root into a shared path (the installer's default ~/.local/bin
# would land in /root). Kept as ARG, not ENV, so it doesn't leak into the image
# and redirect a later `curl https://mise.run | sh` run by an agent.
RUN curl -fsSL https://mise.run | MISE_INSTALL_PATH=/usr/local/bin/mise sh \
    && mise --version

# ENV (not a shell rc file) so shims are on PATH for every process, including
# the non-interactive bash/sh an agent's tools invoke.
ENV PATH="/home/agent/.local/share/mise/shims:${PATH}"

# Runtimes land under ~/.local/share/mise, so mise install below must run as
# agent.
USER agent

# config/fish/ mirrors ~/.config/fish/ (fish has no config.fish until we add one).
COPY --chown=agent:agent config/fish/ /home/agent/.config/fish/

# config/mise/ mirrors ~/.config/mise/, mise's default global config location.
COPY --chown=agent:agent config/mise/ /home/agent/.config/mise/

# Install everything pinned in config.toml now, rather than on first
# `mise install` inside the sandbox.
RUN mise install

# `mise activate` (in config.fish) wires up shims and env hooks but not shell
# completions -- fish autoloads those from completions/. Generated here so they
# track whatever MISE_VERSION is pinned above.
RUN mkdir -p /home/agent/.config/fish/completions \
    && mise completion fish > /home/agent/.config/fish/completions/mise.fish

# Seed VS Code Server's remote settings so its integrated terminal defaults to
# fish: sandboxd forces SHELL=/bin/bash into every sandbox at creation,
# overriding both this image's ENV SHELL and the usermod above. VS Code Server
# writes this file only if it's missing, so the seed survives untouched into
# every sandbox.
COPY --chown=agent:agent config/vscode-server/ /home/agent/.vscode-server/

# claude-code's CMD launches `claude` directly; override to fish only for the
# shell variants. CMD can't branch on ARG directly, so pick the stage instead.
FROM base AS final-claude-code
FROM base AS final-claude-code-docker
FROM base AS final-shell
CMD ["fish"]
FROM base AS final-shell-docker
CMD ["fish"]

FROM final-${BASE_VARIANT} AS final
