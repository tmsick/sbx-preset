# docker buildx build every kit (or one: make build-mise), as a local sanity
# check -- the sandbox-kit frontend validates each descriptor as it builds. To
# try a kit in a real sandbox, pass its directory to sbx instead (see README's
# Usage); sbx builds it itself.
#
#   make build                                 # every kit under kit/
#   make build-mise                            # one kit
#   MISE_VERSION=v2026.8.1 make build-mise     # override the pin in mise.dockerfile
#
# Variables are read from the environment or the command line (both forms
# work). Local tag: $(IMAGE)/<kit>:$(TAG). MISE_VERSION has no default here,
# so the Dockerfile's pin stays authoritative.

IMAGE ?= sbx-preset/kit
TAG ?= latest
KITS := $(notdir $(wildcard kit/*))

.PHONY: build $(KITS:%=build-%)
build: $(KITS:%=build-%)

$(KITS:%=build-%): build-%:
	docker buildx build --load \
		$(if $(MISE_VERSION),--build-arg MISE_VERSION=$(MISE_VERSION)) \
		-f kit/$*/$*.yaml -t $(IMAGE)/$*:$(TAG) kit/$*/
