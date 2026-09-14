# Probe results: the four unconfirmed mechanisms

Date: 2026-09-14. Run against Claude Code on this machine, Opus 5.

The design spec leans on four behaviors that the documentation describes but that had
not been observed here. Each was probed with a throwaway skill under
[`scripts/probes/`](../../scripts/probes). The probe skills stay in the repo so the
checks can be rerun after a Claude Code upgrade.

## Contents
- Probe 1: symlinked personal skills
- Probe 2: context fork returning in the same turn
- Probe 3: argument interpolation inside a command injection
- Probe 4: disallowed-tools inside a fork
- Results table
- What changed in the build

---

## Probe 1: symlinked personal skills

**Ran:** symlinked `~/.claude/skills/probe-link` to a directory outside `~/.claude`,
then read `SKILL.md` through the link.

**Observed:** the link resolved and `SKILL.md` was readable. The skill then appeared in
the session's skill list and was invocable.

**Also observed, and worth knowing:** a skill created during a session is **not**
immediately invocable. The first call returned `Unknown skill: probe-fork`. A rescan
picks it up a short time later, announced by a system message, after which it works.
So there is a lag, not a restart requirement.

**Verdict: CONFIRMED.** Symlink mode is the default in `scripts/link-skills.sh`. The
`--copy` fallback stays in the script but is not needed.

---

## Probe 2: context fork returning in the same turn

**Ran:** a skill with `context: fork`, `agent: general-purpose`, `background: false`,
whose whole body was an instruction to return one fixed string.

**Observed:**

```
Skill "probe-fork" completed (forked execution).

Result:
PROBE-FORK-OK
```

The result came back inside the same turn. No task notification, no waiting.

**Verdict: CONFIRMED.** `blind-e2e` needs no hand-built agent dispatch. The frontmatter
is the whole mechanism.

---

## Probe 3: argument interpolation inside a command injection

Three forms were tried against `` !`cat "<placeholder>"` ``.

| Form | Result |
|---|---|
| `$1` | **FAILED.** `cat: '': No such file or directory`. The placeholder resolved to an empty string. |
| `$ARGUMENTS` | **CONFIRMED.** The file content was injected. |
| `$casepath`, declared via `arguments: casepath` | **CONFIRMED.** The file content was injected. |

**Verdict: FALLBACK TAKEN, and a better one than the spec named.** The spec's fallback
was to paste the test case content inline at the call site. That is not needed. Use
`$ARGUMENTS` for a single-argument skill, or a named argument declared in frontmatter
for a multi-argument skill. Positional `$1` must not be used inside a `!` injection
anywhere in this repo.

---

## Probe 4: disallowed-tools inside a fork

**Ran:** a forked skill with `disallowed-tools: Read, Grep, Glob, Edit, Write, NotebookEdit`,
instructed to try reading a file with `Read`.

**Observed:**

```
TOOLS-BLOCKED

The Read tool schema was present, but invoking it on /tmp/probe-arg.txt returned
"Permission to use Read has been denied" — the file-reading capability is removed
in this forked context, so the file contents could not be accessed.
```

**Verdict: CONFIRMED, with one detail that matters.** The restriction is enforced at
invocation, not by hiding the tool. The forked agent still **sees** `Read` in its tool
list and only learns it is blocked by trying. So `blind-e2e` must tell the agent up
front not to reach for those tools, or it burns a turn discovering the denial. That is
a wording requirement in the skill, not a design change.

---

## Results table

| Mechanism | Result |
|---|---|
| A symlinked `~/.claude/skills/<name>` lists and runs correctly | CONFIRMED |
| `context: fork` with `background: false` returns the fork's result in the same turn | CONFIRMED |
| `$1` interpolates inside a `` !`command` `` injection | **FALLBACK TAKEN** — use `$ARGUMENTS` or a named argument |
| `disallowed-tools` removes those tools inside a forked skill | CONFIRMED |

## What changed in the build

1. `blind-e2e` injects its test case with `` !`cat "$ARGUMENTS"` ``, never `$1`.
2. `blind-e2e` opens by telling the forked agent that `Read`, `Grep`, `Glob`, `Edit`
   and `Write` will be denied, so it does not waste a turn trying.
3. Nothing else changed. Blindness is genuinely enforced, not requested.
