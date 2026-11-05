# Local sanity check before pushing: sbx kit validate every kit (or one:
# make validate-mise). To try a kit in a real sandbox, pass its directory to
# sbx instead (see README's Development).
#
#   make validate                              # every kit under kit/
#   make validate-mise                         # one kit
#   make fmt                                   # format the repo with prettier
#   make fmt-check                             # fail if anything is unformatted
#
# fmt runs a pinned prettier through npx; without Node on the host:
#   mise exec node -- make fmt
#
# A kit with a recipe is built to validate it, on the host's Docker (its
# daemon has to be running). To build in sbx's own builder sandbox instead:
#   SBX_KIT_BUILDER=sandbox make validate
# (`sbx kit builder rm` reclaims its build cache afterwards.)
#
# No --offline: sbx can't load a v3 source kit without the daemon. CI
# (.github/workflows/kits.yml) validates by building instead.

PRETTIER_VERSION := 3.9.10
PRETTIER ?= npx --yes prettier@$(PRETTIER_VERSION)

.PHONY: fmt fmt-check
fmt:
	$(PRETTIER) --write .
fmt-check:
	$(PRETTIER) --check .

KITS := $(notdir $(wildcard kit/*))

.PHONY: validate $(KITS:%=validate-%)
validate: $(KITS:%=validate-%)

# kit/ca-trust declares a required arg (the CA cert) that isn't shipped with
# the kit -- a throwaway self-signed cert stands in here, used only to
# satisfy validation.
$(KITS:%=validate-%): validate-%:
	@if [ "$*" = "ca-trust" ]; then \
		cert=$$(mktemp) key=$$(mktemp); \
		openssl req -x509 -newkey rsa:2048 -days 1 -nodes -keyout "$$key" -out "$$cert" -subj "/CN=validate placeholder CA" 2>/dev/null; \
		sbx kit validate ./kit/$* --kit-arg "cert_base64=$$(base64 < "$$cert" | tr -d '\n')"; \
		rm -f "$$cert" "$$key"; \
	else \
		sbx kit validate ./kit/$*; \
	fi
