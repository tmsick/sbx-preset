# sbx-preset

A custom [Docker Sandboxes](https://docs.docker.com/ai/sandboxes/) template that adds
[mise](https://mise.jdx.dev/) to the stock agent environment. Personal configuration
(Claude Code, git, and eventually others) is layered on top at sandbox creation time
via a [kit](https://docs.docker.com/ai/sandboxes/customize/), not baked into the image
-- see [kit/](#kit).

## Usage

Tasks are defined in `mise.toml`; run `mise trust` once per clone before the first `mise run`.

```sh
mise run                    # build, save and load the template
sbx run -t sbx-preset:claude-code claude --kit ./kit/claude/ --kit ./kit/git/ .
```

Other tasks: `build`, `save`, `clean`, `kit:init`.

Variables (read from the environment): `IMAGE`, `BASE_VARIANT`, `TAG`, `MISE_VERSION`.

```sh
BASE_VARIANT=shell mise run          # the agent-less variant used by `sbx run shell`
MISE_VERSION=v2026.8.1 mise run      # override the pin in the Dockerfile
```

## kit/

`kit/<name>/` directories are [sbx kits](https://docs.docker.com/ai/sandboxes/customize/)
— declarative artifacts applied at sandbox creation (`--kit`) or to a running sandbox
(`sbx kit add`), not baked into the image. Personal, per-user configuration belongs
here rather than in `config/`: unlike an image rebuild, editing a kit's files takes
effect on the next `sbx create`/`run` with no `mise run` needed.

Each kit's `spec.yaml` is committed; `files/` (the actual personal content) is
gitignored. `sbx kit validate ./kit/<name>/` checks the artifact is well-formed.
Run `mise run kit:init` once per clone to scaffold the `files/home/` dirs, then
drop `CLAUDE.md`, `.gitconfig` and `.gitignore_global` straight in.

`kit/claude/` injects `files/home/.claude/CLAUDE.md` to `/home/agent/.claude/CLAUDE.md`.
Only `CLAUDE.md` and `rules/` are worth injecting this way; `sbx` rewrites
`~/.claude/settings.json` and `~/.claude.json` itself, and bind-mounts `~/.claude/skills`
from the store seeded by `sbx skills import`, so those cannot be usefully seeded from
here.

`kit/git/` injects `files/home/.gitconfig` and `files/home/.gitignore_global` --
deliberately those paths, not the XDG-style `~/.config/git/{config,ignore}` a template
`COPY` would use. sandboxd's own `GitConfigCustomizer` forces `core.excludesFile` to
`~/.gitignore_global` on every sandbox start, non-destructively merging into whatever a
kit put there first; landing content at `~/.config/git/{config,ignore}` instead leaves
it shadowed, since `core.excludesFile` always wins and that file is never read. It also
covers `git init` in the sandbox or any repo outside the mounted workspace -- `sbx` only
injects identity into an already-git workspace's local `.git/config`.

## config/

`config/mise/` mirrors `~/.config/mise/`, `config/fish/` mirrors `~/.config/fish/`
and `config/vscode-server/` mirrors `~/.vscode-server/`; all three are copied into
the image the same way. Unlike `kit/`, `config/` is committed: it defines the
reproducible toolchain and environment the template ships with, not personal
configuration.

`config/fish/config.fish` activates mise for interactive fish shells and sets a
handful of environment-appropriate defaults (editor, locale, path, aliases)
scoped to what actually exists in the image.

`config/vscode-server/data/Machine/settings.json` sets fish as the default profile
for VS Code's Remote-SSH integrated terminal. This is needed on top of the `agent`
user's login shell: Docker Sandboxes forces `SHELL=/bin/bash` into every sandbox's
environment at creation time, which is what both a plain `ssh` session and VS Code's
terminal actually key off, so the login shell alone doesn't change what a Remote-SSH
terminal opens.
