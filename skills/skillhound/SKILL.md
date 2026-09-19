---
name: skillhound
description: Mines past Claude Code chats for repeated work that belongs in a new skill. It also finds skill steps that a script can do in place of the model.
disable-model-invocation: true
argument-hint: [since-date]
---

# Skillhound

Hunt through the chat logs for two kinds of waste, and report them with evidence:

1. **New skills.** Work the agent repeats across sessions or projects, most of all
   research or chores with one right answer.
2. **Scripts for existing skills.** Steps an installed skill makes the model do by hand
   that a node, python, or bash script can do the same way every time.

A script is the target. It costs fewer tokens than the model, and it gives the same
result on every run.

## 1. Count

```bash
python3 ${CLAUDE_SKILL_DIR}/scripts/hound.py
```

If the user gave a date (`$ARGUMENTS`), add `--since <date>` to read only the chats
changed since then. It writes `/tmp/skillhound/events.jsonl`
and prints the counts: tools, Bash command heads by project, chore patterns, web lookups,
skills called, and repeated user prompts.

Read [known.md](known.md). It lists the findings that shipped already and the ones the
user turned down. Leave those out of the report, unless the counts show the problem
came back.

## 2. Dig in parallel

Send three subagents at once, each with the path to `events.jsonl`, its field list (in
the `hound.py` docstring), and the counts from step 1:

| Agent | Looks at |
|---|---|
| New skills | Chores and research repeated in 2 or more sessions: the chore patterns, the Bash heads, the web lookups, the repeated prompts |
| Our skills | Every skill in this repository (`skills/*/SKILL.md`): the tool calls that follow each Skill call, the steps that repeat in every run, and the runs that failed or that the user corrected |
| Project skills | Skills under each project's `.claude/skills/`, minus any project the user excluded |

Tell each agent to be skeptical. A finding needs a count, the number of sessions and
projects, and one or two example commands. Tell it to drop anything seen in one session
only, and to name any installed skill that already covers the finding.

## 3. Judge each finding

Three tests decide whether a finding gets a script:

- The step has one right answer. Writing a test case, choosing a design, and judging a
  verdict stay with the model.
- It works the same way in any repository with the same tools. A script that fits one
  project belongs in that project, not in this repository.
- The script is short enough to read and test.

## 4. Report

Write `docs/research/<today>-skillhound.md` with three ranked tables: new skills, scripts
for our skills, and project skills. Each row carries the evidence and the script's
inputs and outputs. Then give the user the top three and ask which to build.

## 5. Keep it current

When the user builds a finding or turns one down, add a line to [known.md](known.md).
A new chore pattern in the counts gets a regex in `PATTERNS` in `scripts/hound.py`. Then
the next hunt counts it from the start.

## Writing standard

Write everything this skill produces in Simplified Technical English: short sentences,
active voice, one word for one meaning, the answer first, no jargon left unexplained.
Keep paths, commands and numbers exact.
