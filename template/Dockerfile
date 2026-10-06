# syntax=docker/dockerfile:1

# Docker Sandboxes template: mise, fish and Neovim on top of the stock agent
# environment. Must extend docker/sandbox-templates:<tag>, not a generic base
# image: the built-in agent (`sbx create claude`) keeps its own configuration
# and launch command and only swaps the image, so the image must be the one
# that agent expects. BASE_VARIANT is passed straight through as the upstream
# tag -- no implicit suffixing -- so it must be a tag docker/sandbox-templates
# actually publishes.
#
# Defaults to claude-code-docker; --build-arg BASE_VARIANT=shell-docker gives
# the agent-less variant used by `sbx create shell`.
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

ARG TARGETARCH

# Releases, pinned so a rebuild doesn't silently pick up a new one; bumped by
# Renovate. No leading `v`: the URLs and installer below add it where needed.
ARG MISE_VERSION=2026.10.3
ARG FISH_VERSION=4.9.3
ARG NVIM_VERSION=0.12.5

# curl/ca-certificates: the downloads below. xz-utils: unpacks fish's
# tarball. libatomic1: needed at runtime by pnpm's standalone binary (and other
# Node.js SEA builds) once mise installs one, and missing on the Ubuntu base
# (https://github.com/pnpm/pnpm/issues/11531).
RUN apt-get update -y \
    && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    libatomic1 \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

# fish from upstream's static build (4.x embeds its functions and
# completions), made the agent user's login shell (usermod, not chsh -- no tty
# at build time).
RUN case "$TARGETARCH" in \
    amd64) fish_arch=x86_64 ;; \
    arm64) fish_arch=aarch64 ;; \
    *) echo "unsupported TARGETARCH: $TARGETARCH" >&2; exit 1 ;; \
    esac \
    && curl -fsSL "https://github.com/fish-shell/fish-shell/releases/download/${FISH_VERSION}/fish-${FISH_VERSION}-linux-${fish_arch}.tar.xz" \
    | tar -xJ -C /usr/local/bin fish \
    && chmod 0755 /usr/local/bin/fish \
    && /usr/local/bin/fish --version \
    && echo /usr/local/bin/fish >> /etc/shells \
    && usermod --shell /usr/local/bin/fish agent

# Neovim from its release tarball, which is self-contained (runtime files,
# parsers) and expects to stay together: kept whole under /opt/nvim, linked
# from /usr/local/bin.
RUN case "$TARGETARCH" in \
    amd64) nvim_arch=x86_64 ;; \
    arm64) nvim_arch=arm64 ;; \
    *) echo "unsupported TARGETARCH: $TARGETARCH" >&2; exit 1 ;; \
    esac \
    && mkdir -p /opt/nvim \
    && curl -fsSL "https://github.com/neovim/neovim/releases/download/v${NVIM_VERSION}/nvim-linux-${nvim_arch}.tar.gz" \
    | tar -xz -C /opt/nvim --strip-components=1 --no-same-owner \
    && ln -s /opt/nvim/bin/nvim /usr/local/bin/nvim \
    && nvim --version | head -1

# mise from its official installer, into a shared path (the installer's
# default ~/.local/bin would land in /root). No tools are baked in: a project
# pins its toolchain in its own mise.toml and installs it in the sandbox.
RUN curl -fsSL https://mise.run \
    | MISE_VERSION="v${MISE_VERSION}" MISE_INSTALL_PATH=/usr/local/bin/mise sh \
    && mise --version

# ENV (not a shell rc file) so shims come first for every process -- including
# the non-interactive bash Claude Code's Bash tool runs -- ahead of the image's
# own /usr/bin/node, python3, ...
ENV PATH="/home/agent/.local/share/mise/shims:${PATH}"

USER agent

# config/fish/ mirrors ~/.config/fish/: config.fish, plus one conf.d/ file
# per tool for its shell integration (mise activation; nvim as EDITOR).
COPY --chown=agent:agent config/fish/ /home/agent/.config/fish/

# `mise activate` (conf.d/mise.fish) wires up shims and env hooks but not
# shell completions -- fish autoloads those from completions/. Generated here
# so they track the pinned MISE_VERSION.
RUN mkdir -p /home/agent/.config/fish/completions \
    && mise completion fish > /home/agent/.config/fish/completions/mise.fish

# Seed VS Code Server's remote settings so its integrated terminal defaults to
# fish: sandboxd forces SHELL=/bin/bash into every sandbox, overriding the
# login shell set above. VS Code Server writes this file only if it's
# missing, so the seed survives untouched into every sandbox.
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
