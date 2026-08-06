# TODO

- `config/fish/config.fish` mixes personal preferences (`EDITOR nvim`, aliases
  for git/nvim/docker/less) into what README documents as template-level,
  non-personal config. Only `XDG_CONFIG_HOME`, `mise activate fish`, and the
  `fish_add_path` calls are actually required. Split the personal parts into
  a kit (same pattern as `kit/claude/`).

- `mise.toml`'s `IMAGE`/`BASE_VARIANT`/`TAG` overrides (e.g. `BASE_VARIANT=shell
mise run`) silently don't work once mise has been activated in that shell --
  its `[env]` diff-tracking stomps the override back to the value it exported
  on `cd`. `MISE_VERSION` is unaffected because it's read directly in the task
  script (`${MISE_VERSION:-}`) instead of through `[env]`. Fix: move
  `IMAGE`/`BASE_VARIANT`/`TAG` out of `[env]` and read them the same way.

- No CI builds the image on push/PR. Renovate auto-bumps the pinned
  `MISE_VERSION` in the Dockerfile, but nothing verifies the bump still
  `docker build`s before merge.

- `kit/net/`'s allowlist only carries context7 so far -- the domains that had
  been added to the *global* policy by hand, which is how they were found.
  Anything else this setup routinely needs should move here as it comes up
  (`sbx-init allow DOMAIN`), and the two global `context7.com` rules can then
  be dropped with `sbx policy rm`.

- `tools/sbx-init` never publishes the kits, so it only works on this
  machine's clone. A second machine would want `sbx kit push` to an OCI
  registry or a `git+https://...#dir=` reference instead -- both drop the
  repository path entirely, at the cost of publishing personal
  `CLAUDE.md`/`.gitconfig`, a push per edit, and the "editing a kit takes
  effect on the next create" property README documents. Also note
  `kit.allowedSources` defaults to `["docker.io/"]` and would need widening.
