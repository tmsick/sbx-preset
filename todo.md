# TODO

- `config/fish/config.fish` mixes personal preferences (`EDITOR nvim`, aliases
  for git/nvim/docker/less) into what README documents as template-level,
  non-personal config. Only `XDG_CONFIG_HOME`, `mise activate fish`, and the
  `fish_add_path` calls are actually required. Split the personal parts into
  a kit (same pattern as `kit/claude/`).

- `mise.toml`'s `IMAGE`/`BASE_VARIANT`/`TAG` overrides (e.g. `BASE_VARIANT=shell mise run`)
  silently don't work once mise has been activated in that shell --
  its `[env]` diff-tracking stomps the override back to the value it exported
  on `cd`. `MISE_VERSION` is unaffected because it's read directly in the task
  script (`${MISE_VERSION:-}`) instead of through `[env]`. Fix: move
  `IMAGE`/`BASE_VARIANT`/`TAG` out of `[env]` and read them the same way.

- No CI builds the image on push/PR. Renovate auto-bumps the pinned
  `MISE_VERSION` in the Dockerfile, but nothing verifies the bump still
  `docker build`s before merge.

- git over SSH is blocked in sandboxes and nothing in `kit/net/` fixes it
  yet. `balanced` allows `github.com:443` but no port 22, and the daemon log
  has the refusals to prove it: `20.27.177.113:22` (a github.com address)
  denied twice for the `claude-sbx-preset` sandbox. Note what got logged is
  an **IP literal**, not a hostname -- for raw SSH the proxy has no SNI or
  CONNECT line to read a name from, so an allow rule on `github.com:22` may
  simply never match, and `ssh.github.com:443` is the same raw protocol on a
  different port rather than a way around it. Work out what the policy
  engine can actually match on before adding anything.

  The same log also has `ports.ubuntu.com:3128` refused 11 times across six
  sandboxes. 3128 is Squid's port, so this reads as apt reaching for a proxy
  that isn't there rather than traffic worth allowing -- worth confirming
  before it gets allowlisted by reflex.

- Kits are experimental and their schema moves without a version bump to
  signal it: sbx v0.38.0 renamed `caps.network.*` to `permissions.network.*`
  and `commands.*` to `setup.*`, both still under `schemaVersion: "2"`, and
  `kit/net/spec.yaml` stopped validating the moment sbx updated underneath
  it. Nothing catches that until a `sbx create` fails, so `sbx kit validate ./kit/*/`
  belongs in whatever CI ends up being built (see the item above
  about no CI), and is worth running by hand after an sbx update.

- `tools/sbx-init` never publishes the kits, so it only works on this
  machine's clone. A second machine would want `sbx kit push` to an OCI
  registry or a `git+https://...#dir=` reference instead -- both drop the
  repository path entirely, at the cost of publishing personal
  `CLAUDE.md`/`.gitconfig`, a push per edit, and the "editing a kit takes
  effect on the next create" property README documents. Also note
  `kit.allowedSources` defaults to `["docker.io/"]` and would need widening.
