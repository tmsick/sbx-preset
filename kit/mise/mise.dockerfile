# syntax=docker/dockerfile:1

# mise, the tools config/mise/config.toml asks for, and mise's shell
# integration, staged under /out and copied onto scratch (README's ## kit/ has
# the overlay rules this follows).
#
# The build stage uses the same base Docker's agent workloads build on
# (sbx-kit-claude's com.docker.sandboxes.base label), so mise's precompiled
# runtimes link against the glibc they will run on.
FROM docker/sandbox-templates:shell-docker AS build

USER root
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Pinned so a rebuild doesn't silently pick up a new release.
ARG MISE_VERSION=v2026.9.14

# libatomic1: needed at runtime by pnpm's standalone binary (and other Node.js
# SEA builds), missing on the Ubuntu base
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
    && cp -a /out/usr/local/bin/mise /usr/local/bin/ \
    && mise --version

# Runtimes land under ~/.local/share/mise, so mise install must run as agent.
USER agent
ENV PATH="/home/agent/.local/share/mise/shims:${PATH}"

# config/ mirrors ~/.config/: mise's global config, and conf.d/mise.fish, which
# activates mise in fish.
COPY --chown=agent:agent config/ /home/agent/.config/

# Install everything in config.toml now, rather than on first `mise install`
# inside the sandbox. `mise activate` doesn't wire up completions -- fish
# autoloads those from completions/. Generated here so they track whatever
# MISE_VERSION is pinned above.
RUN mise install \
    && mkdir -p /home/agent/.config/fish/completions \
    && mise completion fish > /home/agent/.config/fish/completions/mise.fish

# Stage the home tree: /out and /home stay root's, every level from
# /home/agent down stays the agent's.
USER root
RUN mkdir -p /out/home/agent/.local/share \
    && cp -a /home/agent/.config /out/home/agent/ \
    && cp -a /home/agent/.local/share/mise /out/home/agent/.local/share/ \
    && chown -R 1000:1000 /out/home/agent \
    && chown 0:0 /out /out/home \
    && chown -R 0:0 /out/usr

FROM scratch
COPY --from=build /out/ /
# Appended to the workload's PATH at assembly, so the workload's own
# /usr/bin/node, python3, ... still win outside a shell that ran `mise
# activate` or sourced /etc/sandbox-persistent.sh (see mise.yaml). Still
# makes the tools the workload lacks (nvim, bat, usage, ...) reachable
# everywhere.
ENV PATH="/home/agent/.local/share/mise/shims"
