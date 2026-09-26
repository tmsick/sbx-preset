# syntax=docker/dockerfile:1

# fish from upstream's static build, plus its configuration, staged under /out and copied onto scratch (README's ## kit/
# has the overlay rules this follows).
FROM docker/sandbox-templates:shell-docker AS build

USER root
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG TARGETARCH
# Pinned so a rebuild doesn't silently pick up a new release.
ARG FISH_VERSION=4.9.3

# 4.x's static build embeds its functions and completions. xz-utils unpacks
# the tarball.
RUN apt-get update -y \
    && apt-get install -y --no-install-recommends xz-utils \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /out/usr/local/bin \
    && case "$TARGETARCH" in \
    amd64) fish_arch=x86_64 ;; \
    arm64) fish_arch=aarch64 ;; \
    *) echo "unsupported TARGETARCH: $TARGETARCH" >&2; exit 1 ;; \
    esac \
    && curl -fsSL "https://github.com/fish-shell/fish-shell/releases/download/${FISH_VERSION}/fish-${FISH_VERSION}-linux-${fish_arch}.tar.xz" \
    | tar -xJ -C /out/usr/local/bin fish \
    && chmod 0755 /out/usr/local/bin/fish \
    && /out/usr/local/bin/fish --version

# config/fish/ and config/vscode-server/ mirror ~/.config/fish/ and
# ~/.vscode-server/. /out and /home stay root's, every level from /home/agent
# down stays the agent's.
COPY config/fish/ /out/home/agent/.config/fish/
COPY config/vscode-server/ /out/home/agent/.vscode-server/
RUN chown -R 1000:1000 /out/home/agent \
    && chown 0:0 /out /out/home \
    && chown -R 0:0 /out/usr

FROM scratch
COPY --from=build /out/ /
