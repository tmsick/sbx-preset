# TODO

- `template/config/fish/config.fish` mixes personal preferences (`EDITOR nvim`, aliases
  for git/nvim/docker/less) into what README documents as template-level config.
  Only `XDG_CONFIG_HOME`, `mise activate fish` and the `fish_add_path` calls are
  actually required; split the rest into a kit, as `kit/claude/` does.

- `ports.ubuntu.com:3128` is refused 11 times across six sandboxes in the daemon
  log. 3128 is Squid's port, so this reads as apt reaching for a proxy that isn't
  there rather than traffic worth allowing -- confirm before allowlisting it by
  reflex.

- Kits are experimental and their schema moves without a version bump to signal
  it: sbx v0.38.0 renamed `caps.network.*` to `permissions.network.*` and
  `commands.*` to `setup.*`, both still under `schemaVersion: "2"`.
  `.github/workflows/kits.yml` now runs `sbx kit validate` on every PR/push
  touching `kit/`, but only reacts to changes in this repo --
  a schema-breaking sbx release with no accompanying kit edit slips past it
  silently, so `sbx kit validate` is still worth running by hand after
  upgrading sbx locally.
