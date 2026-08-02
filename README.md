# sbx-preset

A custom [Docker Sandboxes](https://docs.docker.com/ai/sandboxes/) template that adds
[mise](https://mise.jdx.dev/) to the stock agent environment and bakes in a personal
Claude Code preset.

## Usage

```sh
make                        # build, save and load the template
sbx run -t sbx-preset:claude-code claude .
```

Other targets: `build`, `save`, `clean`.

Variables: `IMAGE`, `BASE_VARIANT`, `TAG`, `MISE_VERSION`.

```sh
make BASE_VARIANT=shell         # the agent-less variant used by `sbx run shell`
make MISE_VERSION=v2026.8.1     # override the pin in the Dockerfile
```

## preset/

`preset/claude/` mirrors `~/.claude/` and is copied into the image. Its contents are
gitignored, and must be real files — Docker cannot follow symlinks out of the build
context.

Only `CLAUDE.md` and `rules/` survive into a running sandbox; `sbx` rewrites
`~/.claude/settings.json` and `~/.claude.json`, and bind-mounts `~/.claude/skills` from
the store seeded by `sbx skills import`.
