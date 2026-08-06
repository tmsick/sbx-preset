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

- `ports.ubuntu.com:3128` is refused 11 times across six sandboxes in the
  daemon log. 3128 is Squid's port, so this reads as apt reaching for a
  proxy that isn't there rather than traffic worth allowing -- worth
  confirming before it gets allowlisted by reflex.

- `kit/net/` is one allowlist for every sandbox, and `tools/sbx-init` hands
  every kit under `kit/` to every `sbx create`, so a domain only one project
  needs (figma for a frontend, asana for another) cannot be expressed
  without granting it everywhere.

  Split by service rather than by project -- `kit/net-figma/`,
  `kit/net-asana/` -- and attach the ones a sandbox needs. That is the
  granularity kits are designed for: the documented mixin use cases are
  per-capability ("grant the agent access to a new authenticated service"),
  the distribution tooling is `sbx kit push`/`pull`/`pack` with
  `kit.allowedSources` defaulting to `["docker.io/"]`, and the built-in
  agent kits work the same way -- claude's brings `api.anthropic.com`. A kit
  per project would not survive two projects wanting figma.

  That needs `kits()` to stop meaning "everything in `kit/`": a default set
  plus opt-in ones, with a thin per-project record of which extras to
  attach (a `.sbx/kits` in the target project naming them, say) so the kits
  themselves stay here. `sbx-init allow` also writes the shared kit
  unconditionally today and would need to target the right one.

  Nothing is blocked meanwhile: unknown flags already reach `sbx create`, so
  `sbx-init . --kit /path/to/kit` works now, and `sbx policy allow network --sandbox NAME`
  covers a throwaway.

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
