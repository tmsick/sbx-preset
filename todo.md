# TODO

- `template/config/fish/config.fish` mixes personal preferences (`EDITOR nvim`, aliases
  for git/nvim/docker/less) into what README documents as template-level config.
  Only `XDG_CONFIG_HOME`, `mise activate fish` and the `fish_add_path` calls are
  actually required; split the rest into a kit, as `kit/claude/` does.

- `mise.toml`'s `IMAGE`/`BASE_VARIANT`/`TAG` overrides (e.g. `BASE_VARIANT=shell mise run`)
  silently don't work once mise has been activated in that shell: its
  `[env]` diff-tracking stomps the override back to the value exported on `cd`.
  `MISE_VERSION` is unaffected, being read directly in the task script
  (`${MISE_VERSION:-}`) rather than through `[env]`. Fix: move the other three
  out of `[env]` and read them the same way.

- `ports.ubuntu.com:3128` is refused 11 times across six sandboxes in the daemon
  log. 3128 is Squid's port, so this reads as apt reaching for a proxy that isn't
  there rather than traffic worth allowing -- confirm before allowlisting it by
  reflex.

- Kits are experimental and their schema moves without a version bump to signal
  it: sbx v0.38.0 renamed `caps.network.*` to `permissions.network.*` and
  `commands.*` to `setup.*`, both still under `schemaVersion: "2"`.
  `.github/workflows/kits.yml` now runs `sbx kit validate` on every PR/push
  touching `kit/` or `kit-opt/`, but only reacts to changes in this repo --
  a schema-breaking sbx release with no accompanying kit edit slips past it
  silently, so `sbx kit validate` is still worth running by hand after
  upgrading sbx locally.

- `tools/sbx-init`'s `DEFAULT_KITS`/`OPT_KIT_SERVICES` and
  `.github/workflows/kits.yml`'s publish matrix list the same six kits by hand
  in two separate places (the point of dropping directory discovery was to let
  `sbx-init` run without a clone, so it can no longer just list `kit/`). Adding
  or removing a kit needs both edited, and nothing catches a missed one --
  `sbx-init` would silently omit a new kit, or offer `--with` a service whose
  ghcr.io package no longer exists.
