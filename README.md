# sbx-preset

[Docker Sandboxes](https://docs.docker.com/ai/sandboxes/) [kits](https://docs.docker.com/ai/sandboxes/customize/kits/)
(v2) for the built-in Claude Code agent: [mise](https://mise.jdx.dev/), fish and Neovim
([kit/mise/](#kitmise), [kit/fish/](#kitfish), [kit/nvim/](#kitnvim)), plus configuration and
per-service network access ([the other kits](#the-other-kits)).

## Usage

For your own project, no clone of this repository needed:

```sh
sbx settings set kit.allowedSources '["docker.io/","ghcr.io/tmsick/"]'  # once

cd /path/to/project   # a git repository
sbx create --clone \
  --kit ghcr.io/tmsick/sbx-preset/kit/mise:latest \
  --kit ghcr.io/tmsick/sbx-preset/kit/fish:latest \
  --kit ghcr.io/tmsick/sbx-preset/kit/nvim:latest \
  --kit ghcr.io/tmsick/sbx-preset/kit/claude-config:latest \
  --kit ghcr.io/tmsick/sbx-preset/kit/git:latest \
  --kit ghcr.io/tmsick/sbx-preset/kit/context7:latest \
  claude .
```

`--clone` gives the agent its own clone of the repository inside the sandbox, at the same path,
instead of bind-mounting the working tree, which is too slow to work in. The host repository gets
a `sandbox-<name>` remote to fetch the agent's branches from (`git fetch sandbox-<name>`) while
the sandbox is running; the host's own remotes are copied into the clone, so the agent can also
push to them directly. `--clone` is fixed at creation.

The sandbox is named `claude-<directory>` by default (see `sbx ls`); pass `--name` to choose
another.

Add `--kit ghcr.io/tmsick/sbx-preset/kit/<service>:latest` for a project that needs one (see
[the other kits](#the-other-kits)). A kit that only grants network access can also be added to an
existing sandbox with `sbx kit add <sandbox> <reference>`, which recreates its container; one
that ships files can't, so it means removing the sandbox (`sbx rm`) and creating it again.

On a network behind a corporate TLS-inspecting proxy, put
`--kit ghcr.io/tmsick/sbx-preset/kit/ca-trust:latest --kit-arg cert_base64=<...>` FIRST in the
`--kit` list -- before this one its CA isn't trusted yet, every other kit's `setup.install` that
reaches the network (mise, fish, nvim) fails certificate verification and `sbx create` doesn't
come up at all. See [`kit/ca-trust/`](#the-other-kits) for how to get that value.

Work in the sandbox from VS Code (and its Claude Code extension) over SSH:

```sh
sbx setup ssh   # once, and again if a new sandbox's host isn't found
code --remote "ssh-remote+claude-$(basename "$PWD").sbx" "$PWD"
```

These are v2 kits on the built-in agent, not v3 kits on a v3 workload such as
`docker.io/docker/sbx-kit-claude`: the two formats don't compose with each other, and the v3
format was still changing in place under released sbx versions. The `v3-snapshot` tag holds this
repository's last v3 state, the starting point for moving back.

Everything this repository adds is a kit; the image stays Docker's own
(`docker/sandbox-templates:claude-code-docker`), so its updates reach every new sandbox without a
rebuild here.

## Development

To work on this repository itself, clone it. A kit directory can be passed to sbx as is, so a
change can be tried before CI publishes it (use absolute paths):

```sh
sbx create --name kit-test --kit "$PWD/kit/mise" --kit "$PWD/kit/fish" claude /path/to/project
```

`make validate` (or `make validate-<kit>`) runs `sbx kit validate` on every kit (or one) as a
quicker check.

## kit/

`kit/<name>/` directories are [v2 kits](https://docs.docker.com/ai/sandboxes/customize/kits/):
declarative artifacts applied at sandbox creation (`--kit`), not baked into an image -- editing a
kit takes effect on the next `sbx create`, with no image rebuild. Each kit is a `spec.yaml` plus,
where it ships files, a `files/` tree (`files/home/` lands in `/home/agent/`). Files land first,
then `setup.install` commands run, as root unless a command says otherwise, in `--kit` order.

A GitHub Actions workflow ([`.github/workflows/kits.yml`](.github/workflows/kits.yml)) runs `sbx
kit validate` against every kit on pull requests and on push to `main`, and on push to `main`
also publishes each to `ghcr.io/tmsick/sbx-preset/kit/<name>`, tagged `:latest` and `:<sha>`.

Two things to know before running `sbx kit add` by hand. It accepts only kits limited to
`environment.variables`, `setup.install` and `permissions.network.allow` -- of the kits here,
`context7`, `asana`, `atlassian` and `figma`; one with files or startup commands is refused.

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

A tool's shell integration ships with the kit that installs the tool: the mise kit wires mise into
fish (`conf.d/mise.fish`) and bash (`/etc/sandbox-persistent.sh`), the nvim kit makes nvim fish's
`EDITOR` (`conf.d/nvim.fish`), and the fish kit knows about neither -- any of the three works
without the others. Each pins its release once, as the kit's `version` arg (`${{ kit.args.version
}}` in its commands), which is what Renovate bumps; `--kit-arg mise.version=2026.8.1` overrides
it per sandbox. Their downloads come from GitHub releases and the Ubuntu mirrors, which `sbx
policy init balanced` already allows, so they grant no network access: a v2 grant would stay open
for the agent at runtime, not just during install.

### kit/mise/

mise and its shell integration -- no tools. Install them in the sandbox as a project needs them
(`mise install` against the project's own `mise.toml`, or `mise use`); a project pins its
toolchain and sets its environment variables (`[env]`) there, which is why there is no direnv
here. Its install commands:

- download the mise release binary from GitHub to `/usr/local/bin/mise` -- not through the
  `mise.run` installer, which fetches from `mise.jdx.dev`, a domain `balanced` doesn't allow;
- install `libatomic1`, which pnpm's standalone binary (and other Node.js SEA builds) needs once
  mise installs one, and which the Ubuntu image lacks;
- prepend mise's shims to `PATH` in `/etc/sandbox-persistent.sh`, so the image's `/usr/bin/node`,
  `python3`, ... don't win. That file is `BASH_ENV` and `CLAUDE_ENV_FILE` on Docker's images, and
  their `~/.bashrc` sources it: every bash, and every Claude Code Bash tool call, gets the shims
  first. Interactive fish gets the same precedence from `mise activate` (`conf.d/mise.fish`);
- generate fish's `completions/mise.fish` for the installed release.

### kit/fish/

fish, from upstream's static build (4.x embeds its functions and completions), as the `agent`
user's login shell (`/etc/shells`, `usermod`). Its install command fetches `xz-utils` to unpack
the tarball.

`files/home/.config/fish/config.fish` sets defaults (locale, path, aliases) scoped to what actually
exists in the sandbox.

`files/home/.vscode-server/data/Machine/settings.json` makes fish the default profile for VS Code's
Remote-SSH terminal. Needed on top of the login shell: Docker Sandboxes forces `SHELL=/bin/bash`
into every sandbox, and that is what both a plain `ssh` session and VS Code's terminal key off.

### kit/nvim/

Neovim, from its release tarball (kept whole under `/opt/nvim`, linked from `/usr/local/bin`), and
`conf.d/nvim.fish`, which sets `EDITOR` and `VISUAL` and aliases `vim`. git follows them: the git
kit sets no `core.editor`, which would otherwise take precedence. No nvim configuration ships with
it. Outside fish -- Claude Code's Bash tool -- `EDITOR` stays unset, which is fine for an agent
that never opens an editor.

### The other kits

Besides the three tool kits, `claude-config`, `git` and `context7` are what the Usage quickstart
attaches by default -- generic enough to want on every sandbox. `asana`, `atlassian` and `figma`
are network access for one service each, worth adding only when a project actually talks to it.
`playwright` is different again -- it installs a browser and registers an MCP server rather than
just opening network access. There's no directory split between these groups: every kit is attached the same
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
- `kit/playwright/` installs Chromium at creation and registers `@playwright/mcp` with Claude Code
  at every sandbox start, so browser automation runs as a subprocess of `claude` itself, inside
  the sandbox -- unlike `sbx mcp add --command`, whose local stdio servers run unsandboxed on the
  host. Its network allow list covers only Chromium's own binary download; which sites the agent
  is actually allowed to navigate to is left to the consuming project, via
  `sbx policy allow network` or another kit.
- `kit/ca-trust/` trusts a CA certificate passed in at creation
  (`--kit-arg ca-trust.cert_base64=<...>`), not one this repository ships or knows about. The
  motivating case is a corporate TLS-inspecting proxy: the host OS already trusts its CA, but the
  sandbox is a separate Linux environment with its own trust store, so every kit whose
  `setup.install` reaches the network (mise, fish, nvim) fails certificate verification on a
  machine routed through one -- until that same CA is trusted there too. It has to go first: list
  it before the others on `--kit`, since `setup.install` runs in `--kit` order and the CA has to
  land before anything else tries the network. The value is the certificate, PEM-encoded and
  base64'd with no line wraps: `base64 < ca.pem | tr -d '\n'` from a file, or pulled straight from
  the macOS keychain --
  `security find-certificate -a -c <name> -p /Library/Keychains/System.keychain | base64 | tr -d '\n'`,
  `<name>` being whatever the proxy's CA is listed under in Keychain Access.
