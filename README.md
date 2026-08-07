# sbx-preset

A custom [Docker Sandboxes](https://docs.docker.com/ai/sandboxes/) template that adds
[mise](https://mise.jdx.dev/) to the stock agent environment, built from [template/](#template).
Configuration (Claude Code, git, and eventually others) is layered on at sandbox creation time via
a [kit](https://docs.docker.com/ai/sandboxes/customize/), not baked into the image -- see
[kit/](#kit).

## Usage

For your own project, no clone of this repository needed -- see [tools/](#tools):

```sh
curl -fsSL https://raw.githubusercontent.com/tmsick/sbx-preset/main/tools/sbx-init \
  -o ~/bin/sbx-init && chmod +x ~/bin/sbx-init                         # once
sbx settings set kit.allowedSources '["docker.io/","ghcr.io/tmsick/"]'  # once

cd /path/to/project
sbx-init .
sbx run --name claude-project   # attach later, from anywhere
```

To work on this repository itself -- the Dockerfile, `template/config/`, or a kit's
`spec.yaml` -- clone it and run `mise trust` once. Tasks are defined in `mise.toml`:

```sh
mise run                    # build, save and load the template locally
```

Other tasks: `build`, `save`, `clean`.

Variables (read from the environment): `IMAGE`, `BASE_VARIANT`, `TAG`, `MISE_VERSION`.

```sh
BASE_VARIANT=shell mise run          # the agent-less variant used by `sbx run shell`
MISE_VERSION=v2026.8.1 mise run      # override the pin in the Dockerfile
```

## template/

`template/` is the Dockerfile's build context: `template/Dockerfile` plus `template/config/`, the
paths it `COPY`s. Unlike `kit/`, it's committed as-is -- it defines the reproducible toolchain the
image ships with, not personal configuration -- and is what `mise run` builds, saves and loads.

A GitHub Actions workflow ([`.github/workflows/template.yml`](.github/workflows/template.yml))
publishes it to `ghcr.io/tmsick/sbx-preset:<variant>` on every push to `main` -- tagging both
`<variant>` and `<variant>-<sha>` -- and, on a pull request touching `template/`, builds without
pushing, to catch a Renovate `MISE_VERSION` bump that no longer builds. `sbx-init` always
resolves the template from `ghcr.io`; `mise run load` is for trying a local change here before
it's published (`sbx run --template sbx-preset:<variant> claude` against that local build).

`template/config/mise/`, `template/config/fish/` and `template/config/vscode-server/` mirror
`~/.config/mise/`, `~/.config/fish/` and `~/.vscode-server/` inside the image.

`template/config/fish/config.fish` activates mise for interactive shells and sets defaults (editor,
locale, path, aliases) scoped to what actually exists in the image.

`template/config/vscode-server/data/Machine/settings.json` makes fish the default profile for VS
Code's Remote-SSH terminal. Needed on top of the `agent` user's login shell: Docker Sandboxes
forces `SHELL=/bin/bash` into every sandbox at creation time, and that is what both a plain `ssh`
session and VS Code's terminal key off.

## tools/

`tools/sbx-init` composes the `sbx create` call for you -- the template plus all three default
kits, plus whatever `--with` asks for -- so you don't have to type
`-t ghcr.io/tmsick/sbx-preset:claude-code` and a `--kit ghcr.io/tmsick/sbx-preset/...` per kit by
hand. Install it as a plain file; it needs no clone of this repository to run:

```sh
curl -fsSL https://raw.githubusercontent.com/tmsick/sbx-preset/main/tools/sbx-init \
  -o ~/bin/sbx-init && chmod +x ~/bin/sbx-init
```

`sbx` refuses kits from sources it doesn't recognize by default (`kit.allowedSources`); allow
this repository's `ghcr.io` packages once:

```sh
sbx settings set kit.allowedSources '["docker.io/","ghcr.io/tmsick/"]'
```

```sh
sbx-init .                       # sbx create, with the template and kits filled in
sbx-init . --with figma          # plus kit-opt/figma (repeatable, comma-separated)
sbx-init . --profile strict      # unrecognized flags go on to `sbx create`
sbx-init --agent shell .         # picks the matching sbx-preset variant
sbx-init --dry-run .             # print the command instead of running it
```

`sbx-init`'s own kit list (`DEFAULT_KITS`, `OPT_KIT_SERVICES`) mirrors
[`.github/workflows/kits.yml`](.github/workflows/kits.yml)'s publish matrix; the two are kept in
sync by hand, not generated from one source.

There's no `sbx-init allow` shortcut: adding a network domain means editing
[`kit/net/spec.yaml`](kit/net/spec.yaml) directly, in a clone, and letting CI publish it. An
already-running sandbox only picks up the change via `sbx kit add` (which recreates its
container) or a one-off `sbx policy allow network` run by hand.

## kit/

`kit/<name>/` directories are [sbx kits](https://docs.docker.com/ai/sandboxes/customize/):
declarative artifacts applied at sandbox creation (`--kit`) or to a running sandbox (`sbx
kit add`), not baked into the image -- editing a kit takes effect on the next `sbx
create`/`run`, with no image rebuild. Each kit's `spec.yaml` and `files/` (where present)
are committed whole; `sbx kit validate ./kit/<name>/` checks the artifact is well-formed.

Two things to know before running `sbx kit add` by hand:

- **Give it an absolute path.** Adding a kit recreates the container, re-resolving the
  references the sandbox was created with; a relative one resolves against a different
  directory the second time and the recreate fails outright (`./kit/net` came back as
  `$HOME/kit/net`). `sbx-init` sidesteps this entirely -- it passes `ghcr.io` references,
  not paths.
- **Nothing reports which kits a sandbox has.** `sbx ls --json` carries only name, id,
  agent, status and workspaces; `sbx policy ls SANDBOX --source kit` names every rule
  `kit:<sandbox>` and shows merged resources rather than the kits behind them, accumulating
  a row per recreate and saying nothing about a kit that only injects files. Re-adding an
  attached kit is refused (exit 1, `duplicate kit name`) -- the practical way to find out.

The kits themselves:

- `kit/claude/` injects `CLAUDE.md` into `/home/agent/.claude/`. Only `CLAUDE.md` and
  `rules/` are worth injecting this way: `sbx` rewrites `~/.claude/settings.json` and
  `~/.claude.json` itself, and bind-mounts `~/.claude/skills` from the store seeded by
  `sbx skills import`. `CLAUDE.md` itself stays empty, or generic enough for anyone to read.
- `kit/git/` injects `~/.gitconfig` and `~/.gitignore_global` -- deliberately those paths,
  not the XDG-style `~/.config/git/{config,ignore}` a template `COPY` would use. sandboxd's
  `GitConfigCustomizer` forces `core.excludesFile` to `~/.gitignore_global` on every sandbox
  start (merging non-destructively into whatever the kit put there), so an XDG-style ignore
  file is left shadowed and never read. The kit also covers `git init` in the sandbox and
  repos outside the mounted workspace, which `sbx`'s own identity injection -- the local
  `.git/config` of an already-git workspace -- misses. That injection is also where
  `user.name`/`user.email` come from, not this kit, so `.gitconfig` here carries only
  editor/alias/workflow preferences.
- `kit/net/` carries a network allowlist rather than files, so the domains this setup
  routinely needs stop being a series of `sbx policy allow network` run by hand after every
  `sbx create`. Kit rules are scoped to their own sandbox, unlike a global `sbx policy
allow`. The conventions for the list are in its `spec.yaml`.

## kit-opt/

`kit-opt/<service>/` holds the kits only some projects want, attached with `sbx-init .
--with <service>`. Everything in `kit/` goes to every sandbox; nothing in `kit-opt/` goes
anywhere unless it is asked for. Which of the two directories a kit sits in is the whole
difference between them -- no naming convention to remember, and both validate the same way:
`sbx kit validate ./kit/<name>/` takes one `REFERENCE` at a time, not a glob.

They are named after the service (`figma/`, not `net-figma/`) because a kit is a unit of
_capability_, not of mechanism: if Figma later needs an API token as well as network reach,
`environment.variables` goes in the same kit. Splitting by service rather than by project
is deliberate -- a kit per project would not survive two projects wanting Figma.

A GitHub Actions workflow ([`.github/workflows/kits.yml`](.github/workflows/kits.yml)) runs
`sbx kit validate` against every kit in both directories, on pull requests and on push to
`main`, and on push to `main` also publishes every one of them to
`ghcr.io/tmsick/sbx-preset/<path>:latest` (and `:<sha>`).
