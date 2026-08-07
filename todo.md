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

- `tools/sbx-init` still reads kits as local filesystem paths (`kit/<name>/`,
  `kit-opt/<service>/`), so a second machine needs this repository checked out
  either way. All six kits now publish to `ghcr.io/tmsick/sbx-preset/<path>` on
  push to `main` (`.github/workflows/kits.yml`), so a clone-free path is
  possible -- `sbx kit add ghcr.io/tmsick/sbx-preset/kit/net:latest` -- but
  `kit.allowedSources` defaults to `["docker.io/"]` and would need ghcr.io
  added first, and `tools/sbx-init` would need to grow a ghcr.io-based mode to
  actually use it instead of the local paths.
