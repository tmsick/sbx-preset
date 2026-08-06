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

cd /path/to/project         # then, from the project itself -- see tools/
sbx-init .
sbx run --name claude-project   # attach later, from anywhere
```

Other tasks: `build`, `save`, `clean`, `kit:init`.

Variables (read from the environment): `IMAGE`, `BASE_VARIANT`, `TAG`, `MISE_VERSION`.

```sh
BASE_VARIANT=shell mise run          # the agent-less variant used by `sbx run shell`
MISE_VERSION=v2026.8.1 mise run      # override the pin in the Dockerfile
```

## tools/

`tools/sbx-init` is the everyday entry point. Symlink it onto `PATH` once:

```sh
ln -s "$PWD/tools/sbx-init" ~/bin/sbx-init
```

Creating a sandbox by hand means naming this repository three times over --
`-t sbx-preset:claude-code` plus a `--kit` per kit, all paths inside it -- which
is why it otherwise has to happen from this directory. `sbx-init .` fills all of
that in, so a sandbox gets created from the project it is for:

```sh
sbx-init .                       # the same sbx create, with paths filled in
sbx-init . --profile strict      # unrecognized flags go on to `sbx create`
sbx-init --agent shell .         # picks the matching sbx-preset variant
sbx-init --dry-run .             # print the command instead of running it
```

The repository path is neither typed nor hardcoded: `Path(__file__).resolve()`
follows the symlink, so the script finds the kits from its own real location.
Install it as a symlink, not a hardlink -- a hardlink is just another name for
the file, with no path back here.

`sbx-init allow DOMAIN` adds a domain to `kit/net/` *and* applies the same rule
to the sandbox holding the current directory, which covers both halves of the
problem: the kit reaches an existing sandbox only through `sbx kit add`, and
that recreates its container, while a scoped policy rule takes effect
immediately but is forgotten when the sandbox goes away.

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

`kit/net/` carries a network allowlist rather than files, so the domains this setup
routinely needs stop being a series of `sbx policy allow network` run by hand after
every `sbx create`. Its rules are scoped to the sandbox they were applied to, unlike
`sbx policy allow network` without `--sandbox`, which edits the global policy every
sandbox on the host inherits; `sbx policy ls SANDBOX --source kit` shows them. Only
what `sbx policy init balanced` doesn't already allow belongs here. Unlike the other
two kits it has no `files/`, so the list itself is committed.

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
