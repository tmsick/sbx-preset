# sbx-preset

A custom [Docker Sandboxes](https://docs.docker.com/ai/sandboxes/) template that adds
[mise](https://mise.jdx.dev/) to the stock agent environment, built from [template/](#template).
Personal configuration (Claude Code, git, and eventually others) is layered on at sandbox creation
time via a [kit](https://docs.docker.com/ai/sandboxes/customize/), not baked into the image -- see
[kit/](#kit).

## Usage

Tasks are defined in `mise.toml`; run `mise trust` once per clone.

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

## template/

`template/` is the Dockerfile's build context: `template/Dockerfile` plus `template/config/`, the
paths it `COPY`s. Unlike `kit/`, it's committed as-is -- it defines the reproducible toolchain the
image ships with, not personal configuration -- and is what `mise run` builds, saves and loads.

`template/config/mise/`, `template/config/fish/` and `template/config/vscode-server/` mirror
`~/.config/mise/`, `~/.config/fish/` and `~/.vscode-server/` inside the image.

`template/config/fish/config.fish` activates mise for interactive shells and sets defaults (editor,
locale, path, aliases) scoped to what actually exists in the image.

`template/config/vscode-server/data/Machine/settings.json` makes fish the default profile for VS
Code's Remote-SSH terminal. Needed on top of the `agent` user's login shell: Docker Sandboxes
forces `SHELL=/bin/bash` into every sandbox at creation time, and that is what both a plain `ssh`
session and VS Code's terminal key off.

## tools/

`tools/sbx-init` is the everyday entry point. Symlink it onto `PATH` once:

```sh
ln -s "$PWD/tools/sbx-init" ~/bin/sbx-init
```

By hand, creating a sandbox names this repository three times over -- `-t
sbx-preset:claude-code` plus a `--kit` per kit -- which is why it otherwise has to happen
from this directory. `sbx-init` fills those paths in, so a sandbox gets created from the
project it is for:

```sh
sbx-init .                       # the same sbx create, with paths filled in
sbx-init . --with figma          # plus kit-opt/figma/ (repeatable, comma-separated)
sbx-init . --profile strict      # unrecognized flags go on to `sbx create`
sbx-init --agent shell .         # picks the matching sbx-preset variant
sbx-init --dry-run .             # print the command instead of running it
```

It finds the repository from its own real location (`Path(__file__).resolve()` follows the
symlink), so install it as a symlink -- a hardlink is just another name for the file, with
no path back here.

`sbx-init allow DOMAIN` adds a domain to `kit/net/` _and_ applies the same rule to the
sandbox holding the current directory. Both halves are needed: the kit reaches an existing
sandbox only through `sbx kit add`, which recreates its container, while a scoped policy
rule takes effect immediately but is forgotten when the sandbox goes away. `--with figma`
writes to `kit-opt/figma/` instead.

## kit/

`kit/<name>/` directories are [sbx kits](https://docs.docker.com/ai/sandboxes/customize/):
declarative artifacts applied at sandbox creation (`--kit`) or to a running sandbox (`sbx
kit add`), not baked into the image. Personal, per-user configuration belongs here rather
than in `template/` -- editing a kit takes effect on the next `sbx create`/`run`, with no
image rebuild.

Each kit's `spec.yaml` is committed; `files/` (the personal content) is gitignored. Run
`mise run kit:init` once per clone to scaffold the `files/home/` dirs, then drop
`CLAUDE.md`, `.gitconfig` and `.gitignore_global` straight in. `sbx kit validate
./kit/<name>/` checks the artifact is well-formed.

Two things to know before running `sbx kit add` by hand:

- **Give it an absolute path.** Adding a kit recreates the container, re-resolving the
  references the sandbox was created with; a relative one resolves against a different
  directory the second time and the recreate fails outright (`./kit/net` came back as
  `$HOME/kit/net`). `sbx-init` passes absolute paths for this reason.
- **Nothing reports which kits a sandbox has.** `sbx ls --json` carries only name, id,
  agent, status and workspaces; `sbx policy ls SANDBOX --source kit` names every rule
  `kit:<sandbox>` and shows merged resources rather than the kits behind them, accumulating
  a row per recreate and saying nothing about a kit that only injects files. Re-adding an
  attached kit is refused (exit 1, `duplicate kit name`) -- the practical way to find out.

The kits themselves:

- `kit/claude/` injects `CLAUDE.md` into `/home/agent/.claude/`. Only `CLAUDE.md` and
  `rules/` are worth injecting this way: `sbx` rewrites `~/.claude/settings.json` and
  `~/.claude.json` itself, and bind-mounts `~/.claude/skills` from the store seeded by
  `sbx skills import`.
- `kit/git/` injects `~/.gitconfig` and `~/.gitignore_global` -- deliberately those paths,
  not the XDG-style `~/.config/git/{config,ignore}` a template `COPY` would use. sandboxd's
  `GitConfigCustomizer` forces `core.excludesFile` to `~/.gitignore_global` on every sandbox
  start (merging non-destructively into whatever the kit put there), so an XDG-style ignore
  file is left shadowed and never read. The kit also covers `git init` in the sandbox and
  repos outside the mounted workspace, which `sbx`'s own identity injection -- the local
  `.git/config` of an already-git workspace -- misses.
- `kit/net/` carries a network allowlist rather than files, so the domains this setup
  routinely needs stop being a series of `sbx policy allow network` run by hand after every
  `sbx create`. Kit rules are scoped to their own sandbox, unlike a global `sbx policy
allow`. The conventions for the list are in its `spec.yaml`; having no `files/`, it is
  committed whole.

## kit-opt/

`kit-opt/<service>/` holds the kits only some projects want, attached with `sbx-init .
--with <service>`. Everything in `kit/` goes to every sandbox; nothing in `kit-opt/` goes
anywhere unless it is asked for. Which of the two directories a kit sits in is the whole
difference between them -- no naming convention to remember, and `sbx kit validate ./kit/*/
./kit-opt/*/` covers both.

They are named after the service (`figma/`, not `net-figma/`) because a kit is a unit of
_capability_, not of mechanism: if Figma later needs an API token as well as network reach,
`environment.variables` goes in the same kit. Splitting by service rather than by project
is deliberate -- a kit per project would not survive two projects wanting Figma.
