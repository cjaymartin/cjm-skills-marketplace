# Research: skill and plugin mechanics

Date: 2026-09-14. Sources are primary (Anthropic / Claude Code docs) unless marked otherwise.

## Contents
- SKILL.md required shape
- Claude Code frontmatter fields (the important ones for this repo)
- Progressive disclosure rules
- Where skills live, and symlinks
- Plugin and marketplace file shapes
- What this means for our design

---

## SKILL.md required shape

Every skill is a directory with a `SKILL.md`. Frontmatter requires exactly two fields:

- `name` — max 64 chars, lowercase letters, numbers, hyphens only. Cannot contain the reserved words "anthropic" or "claude". No XML tags.
- `description` — non-empty, max 1024 chars, third person, no XML tags. Must say **what** the skill does **and when** to use it. This is the only signal used to pick a skill.

Source: https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview

### Naming

Anthropic recommends gerund names ("Processing PDFs"). Noun phrases and action verbs are listed as acceptable alternatives.

Source: https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices

**Decision for this repo:** the slash command comes from the *directory* name for personal/project skills, and from the `name` frontmatter for plugin skills. To make one repo work in both install modes, **`name` must equal the directory name** in every skill here. That rules out gerund display names.

---

## Claude Code frontmatter fields

Beyond `name` and `description`, Claude Code supports:

| Field | Type | Purpose |
|---|---|---|
| `disable-model-invocation` | bool | `true` stops auto-trigger; user can still run `/skill-name` |
| `user-invocable` | bool | `false` hides it from the `/` menu; only Claude may call it |
| `context` | string | `fork` runs the skill in an **isolated subagent context** |
| `agent` | string | subagent type when `context: fork` (`Explore`, `Plan`, `general-purpose`, ...) |
| `background` | bool | `false` waits for the forked result in the same turn (default `true`) |
| `model` | string | model to use while the skill is active |
| `effort` | string | `low`, `medium`, `high`, `xhigh`, `max` |
| `allowed-tools` | string/list | pre-approved tools for the invocation turn |
| `disallowed-tools` | string/list | tools **removed** from the pool while the skill is active |
| `paths` | string/list | globs limiting auto-activation |
| `arguments` | string/list | named positional args for `$name` substitution |
| `argument-hint` | string | autocomplete hint |
| `hooks` | map | hooks registered when the skill runs |
| `shell` | string | shell for `` !`cmd` `` injection |
| `metadata` | map | free-form; Claude Code ignores it |

Source: https://code.claude.com/docs/en/skills

### The two fields that matter most here

1. **`context: fork` + `background: false`** gives a skill its own clean subagent context and returns the result in the same turn. This is the exact mechanism `blind-e2e` needs. No hand-rolled agent dispatch required.
2. **`disallowed-tools`** removes tools from the pool. This is how blindness gets *enforced* rather than merely requested.

### Shell injection

`` !`command` `` in the body runs at invoke time and injects the output. Useful for pasting a test case into the forked agent's prompt so it never needs a file-read tool.

### Argument substitution

`$ARGUMENTS` (all), `$1`/`$ARGUMENTS[N]` (positional, 0-based), `$name` (declared in `arguments`).

---

## Progressive disclosure rules

- Only `name` + `description` load at startup (~100 tokens per skill).
- SKILL.md body loads on trigger. Keep it **under 500 lines**; target under 5k tokens.
- Bundled files load only when read. No context cost until then.
- **Keep references one level deep from SKILL.md.** Nested references get partially read (agents preview with `head`), producing incomplete information.
- Reference files over 100 lines need a table of contents at the top.

Source: https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices

## Degrees of freedom

Match specificity to fragility. High freedom (prose) when many approaches work. Low freedom (an exact command, "do not modify it") when the sequence is fragile.

---

## Where skills live, and symlinks

| Scope | Path |
|---|---|
| Personal | `~/.claude/skills/<name>/SKILL.md` |
| Project | `.claude/skills/<name>/SKILL.md` |
| Plugin | `<plugin>/skills/<name>/SKILL.md`, invoked `/plugin-name:skill-name` |

**Symlinks are documented as supported** for enterprise, personal, and project locations. Claude Code reads `SKILL.md` through the link and loads the skill once even if several paths point at the same target.

Source: https://code.claude.com/docs/en/skills

**Caveat — not a primary source.** Open issues report symlink discovery problems: skills execute but fail listing or validation.

- https://github.com/anthropics/claude-code/issues/14836 — `/skills` does not find skills in symlinked directories
- https://github.com/anthropics/claude-code/issues/25367 — symlinked `~/.claude/skills/` fails validation but executes
- https://github.com/anthropics/claude-code/issues/37590 — request for symlink support in `.claude/skills/`

**Decision:** symlink per-skill (`~/.claude/skills/<name>` → repo dir), not the whole skills directory. Verify each link resolves and the skill lists correctly right after creating it. If listing breaks, fall back to a copy-on-change sync script.

---

## Plugin and marketplace file shapes

`.claude-plugin/marketplace.json` at repo root:

```json
{
  "name": "kebab-case-id",
  "owner": { "name": "required", "email": "optional", "url": "optional" },
  "plugins": [
    { "name": "kebab-case", "source": "./", "description": "recommended" }
  ]
}
```

`.claude-plugin/plugin.json` inside the plugin directory:

```json
{
  "name": "kebab-case",
  "description": "string",
  "version": "string",
  "author": { "name": "string" }
}
```

`source` accepts a relative path string, or an object with `source` set to `github`, `url`, `git-subdir`, `npm`, `archive`, or `command`.

Plugin directories Claude Code reads: `commands/`, `agents/`, `skills/`, `hooks/`, `.mcp.json`.

CLI (non-interactive):

```
claude plugin marketplace add ./path/to/marketplace
claude plugin install <plugin>@<marketplace>
claude plugin validate .
claude plugin marketplace update [name]
```

Source: https://code.claude.com/docs/en/plugin-marketplaces

---

## What this means for our design

1. `blind-e2e` is a skill with `context: fork`, `background: false`, `user-invocable: false`. No custom agent plumbing.
2. Blindness is enforced with `disallowed-tools` (no Read, Grep, Glob, Edit, Write), and the test case is injected with `` !`cat` `` so the fork needs no file-read tool at all.
3. Every skill sets `name` equal to its directory name, so one repo serves both the symlink install and the plugin install.
4. Each SKILL.md stays under 500 lines; long detail goes to sibling reference files linked one level deep.
5. Orchestrators (`implement`) set `disable-model-invocation: true` so they only run when the user asks.
