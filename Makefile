# Local sanity checks before pushing. Neither produces a runnable sandbox: see
# README's "## template/" for why, and for how to actually try a change.
#
#   make build                                 # docker build claude-code-docker
#   BASE_VARIANT=shell-docker make build       # the agent-less variant
#   MISE_VERSION=2026.8.1 make build           # override a pin in the Dockerfile
#   make validate                              # sbx kit validate every kit
#
# Variables are read from the environment or the command line (both forms
# work). Local tag: $(IMAGE)/$(BASE_VARIANT):$(TAG). MISE_VERSION,
# FISH_VERSION and NVIM_VERSION have no default here, so the Dockerfile's pins
# stay authoritative.

IMAGE ?= sbx-preset
BASE_VARIANT ?= claude-code-docker
TAG ?= latest
KITS := $(wildcard kit/*)

.PHONY: build validate
build:
	docker build --build-arg BASE_VARIANT=$(BASE_VARIANT) \
		$(if $(MISE_VERSION),--build-arg MISE_VERSION=$(MISE_VERSION)) \
		$(if $(FISH_VERSION),--build-arg FISH_VERSION=$(FISH_VERSION)) \
		$(if $(NVIM_VERSION),--build-arg NVIM_VERSION=$(NVIM_VERSION)) \
		-f template/Dockerfile -t $(IMAGE)/$(BASE_VARIANT):$(TAG) template/

validate:
	@for kit in $(KITS); do sbx kit validate "./$$kit" || exit 1; done
