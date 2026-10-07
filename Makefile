# Local sanity check before pushing: sbx kit validate every kit (or one:
# make validate-mise). To try a kit in a real sandbox, pass its directory to
# sbx instead (see README's Development).
#
#   make validate                              # every kit under kit/
#   make validate-mise                         # one kit

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
