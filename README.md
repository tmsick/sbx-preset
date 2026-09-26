# sbx-preset

[Docker Sandboxes](https://docs.docker.com/ai/sandboxes/) [kits](https://docs.docker.com/ai/sandboxes/customize/)
(v3) layered onto Docker's published agent workloads: [mise](https://mise.jdx.dev/)
([kit/mise/](#kitmise)), fish ([kit/fish/](#kitfish)) and Neovim ([kit/nvim/](#kitnvim)), plus
configuration and per-service network access ([the other kits](#the-other-kits)).

## Usage

For your own project, no clone of this repository needed:

```sh
sbx settings set kit.allowedSources '["docker.io/","ghcr.io/tmsick/"]'  # once

cd /path/to/project
sbx create --name "claude-$(basename "$PWD")" \
  docker.io/docker/sbx-kit-claude:latest \
  --kit ghcr.io/tmsick/sbx-preset/kit/mise:latest \
  --kit ghcr.io/tmsick/sbx-preset/kit/fish:latest \
  --kit ghcr.io/tmsick/sbx-preset/kit/nvim:latest \
  --kit ghcr.io/tmsick/sbx-preset/kit/claude-config:latest \
  --kit ghcr.io/tmsick/sbx-preset/kit/git:latest \
  --kit ghcr.io/tmsick/sbx-preset/kit/context7:latest \
  .
sbx run --name "claude-$(basename "$PWD")"   # attach, from anywhere
```

Run the first `sbx create` or `sbx run` from an interactive terminal: sbx asks once to approve the
workload's use of your Anthropic credential and records it in `~/.config/sbx/credentials.yaml`.
Without that approval (`< /dev/null`, CI) the sandbox is created with the credential withheld.

Add `--kit ghcr.io/tmsick/sbx-preset/kit/<service>:latest` for a project that needs one (see
[the other kits](#the-other-kits)). Kits are fixed at creation: v3 sandboxes don't support `sbx
kit add`, so changing a sandbox's kits means creating a new one. Running this again for a
project that already has a sandbox creates a second one rather than reusing it -- check `sbx ls`
first. Inside a sandbox, `ls /usr/share/sandbox/kit/` lists the kits it was built from.

To use VS Code (and its Claude Code extension) inside the sandbox, connect over SSH:

```sh
sbx setup ssh   # once, and again if a new sandbox's host isn't found
code --remote "ssh-remote+claude-$(basename "$PWD").sbx" "$PWD"
```

To work on this repository itself, clone it. A kit directory can be passed to sbx as is -- sbx
builds it -- so a change can be tried before CI publishes it (use absolute paths):

```sh
sbx create --name kit-test docker.io/docker/sbx-kit-claude:latest \
  --kit "$PWD/kit/mise" --kit "$PWD/kit/fish" /path/to/project
```

`make build` (or `make build-<kit>`) runs `docker buildx build` on every kit (or one) as a quicker
check; the kit frontend validates each descriptor as it builds. Variables (read from the
environment or the command line): `IMAGE`, `TAG`, `MISE_VERSION`.

## kit/

`kit/<name>/` directories are [v3 kits](https://docs.docker.com/ai/sandboxes/customize/author/):
a descriptor `<name>.yaml` (starting `# syntax=docker/sandbox-kit:3`, which selects the BuildKit
frontend that validates and builds it), plus the content it builds from, where it has any. A
mixin's content is an overlay: exactly the files its final build stage adds, landed on the
workload's filesystem. Everything else a mixin needs -- network access, setup commands -- is a
`capabilities` entry.

Three rules that overlay semantics impose, and that every kit here follows:

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
  file collision -- why the Claude Code configuration kit is `claude-config`, not `claude`
  (`docker.io/docker/sbx-kit-claude` already stages `claude/`).

The workload is Docker's, not built here: an agent's sbx integration -- entrypoint, credential
injection, session volumes, settings seeding -- lives in its workload kit and silently assumes
things of the image (e.g. `claude` at `~/.local/bin/claude`, pre-created `~/.claude/*` mount
points). Docker keeps `sbx-kit-claude`'s image and descriptor in step; a workload built here
would have to track those assumptions by hand, unchecked. Everything this repository adds is
therefore a mixin, and works on any v3 workload that ships the platform floor (bash, the `agent`
user, git, a CA store).

A GitHub Actions workflow ([`.github/workflows/kits.yml`](.github/workflows/kits.yml)) builds
every kit for `linux/amd64` and `linux/arm64` on pull requests -- the build is the validation --
and on push to `main` also publishes each to `ghcr.io/tmsick/sbx-preset/kit/<name>`, tagged
`:latest` and `:<sha>`.

A tool's shell integration ships with the kit that installs the tool: the mise kit wires mise into
fish (`conf.d/mise.fish`) and bash (`/etc/sandbox-persistent.sh`), the nvim kit makes nvim fish's
`EDITOR` (`conf.d/nvim.fish`), and the fish kit knows about neither -- any of the three works
without the others.

### kit/mise/

mise and its shell integration -- no tools. Install them in the sandbox as a project needs them
(`mise install` against the project's own `mise.toml`, or `mise use`); a project pins its
toolchain and sets its environment variables (`[env]`) there, which is why there is no direnv
here. `mise.dockerfile` stages:

- `/usr/local/bin/mise`, from its official installer, pinned by `ARG MISE_VERSION` and bumped by
  Renovate.
- `libatomic.so.1`, lifted from the apt package of the Ubuntu base Docker's agent workloads are
  built from (`docker/sandbox-templates:shell-docker`, their `com.docker.sandboxes.base` label):
  pnpm's standalone binary (and other Node.js SEA builds) needs it once mise installs one, and
  the base lacks it.
- fish's `conf.d/mise.fish` (`mise activate fish`) and `completions/mise.fish`.

`mise.yaml`'s install hook prepends mise's shims to PATH in `/etc/sandbox-persistent.sh`. The
overlay's own `ENV PATH` is appended to the workload's at assembly, so the workload's
`/usr/bin/node`, `python3`, ... would otherwise win. That file is `BASH_ENV` and
`CLAUDE_ENV_FILE` on Docker's images, and their `~/.bashrc` sources it: every bash, and every
Claude Code Bash tool call, gets the shims first. Interactive fish gets the same precedence from
`mise activate`.

Not Docker's `docker.io/docker/sbx-kit-mise`: it activates mise only in interactive bash, so the
workload's own tools still win in Claude Code's Bash tool, and it has no fish integration. The two
can't be composed together anyway: both stage `mise/` sources.

### kit/fish/

fish, from upstream's static build (4.x embeds its functions and completions), pinned by `ARG
FISH_VERSION` and bumped by Renovate. `fish.yaml`'s install hook makes fish the `agent` user's
login shell (`/etc/shells`, `usermod`).

`config/fish/config.fish` sets defaults (locale, path, aliases) scoped to what actually exists in
the sandbox.

`config/vscode-server/data/Machine/settings.json` makes fish the default profile for VS Code's
Remote-SSH terminal. Needed on top of the login shell: Docker Sandboxes forces `SHELL=/bin/bash`
into every sandbox, and that is what both a plain `ssh` session and VS Code's terminal key off.

### kit/nvim/

Neovim, from its release tarball (kept whole under `/opt/nvim`, linked from `/usr/local/bin`),
pinned by `ARG NVIM_VERSION` and bumped by Renovate, and `conf.d/nvim.fish`, which sets `EDITOR`
and `VISUAL` and aliases `vim`. git follows them: the git kit sets no `core.editor`, which would
otherwise take precedence. No nvim configuration ships with it. Outside fish -- Claude Code's Bash
tool -- `EDITOR` stays unset, which is fine for an agent that never opens an editor.

Not Docker's `docker.io/docker/sbx-kit-neovim`: it sets `EDITOR` only in `/etc/profile.d`, which
fish never reads, and ships a starter `~/.config/nvim/init.lua` that a real nvim config would
collide with.

### The other kits

`claude-config`, `git` and `context7` are what the Usage quickstart attaches by default --
generic enough to want on every sandbox. `asana`, `atlassian` and `figma` are network access for
one service each, worth adding only when a project actually talks to it. `playwright` is
different again -- it installs a browser and registers an MCP server rather than just opening
network access. There's no directory split between these groups: every kit is attached the same
way, an explicit `--kit` flag, so which ones a project needs is a call made per `sbx create`,
not encoded in the repository layout.

Kits are named after the capability they provide (`figma/`, not `net-figma/`), not the mechanism
they happen to use today: if Figma later needs an API token as well as network reach, a
`credential@1` capability goes into the same `kit/figma/`, not a new kit. Splitting by service
rather than by project is deliberate too -- a kit per project would not survive two projects
wanting Figma.

Network allowlist conventions, for every kit that declares a `network-policy@1` capability: rules
from a kit are scoped to the sandbox it was composed into, unlike `sbx policy allow network`
without `--sandbox`, which edits the global policy every sandbox on this host inherits (`sbx
policy ls SANDBOX --wide --source kit` shows the ones from kits). `runtime` entries are what the
agent may reach; `install` entries are open only while install hooks run. Only what `sbx policy
init balanced` doesn't already cover belongs in a `runtime` list -- it ships ~190 allow entries
(github, npm, pypi, crates.io, ubuntu, docker registries, the agent APIs, ...); check with `sbx
policy ls --type network --decision allow --json` first. Grow a list from evidence, not
guesses: an entry nobody has been blocked on is network reach handed to every agent for
nothing -- `sbx policy log [SANDBOX]` reports what the proxy actually refused. Entries take an
optional `:PORT` suffix; without one, every port is allowed, and `**.` covers the domain itself
plus any depth of subdomain (`*.` is exactly one label and excludes the apex). Adding a domain
means editing the kit's descriptor, in a clone, and letting CI publish it; a running sandbox
only picks up the change by being recreated, or via a one-off `sbx policy allow network` run by
hand.

- `kit/claude-config/` injects `CLAUDE.md` into `/home/agent/.claude/` -- Claude Code's user
  memory, loaded into every session. A file rather than an `agent-context@1` capability: the
  workload surfaces a mixin's agent context only as an index entry the agent reads on demand,
  and writes its own profile beside the workspace, not here. Only `CLAUDE.md` and `rules/` are
  worth injecting this way: the workload rewrites `~/.claude/settings.json` and
  `~/.claude.json` itself. `CLAUDE.md` stays empty, or generic enough for anyone to read.
- `kit/git/` injects `~/.gitconfig` and `~/.gitignore_global` -- deliberately those paths, not
  the XDG-style `~/.config/git/{config,ignore}`. sandboxd forces `core.excludesFile` to
  `~/.gitignore_global` on every sandbox start (merging non-destructively into whatever the kit
  put there), so an XDG-style ignore file is left shadowed and never read. The kit also covers
  `git init` in the sandbox and repos outside the mounted workspace, which `sbx`'s own identity
  injection -- the local `.git/config` of an already-git workspace -- misses. That injection is
  also where `user.name`/`user.email` come from, not this kit, so `.gitconfig` here carries only
  alias/workflow preferences -- no `core.editor`, so git follows `EDITOR` (see
  [kit/nvim/](#kitnvim)). It grants no network permissions: `balanced` already covers
  github.com:443, and this preset's remotes are HTTPS-only (no SSH port 22).
- `kit/context7/` allows `**.context7.com:443` -- library/API documentation lookups, used
  routinely enough by this setup's Claude Code config to warrant it on every sandbox.
- `kit/asana/`, `kit/atlassian/` and `kit/figma/` each allow only the domains that one service
  needs.
- `kit/playwright/` installs Chromium at creation and registers `@playwright/mcp` with Claude
  Code at every sandbox start, so browser automation runs as a subprocess of `claude` itself,
  inside the sandbox -- unlike `sbx mcp add --command`, whose local stdio servers run unsandboxed
  on the host. Docker's `sbx-kit-playwright` ships a browser but registers no MCP server. Its
  network grants are install-phase only (the browser download, npm, the Ubuntu mirrors for
  `install-deps`); which sites the agent is actually allowed to navigate to is left to the
  consuming project, via `sbx policy allow network` or another kit.
