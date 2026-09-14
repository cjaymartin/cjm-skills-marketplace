# skillz

An agent-driven SDLC as Claude Code skills. Covers the developer's own block of a
ticket's life: research, replicate the failure, build tests, build code, replicate
the success, review your own work.

Design: [docs/superpowers/specs/2026-09-14-agent-sdlc-skills-design.md](docs/superpowers/specs/2026-09-14-agent-sdlc-skills-design.md)

Status: design approved, skills not yet written.

## Prerequisites

- [superpowers](https://github.com/obra/superpowers)
- [mattpocock-skills](https://github.com/mattpocock/skills)

## Install on this machine

```bash
scripts/link-skills.sh
```

Symlinks each skill into `~/.claude/skills/`, so edits here go live at once.

## Install anywhere else

```bash
claude plugin marketplace add <this repo>
claude plugin install agent-sdlc@skillz
```
