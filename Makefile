# Local sanity check before pushing: sbx kit validate every kit (or one:
# make validate-mise). To try a kit in a real sandbox, pass its directory to
# sbx instead (see README's Development).
#
#   make validate                              # every kit under kit/
#   make validate-mise                         # one kit

KITS := $(notdir $(wildcard kit/*))

.PHONY: validate $(KITS:%=validate-%)
validate: $(KITS:%=validate-%)

$(KITS:%=validate-%): validate-%:
	sbx kit validate ./kit/$*
