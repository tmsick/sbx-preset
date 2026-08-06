# TODO

- `config/fish/config.fish` mixes personal preferences (`EDITOR nvim`, aliases
  for git/nvim/docker/less) into what README documents as template-level config.
  Only `XDG_CONFIG_HOME`, `mise activate fish` and the `fish_add_path` calls are
  actually required; split the rest into a kit, as `kit/claude/` does.

- `mise.toml`'s `IMAGE`/`BASE_VARIANT`/`TAG` overrides (e.g. `BASE_VARIANT=shell mise run`)
  silently don't work once mise has been activated in that shell: its
  `[env]` diff-tracking stomps the override back to the value exported on `cd`.
  `MISE_VERSION` is unaffected, being read directly in the task script
  (`${MISE_VERSION:-}`) rather than through `[env]`. Fix: move the other three
  out of `[env]` and read them the same way.

- No CI builds the image on push/PR. Renovate auto-bumps the pinned
  `MISE_VERSION` in the Dockerfile, but nothing verifies the bump still
  `docker build`s before merge.

- `ports.ubuntu.com:3128` is refused 11 times across six sandboxes in the daemon
  log. 3128 is Squid's port, so this reads as apt reaching for a proxy that isn't
  there rather than traffic worth allowing -- confirm before allowlisting it by
  reflex.

- Kits are experimental and their schema moves without a version bump to signal
  it: sbx v0.38.0 renamed `caps.network.*` to `permissions.network.*` and
  `commands.*` to `setup.*`, both still under `schemaVersion: "2"`, and
  `kit/net/spec.yaml` stopped validating the moment sbx updated underneath it.
  Nothing catches that until a `sbx create` fails, so `sbx kit validate ./kit/*/`
  belongs in whatever CI ends up being built (see above), and is worth running by
  hand after an sbx update.

- `tools/sbx-init` never publishes the kits, so it only works on this machine's
  clone. A second machine would want `sbx kit push` to an OCI registry or a
  `git+https://...#dir=` reference instead -- both drop the repository path
  entirely, at the cost of publishing personal `CLAUDE.md`/`.gitconfig`, a push
  per edit, and the "editing a kit takes effect on the next create" property
  README documents. `kit.allowedSources` defaults to `["docker.io/"]` and would
  need widening.
