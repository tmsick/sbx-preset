# sbx-preset

A [Docker Sandboxes](https://docs.docker.com/ai/sandboxes/) template that adds
[mise](https://mise.jdx.dev/), fish and Neovim to Docker's stock Claude Code image
([template/](#template)), plus [kits](https://docs.docker.com/ai/sandboxes/customize/kits/) (v2)
for configuration and per-service network access ([kit/](#kit)).

## Usage

For your own project, no clone of this repository needed:

```sh
sbx settings set kit.allowedSources '["docker.io/","ghcr.io/tmsick/"]'  # once

cd /path/to/project   # a git repository
sbx create --clone \
  -t ghcr.io/tmsick/sbx-preset/claude-code-docker:latest \
  --kit ghcr.io/tmsick/sbx-preset/kit/claude-config:latest \
  --kit ghcr.io/tmsick/sbx-preset/kit/git:latest \
  --kit ghcr.io/tmsick/sbx-preset/kit/context7:latest \
  claude .
```

`-t` swaps only the image: the built-in `claude` agent keeps its own configuration and launch
command, which is why the template extends Docker's `claude-code-docker` image rather than
replacing it.

`--clone` gives the agent its own clone of the repository inside the sandbox, at the same path,
instead of bind-mounting the working tree, which is too slow to work in. The host repository gets
a `sandbox-<name>` remote to fetch the agent's branches from (`git fetch sandbox-<name>`) while
the sandbox is running; the host's own remotes are copied into the clone, so the agent can also
push to them directly. `--clone` is fixed at creation.

The sandbox is named `claude-<directory>` by default (see `sbx ls`); pass `--name` to choose
another.

Add `--kit ghcr.io/tmsick/sbx-preset/kit/<service>:latest` for a project that needs one (see
[kit/](#kit)), at creation or later with `sbx kit add <sandbox> <reference>`, which recreates the
sandbox's container.

Work in the sandbox from VS Code (and its Claude Code extension) over SSH:

```sh
sbx setup ssh   # once, and again if a new sandbox's host isn't found
code --remote "ssh-remote+claude-$(basename "$PWD").sbx" "$PWD"
```

These are v2 kits on the built-in agent, not v3 kits on a v3 workload such as
`docker.io/docker/sbx-kit-claude`: the two formats don't compose with each other, and the v3
format was still changing in place under released sbx versions. The `v3-snapshot` tag holds this
repository's last v3 state, the starting point for moving back.

## Development

To work on this repository itself, clone it. Tasks are defined in `Makefile`:

```sh
make build                                 # docker build the template image
BASE_VARIANT=shell-docker make build       # the agent-less variant used by `sbx create shell`
MISE_VERSION=2026.8.1 make build           # override a pin in the Dockerfile
make validate                              # sbx kit validate every kit
```

Variables (read from the environment or the command line): `IMAGE`, `BASE_VARIANT`, `TAG`,
`MISE_VERSION`, `FISH_VERSION`, `NVIM_VERSION`.

sandboxd keeps its own image store, separate from the host Docker daemon's, so a `make build`
image has to be loaded into it before a sandbox can use it. A kit directory can be passed to sbx
as is (use absolute paths):

```sh
docker save sbx-preset/claude-code-docker:latest -o template.tar
sbx template load template.tar
sbx create --pull never -t docker.io/sbx-preset/claude-code-docker:latest \
  --kit "$PWD/kit/git" claude /path/to/project
sbx template rm docker.io/sbx-preset/claude-code-docker:latest   # when done
```

## template/

`template/` is the Dockerfile's build context: `template/Dockerfile` plus `template/config/`, the
paths it `COPY`s. It extends `docker/sandbox-templates:<BASE_VARIANT>` (`claude-code-docker` by
default) with:

- mise, from its official installer, with its shims first on `PATH` (an image `ENV`, so every
  process gets them -- including the non-interactive bash Claude Code's Bash tool runs -- ahead
  of the image's own `/usr/bin/node`, `python3`, ...). No tools are baked in: install them in the
  sandbox as a project needs them (`mise install` against the project's own `mise.toml`, or `mise
  use`); a project pins its toolchain and sets its environment variables (`[env]`) there.
- fish, from upstream's static build (4.x embeds its functions and completions), as the `agent`
  user's login shell.
- Neovim, from its release tarball (kept whole under `/opt/nvim`, linked from `/usr/local/bin`).
  No nvim configuration ships with it.
- `libatomic1`, which pnpm's standalone binary (and other Node.js SEA builds) needs once mise
  installs one, and which the Ubuntu base lacks.

The three releases are pinned as `ARG`s in the Dockerfile and bumped by Renovate.

`template/config/fish/` mirrors `~/.config/fish/`. `config.fish` sets defaults (locale, path,
aliases) scoped to what actually exists in the sandbox; each tool's shell integration sits in a
`conf.d/` file of its own: `mise.fish` (`mise activate fish`) and `nvim.fish` (`EDITOR`,
`VISUAL`, `vim`). git follows `EDITOR`: the git kit sets no `core.editor`. Outside fish --
Claude Code's Bash tool -- `EDITOR` stays unset, which is fine for an agent that never opens an
editor.

`template/config/vscode-server/data/Machine/settings.json` makes fish the default profile for VS
Code's Remote-SSH terminal. Needed on top of the login shell: Docker Sandboxes forces
`SHELL=/bin/bash` into every sandbox, and that is what both a plain `ssh` session and VS Code's
terminal key off.

A GitHub Actions workflow ([`.github/workflows/template.yml`](.github/workflows/template.yml))
builds `claude-code-docker` and `shell-docker` for `linux/amd64` and `linux/arm64` on pull
requests touching `template/`, and on push to `main` also publishes them to
`ghcr.io/tmsick/sbx-preset/<variant>`, tagged `:latest` and `:<sha>`.

## kit/

`kit/<name>/` directories are [v2 kits](https://docs.docker.com/ai/sandboxes/customize/kits/):
declarative artifacts applied at sandbox creation (`--kit`) or to an existing sandbox (`sbx kit
add`), not baked into the image -- editing a kit takes effect on the next `sbx create`, with no
image rebuild. Each kit is a `spec.yaml` plus, where it injects files, a `files/` tree
(`files/home/` lands in `/home/agent/`).

Two things to know before running `sbx kit add` by hand:

- **Give it an absolute path.** Adding a kit recreates the container, re-resolving the
  references the sandbox was created with; a relative one resolves against a different
  directory the second time and the recreate fails outright (`./kit/git` came back as
  `$HOME/kit/git`). A `ghcr.io` reference (see Usage) sidesteps this entirely -- it isn't a
  path.
- **Nothing reports which kits a sandbox has.** `sbx ls --json` carries only name, id, agent,
  status and workspaces; `sbx policy ls SANDBOX --source kit` names every rule `kit:<sandbox>`
  and shows merged resources rather than the kits behind them, and says nothing about a kit that
  only injects files. Re-adding an attached kit is refused (`duplicate kit name`) -- the
  practical way to find out.

`claude-config`, `git` and `context7` are what the Usage quickstart attaches by default --
generic enough to want on every sandbox. `asana`, `atlassian` and `figma` are network access for
one service each, worth adding only when a project actually talks to it. `playwright` is
different again -- it installs a browser and registers an MCP server rather than just opening
network access. There's no directory split between these groups: every kit is attached the same
way, an explicit `--kit` flag, so which ones a project needs is a call made per `sbx create`, not
encoded in the repository layout.

Kits are named after the capability they provide (`figma/`, not `net-figma/`), not the mechanism
they happen to use today: if Figma later needs an API token as well as network reach,
`environment.variables` goes into the same `kit/figma/`, not a new kit. Splitting by service
rather than by project is deliberate too -- a kit per project would not survive two projects
wanting Figma.

Network allowlist conventions, for every kit that declares `permissions.network.allow`: rules
from a kit are scoped to the sandbox it was applied to, unlike `sbx policy allow network` without
`--sandbox`, which edits the global policy every sandbox on this host inherits (`sbx policy ls
SANDBOX --source kit` shows the ones from kits). Only what `sbx policy init balanced` doesn't
already cover belongs in a kit -- it ships ~190 allow entries (github, npm, pypi, crates.io,
ubuntu, docker registries, the agent APIs, ...); check with `sbx policy ls --type network
--decision allow --json` first. Grow a list from evidence, not guesses: an entry nobody has been
blocked on is network reach handed to every agent for nothing -- `sbx policy log [SANDBOX]`
reports what the proxy actually refused. Entries take an optional `:PORT` suffix; without one,
every port is allowed, and `**.` covers the domain itself plus any depth of subdomain (`*.` is
exactly one label and excludes the apex). Adding a domain means editing the kit's `spec.yaml`, in
a clone, and letting CI publish it; an existing sandbox only picks up the change via `sbx kit
add` or a one-off `sbx policy allow network` run by hand.

The kits:

- `kit/claude-config/` injects `CLAUDE.md` into `/home/agent/.claude/` -- Claude Code's user
  memory, loaded into every session. Only `CLAUDE.md` and `rules/` are worth injecting this way:
  `sbx` rewrites `~/.claude/settings.json` and `~/.claude.json` itself. `CLAUDE.md` stays empty,
  or generic enough for anyone to read.
- `kit/git/` injects `~/.gitconfig` and `~/.gitignore_global` -- deliberately those paths, not
  the XDG-style `~/.config/git/{config,ignore}`. sandboxd forces `core.excludesFile` to
  `~/.gitignore_global` on every sandbox start (merging non-destructively into whatever the kit
  put there), so an XDG-style ignore file is left shadowed and never read. The kit also covers
  `git init` in the sandbox and repos outside the mounted workspace, which `sbx`'s own identity
  injection -- the local `.git/config` of an already-git workspace -- misses. That injection is
  also where `user.name`/`user.email` come from, not this kit, so `.gitconfig` here carries only
  alias/workflow preferences. It grants no network permissions: `balanced` already covers
  github.com:443, and this preset's remotes are HTTPS-only (no SSH port 22).
- `kit/context7/` allows `**.context7.com:443` -- library/API documentation lookups, used
  routinely enough by this setup's Claude Code config to warrant it on every sandbox.
- `kit/asana/`, `kit/atlassian/` and `kit/figma/` each allow only the domains that one service
  needs.
- `kit/playwright/` installs Chromium at creation and registers `@playwright/mcp` with Claude
  Code at every sandbox start, so browser automation runs as a subprocess of `claude` itself,
  inside the sandbox -- unlike `sbx mcp add --command`, whose local stdio servers run unsandboxed
  on the host. Its network allow list covers only Chromium's own binary download; which sites
  the agent is actually allowed to navigate to is left to the consuming project, via `sbx policy
  allow network` or another kit.

A GitHub Actions workflow ([`.github/workflows/kits.yml`](.github/workflows/kits.yml)) runs `sbx
kit validate` against every kit on pull requests and on push to `main`, and on push to `main`
also publishes each to `ghcr.io/tmsick/sbx-preset/kit/<name>`, tagged `:latest` and `:<sha>`.
