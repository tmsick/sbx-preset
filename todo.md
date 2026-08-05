# TODO

- `config/fish/config.fish` is documented (README.md) as template-level, non-personal
  config, but it currently mixes in user preferences: `EDITOR nvim`, `alias g git`,
  `alias vim nvim`, `alias d docker`, `alias less "less -i"`. Only `XDG_CONFIG_HOME`,
  `mise activate fish`, and the `fish_add_path` calls are actually mechanism-required.
  Consider splitting the personal parts out into a kit (same pattern as `kit/claude/`),
  leaving `config/fish/config.fish` with only what the template itself needs.

- `mise.toml`'s `IMAGE`/`BASE_VARIANT`/`TAG` overrides silently don't work as documented
  in README.md's Usage section, in the normal case of running them from a shell where
  mise is already activated (i.e. any interactive fish shell using this repo's own
  `config/fish/config.fish`, or bash after the Dockerfile's `eval "$(mise activate
bash)"`). Confirmed 2026-08-05 with `mise env` standing in for `mise run` (same env
  resolution path): in a freshly-activated bash session,
  `eval "$(mise activate bash)"; BASE_VARIANT=shell mise env` still reports
  `BASE_VARIANT=claude-code` / `TAG=claude-code`. The same command works correctly when
  mise has _not_ been activated in that shell first -- so this isn't about `get_env()`
  or Tera caching in general (a plain, non-colliding `[env]` var like `FOOBAR` picks up
  overrides fine either way; `[env] cacheable = false` on the affected vars doesn't help
  either).

  Root cause: `mise activate <shell>`'s hook already exports `BASE_VARIANT=claude-code`
  (etc.) into the shell as soon as it evaluates this directory's `[env]` block (e.g. on
  the first prompt after `cd`-ing in), and tracks that export in `__MISE_DIFF` so it can
  be reverted when leaving the directory. When `mise run`/`mise env` is invoked again
  afterward -- even with `BASE_VARIANT=shell` prefixed on that exact command -- mise
  recomputes `[env]` using its diff-tracking and stomps the just-exported override back
  to the value it itself set earlier in the session. A one-off `mise run` in a shell
  where mise was never activated doesn't hit this, which is why the bug is easy to miss
  in ad hoc testing but reliably reproduces in the documented interactive workflow.

  `MISE_VERSION=... mise run` is unaffected because it deliberately bypasses `[env]`
  entirely -- the `build` task reads `${MISE_VERSION:-}` directly from the shell in its
  bash script (see the task's own comment). The same fix should work for
  `IMAGE`/`BASE_VARIANT`/`TAG`: move them out of `[env]` and read them the same way
  (`${IMAGE:-sbx-preset}`, `${BASE_VARIANT:-claude-code}`,
  `${TAG:-$BASE_VARIANT}`) in the `build`/`save`/`load` task scripts, rather than via
  `get_env()` Tera templating.

- No CI workflow builds the image on push/PR. Renovate is configured to auto-bump the
  pinned `MISE_VERSION` in the Dockerfile (`.github/renovate.json`), but nothing
  verifies a bumped version still `docker build`s successfully before merge -- a broken
  or incompatible mise release would only surface the next time someone runs
  `mise run` locally.
