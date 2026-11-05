# syntax=docker/dockerfile:1

# fish from upstream's static build, plus its configuration, staged under /out
# and copied onto scratch (README's ## kit/ has the overlay rules this
# follows).
FROM debian:trixie-slim AS build

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG TARGETARCH
# Supplied by the frontend from fish.yaml's `version` arg -- the one place the
# release is pinned. No default here, so a build outside the frontend fails
# rather than guessing.
ARG FISH_VERSION

# 4.x's static build embeds its functions and completions. xz-utils unpacks
# the tarball. Upstream publishes no checksum or signature for this asset (the
# .asc covers only the source tarball), so TLS to github.com is the only
# integrity check; the version re-read is a sanity check, not verification.
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl xz-utils \
    && rm -rf /var/lib/apt/lists/* \
    && case "$TARGETARCH" in \
    amd64) fish_arch=x86_64 ;; \
    arm64) fish_arch=aarch64 ;; \
    *) echo "unsupported TARGETARCH: $TARGETARCH" >&2; exit 1 ;; \
    esac \
    && mkdir -p /out/usr/local/bin \
    && curl --proto '=https' --tlsv1.2 -fsSL "https://github.com/fish-shell/fish-shell/releases/download/${FISH_VERSION:?}/fish-${FISH_VERSION}-linux-${fish_arch}.tar.xz" \
    | tar -xJ --no-same-owner -C /out/usr/local/bin fish \
    && chmod 0755 /out/usr/local/bin/fish \
    && /out/usr/local/bin/fish --version | grep -qF "${FISH_VERSION}"

# files/home/ mirrors ~/: .config/fish/config.fish. /out and /home stay root's,
# every level from /home/agent down stays the agent's.
COPY files/home/ /out/home/agent/
RUN chown -R 1000:1000 /out/home/agent \
    && chown 0:0 /out /out/home \
    && chown -R 0:0 /out/usr

FROM scratch
COPY --from=build /out/ /
