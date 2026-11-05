# syntax=docker/dockerfile:1

# mise and its fish integration, staged under /out and copied onto scratch
# (README's ## kit/ has the overlay rules this follows). No tools are baked
# in: install them in the sandbox as a project needs them.
#
# The build stage is only a place to run curl and mise; it needs no match with
# the workload's base.
FROM debian:trixie-slim AS build

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG TARGETARCH
# Supplied by the frontend from mise.yaml's `version` arg -- the one place the
# release is pinned -- without the `v` the release URL adds. No default here,
# so a build outside the frontend fails rather than guessing.
ARG MISE_VERSION

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl minisign \
    && rm -rf /var/lib/apt/lists/*

# The release binary straight from GitHub, into a shared path, checked the way
# mise documents for a manual download (https://mise.jdx.dev/installing-mise.html):
# the minisign signature on SHASUMS256.txt, then the binary against it. The
# public key is mise's own, also published as minisign.pub in its repository.
RUN case "$TARGETARCH" in \
    amd64) mise_arch=x64 ;; \
    arm64) mise_arch=arm64 ;; \
    *) echo "unsupported TARGETARCH: $TARGETARCH" >&2; exit 1 ;; \
    esac \
    && asset="mise-v${MISE_VERSION:?}-linux-${mise_arch}" \
    && base="https://github.com/jdx/mise/releases/download/v${MISE_VERSION}" \
    && mkdir -p /tmp/mise /out/usr/local/bin \
    && cd /tmp/mise \
    && curl --proto '=https' --tlsv1.2 -fsSL -O "$base/SHASUMS256.txt" -O "$base/SHASUMS256.txt.minisig" -O "$base/$asset" \
    && minisign -Vm SHASUMS256.txt -P RWTC3g8W3z4RZK3V3qv7fa1QY4JEWyBtqIHW+85QlJpZc5yG+uNYNBSZ \
    && grep " ./${asset}\$" SHASUMS256.txt | sha256sum -c - \
    && install -m 0755 "$asset" /out/usr/local/bin/mise \
    && rm -rf /tmp/mise \
    && /out/usr/local/bin/mise --version | grep -qF "${MISE_VERSION}"

# files/home/ mirrors ~/: .config/fish/conf.d/mise.fish activates mise in fish.
# `mise activate` doesn't wire up completions -- fish autoloads those from
# completions/, generated here so they track the pinned MISE_VERSION. /out and
# /home stay root's, every level from /home/agent down stays the agent's.
COPY files/home/ /out/home/agent/
RUN mkdir -p /out/home/agent/.config/fish/completions \
    && /out/usr/local/bin/mise completion fish > /out/home/agent/.config/fish/completions/mise.fish \
    && test -s /out/home/agent/.config/fish/completions/mise.fish \
    && chown -R 1000:1000 /out/home/agent \
    && chown 0:0 /out /out/home \
    && chown -R 0:0 /out/usr

FROM scratch
COPY --from=build /out/ /
# Appended to the workload's PATH at assembly, so the workload's own tools
# still win outside a shell that ran `mise activate` or sourced
# /etc/sandbox-persistent.sh (see mise.yaml).
ENV PATH="/home/agent/.local/share/mise/shims"
