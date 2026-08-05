# syntax=docker/dockerfile:1

# Custom template for Docker Sandboxes: adds mise on top of the stock agent
# environment. Must extend docker/sandbox-templates:<variant> rather than a
# generic base image. Defaults to claude-code; pass --build-arg
# BASE_VARIANT=shell for the agent-less variant used by `sbx run shell`.
ARG BASE_VARIANT=claude-code
FROM docker/sandbox-templates:${BASE_VARIANT} AS base

USER root

# Opt into pipefail so a broken `curl | sh` below still fails the build.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# curl/ca-certificates: mise installer. libatomic1: required at runtime by
# pnpm's standalone binary (and other Node.js SEA builds); missing on the
# minimal Ubuntu base (see https://github.com/pnpm/pnpm/issues/11531).
# fish: the sandbox's default shell, set below.
RUN apt-get update -y \
    && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    libatomic1 \
    fish \
    && rm -rf /var/lib/apt/lists/*

# Make fish the agent user's shell (usermod, not chsh -- no tty at build time).
RUN usermod --shell /usr/bin/fish agent
ENV SHELL=/usr/bin/fish

# Official installer, per mise's own guidance for containers. Pinned so a
# rebuild doesn't silently pick up a new release; override with
# --build-arg MISE_VERSION=... to try another one.
ARG MISE_VERSION=v2026.8.0

# Install as root into a shared path (the installer's default ~/.local/bin
# would land in /root). Kept as ARG, not ENV, so it doesn't leak into the
# image and redirect a later `curl https://mise.run | sh` run by an agent.
RUN curl -fsSL https://mise.run | MISE_INSTALL_PATH=/usr/local/bin/mise sh \
    && mise --version

# ENV (not a shell rc file) so shims are on PATH for every process, including
# the non-interactive bash/sh an agent's tools invoke.
ENV PATH="/home/agent/.local/share/mise/shims:${PATH}"

# Shims alone don't apply mise's [env]/hooks, so interactive shells still need
# real activation (mise documents having both as safe). Runtimes land under
# ~/.local/share/mise, so this must run as agent.
USER agent
RUN echo 'eval "$(mise activate bash)"' >> /home/agent/.bashrc

# config/fish/ mirrors ~/.config/fish/ (fish has no config.fish until we add one).
COPY --chown=agent:agent config/fish/ /home/agent/.config/fish/

# config/mise/ mirrors ~/.config/mise/, mise's default global config location.
# Committed (unlike kit/, which is per-user and gitignored): this is the
# template's own reproducible toolchain, not personal config.
COPY --chown=agent:agent config/mise/ /home/agent/.config/mise/

# Installs everything pinned in config.toml at build time so it's ready
# immediately rather than on first `mise install` inside the sandbox.
RUN mise install

# `mise activate` (in config.fish) only wires up shims/env hooks, not shell
# completions -- fish needs its own script autoloaded from completions/.
# Generated at build time so it tracks whatever MISE_VERSION is pinned above.
RUN mkdir -p /home/agent/.config/fish/completions \
    && mise completion fish > /home/agent/.config/fish/completions/mise.fish

# Seed VS Code Server's remote settings so its integrated terminal defaults to
# fish. Needed because sandboxd forces SHELL=/bin/bash into every sandbox at
# creation, overriding both this image's ENV SHELL and the usermod above; VS
# Code Server only writes this file if it's missing, so seeding it here
# survives untouched into every sandbox (same mechanism Dev Containers uses
# for customizations.vscode.settings).
COPY --chown=agent:agent config/vscode-server/ /home/agent/.vscode-server/

# claude-code's CMD launches `claude` directly; override to fish only for the
# shell variant. CMD can't branch on ARG directly, so pick the stage instead.
FROM base AS final-claude-code
FROM base AS final-shell
CMD ["fish"]

FROM final-${BASE_VARIANT} AS final
