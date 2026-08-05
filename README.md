# sbx-preset

A custom [Docker Sandboxes](https://docs.docker.com/ai/sandboxes/) template that adds
[mise](https://mise.jdx.dev/) to the stock agent environment and bakes in a personal
Claude Code preset.

## Usage

Tasks are defined in `mise.toml`; run `mise trust` once per clone before the first `mise run`.

```sh
mise run                    # build, save and load the template
sbx run -t sbx-preset:claude-code claude .
```

Other tasks: `build`, `save`, `clean`.

Variables (read from the environment): `IMAGE`, `BASE_VARIANT`, `TAG`, `MISE_VERSION`.

```sh
BASE_VARIANT=shell mise run          # the agent-less variant used by `sbx run shell`
MISE_VERSION=v2026.8.1 mise run      # override the pin in the Dockerfile
```

## preset/

`preset/claude/` mirrors `~/.claude/` and is copied into the image. Its contents are
gitignored, and must be real files — Docker cannot follow symlinks out of the build
context.

Only `CLAUDE.md` and `rules/` survive into a running sandbox; `sbx` rewrites
`~/.claude/settings.json` and `~/.claude.json`, and bind-mounts `~/.claude/skills` from
the store seeded by `sbx skills import`.

## config/

`config/mise/` mirrors `~/.config/mise/` and `config/vscode-server/` mirrors
`~/.vscode-server/`; both are copied into the image the same way. Unlike `preset/`,
`config/` is committed: it defines the reproducible toolchain and environment the
template ships with, not personal configuration.

`config/vscode-server/data/Machine/settings.json` sets fish as the default profile
for VS Code's Remote-SSH integrated terminal. This is needed on top of the `agent`
user's login shell: Docker Sandboxes forces `SHELL=/bin/bash` into every sandbox's
environment at creation time, which is what both a plain `ssh` session and VS Code's
terminal actually key off, so the login shell alone doesn't change what a Remote-SSH
terminal opens.
