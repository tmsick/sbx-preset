# Local sanity check before pushing: sbx kit validate every kit (or one:
# make validate-mise). To try a kit in a real sandbox, pass its directory to
# sbx instead (see README's Development).
#
#   make validate                              # every kit under kit/
#   make validate-mise                         # one kit
#   make fmt                                   # format the repo with prettier
#   make fmt-check                             # fail if anything is unformatted
#   make setup-context7                        # register context7 on this host
#
# setup-context7 is not a repo task: it writes host-global sbx state (the MCP
# server and skill that kits can't carry; see README's Usage) and is safe to
# rerun.
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

# sbx detects the server's OAuth metadata, so the first run prints an
# authorization URL to open in a browser (interactive); the tokens stay on the
# host. Re-authorize with `sbx mcp auth context7`.
#
# Only context7-mcp: the upstream find-docs and context7-cli skills drive the
# ctx7 CLI through npx, and the sandbox image ships no Node.js. Upstream ships
# identical copies of context7-mcp under several paths, so sbx warns about
# duplicates; harmless.
.PHONY: setup-context7
setup-context7:
	sbx mcp inspect context7 >/dev/null 2>&1 || sbx mcp add context7 --url https://mcp.context7.com/mcp
	sbx skills add upstash/context7 --skill context7-mcp --force

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
