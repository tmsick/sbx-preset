# sbx-preset

[Docker Sandboxes](https://docs.docker.com/ai/sandboxes/) [kits](https://docs.docker.com/ai/sandboxes/customize/)
(v3) for the built-in Claude Code agent: [mise](https://mise.jdx.dev/), fish and Neovim
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
  --kit ghcr.io/tmsick/sbx-preset/kit/ldconfig:latest \
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
[the other kits](#the-other-kits)), or add a kit to an existing sandbox with `sbx kit add
<sandbox> <reference>`, which recreates its container. A kit that asks for network access the
sandbox wasn't granted makes `sbx kit add` prompt for approval, so run it from a terminal. Inside
a sandbox, `ls /usr/share/sandbox/kit/` lists the kits it carries.

On a network behind a corporate TLS-inspecting proxy, add
`--kit ghcr.io/tmsick/sbx-preset/kit/ca-trust:latest --kit-arg ca-trust.cert_base64=<...>` --
without its CA, an install hook that reaches the network over HTTPS (playwright's npm and
Chromium downloads) fails certificate verification, so `sbx create` doesn't come up at all. Such a
kit declares that it integrates ca-trust, so the CA lands first; the order of `--kit` flags
doesn't matter. See [`kit/ca-trust/`](#the-other-kits) for how to get that value.

Work in the sandbox from VS Code (and its Claude Code extension) over SSH:

```sh
sbx setup ssh   # once, and again if a new sandbox's host isn't found
code --remote "ssh-remote+claude-$(basename "$PWD").sbx" "$PWD"
```

VS Code over SSH needs [`kit/ldconfig/`](#the-other-kits): without it, VS Code Server refuses the
sandbox.

These are v3 kits on Docker's own `claude` agent. Built-in agent names resolve to published v3 kits
(`docker.io/sbx/claude`, a Debian 13 Hardened Image), and v1/v2 kits can't be composed with v3
ones, so everything here is a v3 mixin. The image stays Docker's: nothing is built into one
here beyond each kit's overlay, so its updates reach every new sandbox without a rebuild.

## Development

To work on this repository itself, clone it. A kit directory can be passed to sbx as is -- sbx
builds it -- so a change can be tried before CI publishes it (use absolute paths):

```sh
sbx create --name kit-test --kit "$PWD/kit/mise" --kit "$PWD/kit/fish" claude /path/to/project
```

`make validate` (or `make validate-<kit>`) runs `sbx kit validate` on every kit (or one) as a
quicker check. A kit with a recipe is built to be validated, on the host's Docker -- its daemon
has to be running -- or, with `SBX_KIT_BUILDER=sandbox`, in sbx's own builder sandbox (`sbx kit
builder rm` reclaims its build cache).

`make fmt` formats the repository with a pinned prettier, and `make fmt-check` (which CI runs) fails
on anything unformatted. Both go through `npx`; without Node on the host, run
`mise exec node -- make fmt`.

## kit/

`kit/<name>/` directories are [v3 kits](https://docs.docker.com/ai/sandboxes/customize/author/):
a descriptor `<name>.yaml` (starting `# syntax=docker/sandbox-kit:3`, which selects the BuildKit
frontend that validates and builds it), plus the content it builds from, where it has any: a
recipe `<name>.dockerfile`, and `files/home/`, which mirrors `~/`. A mixin's content is an
overlay: exactly the files its final build stage adds, landed on the workload's filesystem.
Everything else a mixin needs -- network access, setup commands -- is a `capabilities` entry.

Rules that overlay semantics impose, and that every kit here follows:

- **Stage the overlay; ship nothing but it.** Build in one stage, copy the result onto `scratch`.
  A package-manager install would ship its database (`/var/lib/dpkg/status`) over the
  workload's, and an `/etc/passwd` edit would replace the workload's file wholesale. Such changes
  go in lifecycle install hooks, which run against the composed sandbox.
- **Keep `/home` root's and `/home/agent` uid 1000's.** A mixin's directory entries replace the
  workload's, owner included. A bare `COPY --chown=1000:1000 files/home/ /home/agent/` onto
  `scratch` also hands the implicitly created `/home` to uid 1000 -- hence the staged `/out`
  tree with explicit `chown`s.
- **Don't reuse a workload's kit name.** Each kit stages its sources at
  `/usr/share/sandbox/kit/<descriptor stem>/`, and two kits with one stem fail assembly with a
  file collision -- why the Claude Code configuration kit is `claude-config`, not `claude`.
- **A hook sees only the variables it lists in `env:`.** Anything that downloads needs the
  sandbox's proxy and CA variables. A root hook's `HOME` is still `/home/agent`, so a tool that
  caches under it (npm) leaves root-owned files the agent then can't write: give such a hook its
  own `HOME`.

The workload is Docker's, not built here: an agent's sbx integration -- entrypoint, credential
injection, session volumes, settings seeding -- lives in its workload kit and silently assumes
things of the image. Docker keeps that in step; a workload built here would have to track it by
hand, unchecked. Everything this repository adds is therefore a mixin. The install hooks assume a
Debian-based workload (`apt-get`, `usermod`, `update-ca-certificates`), as Docker's `claude` is.
What a kit downloads at build time (mise, fish, Neovim) comes in the overlay, built on
`debian:trixie-slim` (which needn't match the workload); what the sandbox's own package manager
has to do (`apt-get`, `usermod`, an `/etc` edit) is an install hook.

A GitHub Actions workflow ([`.github/workflows/kits.yml`](.github/workflows/kits.yml)) builds
every kit for `linux/amd64` and `linux/arm64` -- the build is the validation. On `main` only (a
push or a manual run), a second job, the only one with package write access, publishes each to
`ghcr.io/tmsick/sbx-preset/kit/<name>`, tagged `:latest` and `:<sha>`.

A tool's shell integration ships with the kit that installs the tool: the mise kit wires mise into
fish (`conf.d/mise.fish`) and bash (`/etc/sandbox-persistent.sh`), the nvim kit makes nvim fish's
`EDITOR` (`conf.d/nvim.fish`), and the fish kit knows about neither -- any of the three works
without the others.

Kit-to-kit relations are declared, not implied by names. A kit that installs a tool `provides`
it, at the version it ships (`mise@2026.11.1`), and a kit whose integration takes effect only
alongside another's tool `integrates` it (`integrates: ["fish"]` on mise and nvim): sbx orders
composition by these -- fish's install hook runs before mise's; absent a relation, hooks run in
kit-name order, never in `--kit` flag order -- and refuses a set where two kits provide one name. The version comes from the kit's `version` arg
(`buildArg:` into the Dockerfile, expanded into `provides` and the kit's own `version`), the one
place a release is pinned and what Renovate bumps.

### kit/mise/

mise and its shell integration -- no tools. Install them in the sandbox as a project needs them
(`mise install` against the project's own `mise.toml`, or `mise use`); a project pins its
toolchain and sets its environment variables (`[env]`) there, which is why there is no direnv
here. `mise.dockerfile` stages:

- `/usr/local/bin/mise`, the release binary from GitHub at the `version` arg, verified against
  the release's minisign-signed `SHASUMS256.txt` as mise documents.
- fish's `conf.d/mise.fish` (`mise activate fish`) and `completions/mise.fish`.

`mise.yaml`'s install hooks install `libatomic1`, which pnpm's standalone binary (and other
Node.js SEA builds) needs once mise installs one and the Debian image lacks, and prepend mise's
shims to `PATH` in `/etc/sandbox-persistent.sh`. The overlay's own `ENV PATH` is appended to the
workload's at assembly, so the workload's `python3`, ... would otherwise win. That file is
`BASH_ENV` and `CLAUDE_ENV_FILE` on Docker's images, and their `~/.bashrc` sources it: every bash,
and every Claude Code Bash tool call, gets the shims first. Interactive fish gets the same
precedence from `mise activate`.

Not Docker's `docker.io/docker/sbx-kit-mise`: it activates mise only in interactive bash, so the
workload's own tools still win in Claude Code's Bash tool, and it has no fish integration. The two
can't be composed together anyway: both provide `mise`.

### kit/fish/

fish, from upstream's static build (4.x embeds its functions and completions), at the `version`
arg, and `config.fish` (locale, path, aliases) scoped to what actually exists in the sandbox.
`fish.yaml`'s install hook makes fish the `agent` user's login shell (`/etc/shells`, `usermod`).

### kit/nvim/

Neovim, from its release tarball (kept whole under `/opt/nvim`, linked from `/usr/local/bin`), and
`conf.d/nvim.fish`, which sets `EDITOR` and `VISUAL` and aliases `vim`. git follows them: the git
kit sets no `core.editor`, which would otherwise take precedence. No nvim configuration ships with
it. Outside fish -- Claude Code's Bash tool -- `EDITOR` stays unset, which is fine for an agent
that never opens an editor.

Not Docker's `docker.io/docker/sbx-kit-neovim`: it sets `EDITOR` only in `/etc/profile.d`, which
fish never reads, and ships a starter `~/.config/nvim/init.lua` that a real nvim config would
collide with.

### The other kits

Besides the three tool kits, `claude-config`, `git` and `context7` are what the Usage quickstart
attaches by default -- generic enough to want on every sandbox -- and so is `ldconfig`, which VS Code
over SSH needs. `asana`, `atlassian` and `figma` are network access for one service each, worth
adding only when a project actually talks to it.
`playwright` is different again -- it installs a browser and registers an MCP server rather than
just opening network access. There's no directory split between these groups: every kit is attached the same
way, an explicit `--kit` flag, so which ones a project needs is a call made per `sbx create`, not
encoded in the repository layout.

Kits are named after the capability they provide (`figma/`, not `net-figma/`), not the mechanism
they happen to use today: if Figma later needs an API token as well as network reach, a
credential goes into the same `kit/figma/`, not a new kit. Splitting by service
rather than by project is deliberate too -- a kit per project would not survive two projects
wanting Figma.

Network allowlist conventions, for every kit that declares `network-policy@1`: rules from a kit
are scoped to the sandbox it was applied to, unlike `sbx policy allow network` without
`--sandbox`, which edits the global policy every sandbox on this host inherits (`sbx policy ls
SANDBOX --source kit` shows the ones from kits). Only what `sbx policy init balanced` doesn't
already cover belongs in a kit -- it ships ~190 allow entries (github, npm, pypi, crates.io,
Debian and Ubuntu mirrors, docker registries, Chromium's download CDN, the agent APIs, ...);
check with `sbx policy ls --type network --decision allow --json` first. Grow a list from
evidence, not guesses: an entry nobody has been blocked on is network reach handed to every agent
for nothing -- `sbx policy log [SANDBOX]` reports what the proxy actually refused. Entries take an
optional `:PORT` suffix; without one, every port is allowed, and `**.` covers the domain itself
plus any depth of subdomain (`*.` is exactly one label and excludes the apex). The kits here
declare `runtime.allow` only: what the agent may reach while the sandbox runs. Adding a domain
means editing the kit's descriptor, in a clone, and letting CI publish it; an existing sandbox
only picks up the change via `sbx kit add` or a one-off `sbx policy allow network` run by hand.

The kits:

- `kit/claude-config/` injects `CLAUDE.md` into `/home/agent/.claude/` -- Claude Code's user
  memory, loaded into every session. Only `CLAUDE.md` and `rules/` are worth injecting this way:
  `sbx` rewrites `~/.claude/settings.json` and `~/.claude.json` itself. The workload keeps its own
  guidance in a managed section at the top of the same `CLAUDE.md`; the kit's content follows it.
  `CLAUDE.md` stays empty, or generic enough for anyone to read.
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
- `kit/ldconfig/` runs `ldconfig` in an install hook. Docker's `claude` workload (Debian 13
  Hardened Image) ships no `/etc/ld.so.cache`, so `ldconfig -p` fails and VS Code Server's
  prerequisite check over SSH ("does not meet the prerequisites") refuses the sandbox, whatever
  other kits are attached. Drop the kit once the workload ships the cache.
- `kit/asana/`, `kit/atlassian/` and `kit/figma/` each allow only the domains that one service
  needs.
- `kit/playwright/` installs Node.js (the image ships none), `@playwright/mcp` at the `version`
  arg's release (globally, as root, scripts disabled) and the Chromium build that release uses at
  creation, and registers it with Claude Code at every sandbox start, so browser automation runs
  as a subprocess of `claude` itself, inside the sandbox -- unlike `sbx mcp add --command`, whose
  local stdio servers run unsandboxed on the host. It grants no network access: the downloads are
  covered by `balanced`, and which sites the agent is actually allowed to navigate to is left to
  the consuming project, via `sbx policy allow network` or another kit.
- `kit/ca-trust/` trusts a CA certificate passed in at creation
  (`--kit-arg ca-trust.cert_base64=<...>`), not one this repository ships or knows about. The
  motivating case is a corporate TLS-inspecting proxy: the host OS already trusts its CA, but
  the sandbox is a separate Linux environment with its own trust store, so every install hook
  that reaches the network fails certificate verification on a machine routed through one --
  until that same CA is trusted there too. A kit whose install hook fetches over HTTPS declares
  `integrates: ["ca-trust"]` (playwright does); a hook that doesn't is ordered by kit name, not by
  `--kit` flags. The value is the certificate, PEM-encoded and base64'd with no line wraps: `base64 < ca.pem | tr -d '\n'` from a file, or
  pulled straight from the macOS keychain --
  `security find-certificate -a -c <name> -p /Library/Keychains/System.keychain | base64 | tr -d '\n'`,
  `<name>` being whatever the proxy's CA is listed under in Keychain Access.
