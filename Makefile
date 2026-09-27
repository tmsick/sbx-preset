# docker buildx build every kit (or one: make build-mise), as a local sanity
# check -- the sandbox-kit frontend validates each descriptor as it builds. To
# try a kit in a real sandbox, pass its directory to sbx instead (see README's
# Usage); sbx builds it itself.
#
#   make build                                 # every kit under kit/
#   make build-mise                            # one kit
#   KIT_VERSION=2026.8.1 make build-mise       # override the kit's `version` arg
#
# Variables are read from the environment or the command line (both forms
# work). Local tag: $(IMAGE)/<kit>:$(TAG). KIT_VERSION has no default here, so
# each descriptor's pin stays authoritative; it reaches the kits that declare
# a `version` arg (mise, fish, nvim) and is ignored by the rest. Not plain
# VERSION: that name is common enough in environments to leak in unasked.

IMAGE ?= sbx-preset/kit
TAG ?= latest
KITS := $(notdir $(wildcard kit/*))

.PHONY: build $(KITS:%=build-%)
build: $(KITS:%=build-%)

$(KITS:%=build-%): build-%:
	docker buildx build --load \
		$(if $(KIT_VERSION),--build-arg version=$(KIT_VERSION)) \
		-f kit/$*/$*.yaml -t $(IMAGE)/$*:$(TAG) kit/$*/
