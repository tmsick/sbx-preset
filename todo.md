# TODO

- `config/fish/config.fish` is documented (README.md) as template-level, non-personal
  config, but it currently mixes in user preferences: `EDITOR nvim`, `alias g git`,
  `alias vim nvim`, `alias d docker`, `alias less "less -i"`. Only `XDG_CONFIG_HOME`,
  `mise activate fish`, and the `fish_add_path` calls are actually mechanism-required.
  Consider splitting the personal parts out into a kit (same pattern as `kit/claude/`),
  leaving `config/fish/config.fish` with only what the template itself needs.
