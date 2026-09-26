# syntax=docker/dockerfile:1

# mise and its fish integration, staged under /out and copied onto scratch
# (README's ## kit/ has the overlay rules this follows). No tools are baked
# in: install them in the sandbox as a project needs them.
#
# The build stage uses the same Ubuntu base Docker's agent workloads build on
# (sbx-kit-claude's com.docker.sandboxes.base label), so the libatomic lifted
# below matches the glibc it will run against.
FROM docker/sandbox-templates:shell-docker AS build

USER root
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Pinned so a rebuild doesn't silently pick up a new release.
ARG MISE_VERSION=v2026.9.14

# libatomic1: needed at runtime by pnpm's standalone binary (and other Node.js
# SEA builds) once mise installs one, and missing on the Ubuntu base
# (https://github.com/pnpm/pnpm/issues/11531). Installed here only to lift its
# shared object out.
RUN apt-get update -y \
    && apt-get install -y --no-install-recommends libatomic1 \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /out \
    && cp -a --parents $(dpkg -L libatomic1 | grep '/libatomic\.so') /out/

# Official installer, into a shared path (its default ~/.local/bin would land
# in /root). MISE_VERSION reaches it as an env var.
RUN mkdir -p /out/usr/local/bin \
    && curl -fsSL https://mise.run | MISE_INSTALL_PATH=/out/usr/local/bin/mise sh \
    && /out/usr/local/bin/mise --version

# config/ mirrors ~/.config/: conf.d/mise.fish activates mise in fish.
# `mise activate` doesn't wire up completions -- fish autoloads those from
# completions/, generated here so they track the pinned MISE_VERSION. /out and
# /home stay root's, every level from /home/agent down stays the agent's.
COPY config/ /out/home/agent/.config/
RUN mkdir -p /out/home/agent/.config/fish/completions \
    && /out/usr/local/bin/mise completion fish > /out/home/agent/.config/fish/completions/mise.fish \
    && chown -R 1000:1000 /out/home/agent \
    && chown 0:0 /out /out/home \
    && chown -R 0:0 /out/usr

FROM scratch
COPY --from=build /out/ /
# Appended to the workload's PATH at assembly, so the workload's own
# /usr/bin/node, python3, ... still win outside a shell that ran `mise
# activate` or sourced /etc/sandbox-persistent.sh (see mise.yaml).
ENV PATH="/home/agent/.local/share/mise/shims"
