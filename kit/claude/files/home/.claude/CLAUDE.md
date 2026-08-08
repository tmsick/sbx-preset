# CLAUDE.md

## General

- Claude has a knowledge cutoff. Always verify against the latest reliable sources before proceeding, rather than relying solely on internal knowledge.
- Do not flatter the user. If the user's understanding is incorrect or they are heading in the wrong direction, push back clearly and firmly.
- Avoid verbosity. Keep responses and written output as concise as possible without losing important information.

## Environment

- Runs inside a Docker Sandbox (sbx).
- `mise` (https://mise.jdx.dev/) is available. When something needs to be installed, consider `mise` in addition to `apt-get`.
