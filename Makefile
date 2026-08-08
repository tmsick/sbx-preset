# docker build the template image, as a local sanity check before pushing.
#
# sandboxd keeps its own image store, separate from the host Docker daemon, so
# this build is invisible to `sbx` -- there's no local path from here to a
# runnable sandbox. Push and let CI publish it, then pull from ghcr.io to try
# it (see README).
#
#   make build                                # docker build claude-code-docker
#   BASE_VARIANT=shell-docker make build       # the agent-less variant
#   MISE_VERSION=v2026.8.1 make build          # override the pin in the Dockerfile
#
# Variables are read from the environment or the command line (both
# `FOO=bar make build` and `make build FOO=bar` work). The resulting local tag
# is $(IMAGE)/$(BASE_VARIANT):$(TAG), mirroring the ghcr.io layout CI
# publishes to. MISE_VERSION has no default here, so the Dockerfile's pin
# stays authoritative.

IMAGE ?= sbx-preset
BASE_VARIANT ?= claude-code-docker
TAG ?= latest

.PHONY: build
build:
	docker build --build-arg BASE_VARIANT=$(BASE_VARIANT) \
		$(if $(MISE_VERSION),--build-arg MISE_VERSION=$(MISE_VERSION)) \
		-f template/Dockerfile -t $(IMAGE)/$(BASE_VARIANT):$(TAG) template/
