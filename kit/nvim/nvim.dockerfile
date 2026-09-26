# syntax=docker/dockerfile:1

# Neovim from its release tarball, plus its fish integration, staged under /out
# and copied onto scratch (README's ## kit/ has the overlay rules this
# follows).
FROM docker/sandbox-templates:shell-docker AS build

USER root
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG TARGETARCH
# Pinned so a rebuild doesn't silently pick up a new release.
ARG NVIM_VERSION=0.12.5

# The tarball is self-contained (runtime files, parsers) and expects to stay
# together, so it goes to /opt/nvim with a link from /usr/local/bin -- one the
# overlay itself resolves.
RUN case "$TARGETARCH" in \
    amd64) nvim_arch=x86_64 ;; \
    arm64) nvim_arch=arm64 ;; \
    *) echo "unsupported TARGETARCH: $TARGETARCH" >&2; exit 1 ;; \
    esac \
    && mkdir -p /out/opt/nvim /out/usr/local/bin \
    && curl -fsSL "https://github.com/neovim/neovim/releases/download/v${NVIM_VERSION}/nvim-linux-${nvim_arch}.tar.gz" \
    | tar -xz -C /out/opt/nvim --strip-components=1 \
    && ln -s /opt/nvim/bin/nvim /out/usr/local/bin/nvim \
    && /out/opt/nvim/bin/nvim --version | head -1

# config/ mirrors ~/.config/: conf.d/nvim.fish. /out and /home stay root's,
# every level from /home/agent down stays the agent's; the release tarball's
# own owner is handed to root.
COPY config/ /out/home/agent/.config/
RUN chown -R 1000:1000 /out/home/agent \
    && chown 0:0 /out /out/home \
    && chown -R 0:0 /out/opt /out/usr

FROM scratch
COPY --from=build /out/ /
