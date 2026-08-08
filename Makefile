# docker build the template image, as a local sanity check before pushing.
# It never becomes a runnable sandbox -- see README's "## template/" for why,
# and for how to actually try a change.
#
#   make build                                # docker build claude-code-docker
#   BASE_VARIANT=shell-docker make build       # the agent-less variant
#   MISE_VERSION=v2026.8.1 make build          # override the pin in the Dockerfile
#
# Variables are read from the environment or the command line (both forms
# work). Local tag: $(IMAGE)/$(BASE_VARIANT):$(TAG). MISE_VERSION has no
# default here, so the Dockerfile's pin stays authoritative.

IMAGE ?= sbx-preset
BASE_VARIANT ?= claude-code-docker
TAG ?= latest

.PHONY: build
build:
	docker build --build-arg BASE_VARIANT=$(BASE_VARIANT) \
		$(if $(MISE_VERSION),--build-arg MISE_VERSION=$(MISE_VERSION)) \
		-f template/Dockerfile -t $(IMAGE)/$(BASE_VARIANT):$(TAG) template/
