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

- Add `kit/net/`, a kit carrying the network allowlist, so the typical
  domains stop being a hand-run series of `sbx policy allow network` after
  every `sbx create`. Kits carry network policy, not just files; unlike a
  global `sbx policy allow` the rules stay scoped to the sandbox and, since
  only `files/` is gitignored, the list itself is committed. Verified shape
  (sbx v0.37.1, kit-spec v2):

  ```yaml
  schemaVersion: "2"
  kind: mixin
  name: net-default
  caps:
    network:
      allow: ["*.githubusercontent.com", "registry.npmjs.org:443"]
      deny: ["telemetry.example.com"]
  ```

  Adding domains later is two-tier: `sbx policy allow network --sandbox NAME DOMAIN`
  for a throwaway one (no container recreate), or edit the kit for a
  permanent one -- which reaches an existing sandbox only via `sbx kit add NAME ./kit/net/`,
  and that _does_ recreate the container.

- Add `tools/sbx-init`, symlinked into `~/bin`, so a sandbox can be created
  from the target project's own directory (`sbx-init .`) instead of coming
  back here to type `-t`, `--kit ./kit/claude/`, `--kit ./kit/git/` by hand.
  The repo path stays out of the command line _and_ out of the script: a
  symlinked script resolves its own location (`Path(__file__).resolve()`
  follows the symlink) to find the kits. Must be a symlink, not a hardlink --
  a hardlink has no path back to the repo. Give it an `sbx-init allow DOMAIN`
  subcommand that both appends to `kit/net/spec.yaml` and applies the rule
  live to the sandbox owning the current directory (map cwd to sandbox name
  via `sbx ls --json`).

  Rejected alternatives: a `mise.toml` task (still needs the target path as
  an argument, from this directory); `sbx kit push` to an OCI registry or a
  `git+https://...#dir=` reference (both drop the path entirely and work
  across machines, but publish personal `CLAUDE.md`/`.gitconfig`, need a push
  per edit, and lose the "editing a kit takes effect on the next create"
  property README documents -- worth revisiting if a second machine appears).
  There is no `sbx settings` key for a default template or default kits, so
  a wrapper is the only route.

- `kit/claude/` and `kit/git/` are still `schemaVersion: "1"`. Valid, but v2
  is current; migrate when convenient (v1's `network.allowedDomains` already
  warns and maps to `caps.network.allow`).
