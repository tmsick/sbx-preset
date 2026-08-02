# Build the sandbox template image and hand it to Docker Sandboxes.
#
# sandboxd keeps its own image store, separate from the host Docker daemon,
# so an image built here stays invisible to sbx until it has been exported
# with `docker save` and imported with `sbx template load`. The tarball is
# only a courier for that handoff; `make clean` throws it away.
#
#   make                                  # build, save and load claude-code
#   make BASE_VARIANT=shell               # the agent-less variant
#   make MISE_VERSION=v2026.8.1           # override the pin in the Dockerfile
#   make build                            # stop after `docker build`
#   sbx run -t sbx-preset:claude-code claude .

IMAGE        ?= sbx-preset
BASE_VARIANT ?= claude-code
TAG          ?= $(BASE_VARIANT)

IMAGE_REF := $(IMAGE):$(TAG)
TMP_DIR   := tmp
TARBALL   := $(TMP_DIR)/$(IMAGE)-$(TAG).tar

# BASE_VARIANT is always forwarded -- the tag is derived from it, so the
# Makefile has to name it anyway. MISE_VERSION is forwarded only when the
# caller sets it, which keeps the pin in the Dockerfile the single source of
# truth instead of duplicating it here.
BUILD_ARGS := --build-arg BASE_VARIANT=$(BASE_VARIANT)
ifdef MISE_VERSION
BUILD_ARGS += --build-arg MISE_VERSION=$(MISE_VERSION)
endif

# A `docker save` killed partway through would otherwise leave a truncated
# tarball that make considers up to date.
.DELETE_ON_ERROR:

.PHONY: all build save load clean

all: load

build:
	docker build $(BUILD_ARGS) -t $(IMAGE_REF) .

save: $(TARBALL)

load: $(TARBALL)
	sbx template load $(TARBALL)

# Depends on the phony build so the tarball always reflects the current
# Dockerfile and preset/; docker's own layer cache keeps that cheap.
$(TARBALL): build | $(TMP_DIR)
	docker save $(IMAGE_REF) -o $@

$(TMP_DIR):
	mkdir -p $@

clean:
	rm -rf $(TMP_DIR)
