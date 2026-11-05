# TODO

- `kit/fish/files/home/.config/fish/config.fish` mixes personal preferences (`BAT_THEME`,
  aliases for bat/git/docker/less) into what README documents as the fish kit's shell setup.
  Only `XDG_CONFIG_HOME` and the `fish_add_path` calls are
  actually required; split the rest into a kit, as `kit/claude-config/` does.

- The `claude` workload (Debian 13 Hardened Image) ships no `/etc/ld.so.cache`, so `ldconfig -p`
  fails and VS Code Server's prerequisite check over SSH ("does not meet the prerequisites")
  refuses the sandbox, with any kit set. Waiting on Docker to fix the image. Fallback if it
  doesn't: a `kit/ldconfig` whose root install hook runs `ldconfig` (an install hook persists,
  unlike running it by hand) -- its own kit, not part of fish.

- Kits are experimental and their grammar moves under released sbx: sbx v0.50.0 stopped composing
  v1/v2 kits with v3 ones, and v3 capabilities get superseded in place (`agent-context@1` by
  `@2`). `.github/workflows/kits.yml` builds every kit with the `docker/sandbox-kit:3` frontend on
  every PR/push touching `kit/`, but only reacts to changes in this repo -- a release of sbx or the
  frontend that tightens validation, with no accompanying kit edit, slips past it silently, so
  `make validate` is still worth running by hand after upgrading sbx locally.

- The fish and Neovim downloads are not integrity-checked beyond TLS: upstream publishes no
  checksum or signature for the Linux assets (fish's `.asc` covers only the source tarball). Pin a
  sha256 per architecture next to the `version` arg and verify it in the recipe; Renovate can't
  bump those from the regex managers here, so it takes a custom step.

- Supply-chain hardening not done: GitHub Actions and base images (`debian:trixie-slim`,
  `busybox:stable`, the `docker/sandbox-kit:3` frontend) are pinned by tag, not digest; the
  published kits aren't signed (`kit.requireSignature` would refuse them); Renovate has no
  `minimumReleaseAge`.

- `asana`, `atlassian` and `figma` allow `**.<apex>`, which for multi-tenant services
  (`*.atlassian.net`) includes other tenants. Narrow to the hosts `sbx policy log` shows in use,
  or take the Atlassian site as a required kit arg.
