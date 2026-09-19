---
name: red-green-e2e
description: Proves a reported bug is real before the fix and proves it is gone after, by running the same plain-English test case through a source-blind agent twice. Use when replicating a failure, verifying a fix, or whenever a ticket needs end-to-end proof rather than a unit test.
arguments: mode ticket_id
argument-hint: [red|green] [ticket-id]
allowed-tools: Bash(${CLAUDE_SKILL_DIR}/../implement/scripts/sdlc.sh *)
---

# Red-green end-to-end proof

Two runs of one unchanged test case, by an agent that cannot see the code. The first
must fail. The second must pass. Together they are the proof.

## Two modes

```
/red-green-e2e red <ticket-id>
/red-green-e2e green <ticket-id>
```

Mode: `$mode`. Ticket: `$ticket_id`.

One script does the fixed work: hashing the case, saving the verdict, and applying the
gate. `SDLC` below means `${CLAUDE_SKILL_DIR}/../implement/scripts/sdlc.sh`.

## Saving a verdict

After every blind run, pass its output to the script unchanged. Copy the whole block
the blind agent returned. Do not reformat it:

```bash
SDLC verdict <ticket-id> <red|green> <absolute path to the case> <<'VERDICT'
<the blind output, exactly as returned>
VERDICT
```

It saves the output to `.sdlc/runs/<ticket-id>/`, updates the red or green line in
`state.md`, and exits with the gate result:

| Exit | Meaning | Do |
|---|---|---|
| 0 | gate met | continue |
| 1 | gate not met | see "When red returns PASS" or "When green returns FAIL" |
| 2 | BLOCKED | see "When any run returns BLOCKED" |
| 3 | malformed output | run the blind case again |
| 4 | the case changed since red | the proof is void, see "Never edit the case" |

In red mode it also records the case hash. In green mode it checks the hash against the
one recorded at red. The hash covers the case and every file in `docs/test-cases/lib/`.

## Red mode — prove the failure

1. **Find or write the case** at `docs/test-cases/<ticket-id>-<slug>.md`, following
   [test-case-format.md](test-case-format.md). Create `docs/test-cases/` if it is not
   there and say that you did.
2. **Give it the server script.** A case that starts a server needs
   `docs/test-cases/lib/serve.sh`. If that file does not exist, copy it there:
   ```bash
   mkdir -p docs/test-cases/lib && cp ${CLAUDE_SKILL_DIR}/../serve/scripts/serve.sh docs/test-cases/lib/
   ```
   Commit it with the case. Never replace an existing copy in the middle of a ticket,
   because that changes the hash of every open proof.
3. **Pick where red runs.** With no fix in your working tree, red runs on the case where
   it is. With the fix already there, make a checkout of the base branch that holds the
   case. For example, red must run again after a case edit:
   ```bash
   SDLC tree docs/test-cases/<ticket-id>-<slug>.md
   ```
   It prints `case=<path>`. Use that path for the blind run and the verdict. Remove the
   checkout right after the verdict with `SDLC tree --rm <tree path>`. While it exists,
   test runners in your checkout can find its files.
4. **Run it blind.** Call the Skill tool with `blind-e2e` and the absolute path to the
   case. Pass nothing else. Never paste the ticket, the diff, or your own expectations
   into that call.
5. **Save the verdict** with `SDLC verdict <ticket-id> red <case path>`. Red gates on
   FAIL. A FAIL verdict is the proof the bug is real. Anything else stops the chain.

## When red returns PASS

Stop. Do not proceed, and do not decide which of these it is. Put all three to the
human and wait:

1. **The bug is not reproducible** — it needs a state, an account, or data the case does
   not set up.
2. **The test case is wrong** — it checks something next to the reported behavior rather
   than the behavior itself.
3. **It is not a bug** — the software is working as designed.

The third is the one that gets skipped, and it is the one that wastes the most time.
A clean fix to intended behavior is still a change nobody asked for.

## When any run returns BLOCKED

BLOCKED means the case could not be run. It is never a pass and never a fail.

Read the REASON line, repair the Setup section, and rerun. The reason is written to be
repairable in one round — an omitted account, an omitted port, an ambiguous step.

The verdict script counts BLOCKED verdicts per case. When it prints `STOP`, three
BLOCKED verdicts hit the same case: stop the chain and go to the human. At that point
the problem is the environment or the ticket, not the wording.

## Green mode — prove the fix

1. **Use the same file.** Do not open it to edit. Do not improve it.
2. **Run it blind.** Same call, nothing added. Use the case in your working tree, which
   holds the fix.
3. **Save the verdict** with `SDLC verdict <ticket-id> green <case path>`. Green gates
   on PASS. Exit 4 means the case changed since red, and the proof is void.

## Never edit the case between red and green

The two runs are only comparable if the question did not change. Editing the case
between them means the red run and the green run answered different questions, and
neither verdict means anything.

If the hash differs, say so loudly, state that the proof is void, and stop. Offer to
start over with a fresh red run. Do not quietly accept the green.

The temptation comes at a specific moment: green returns FAIL, the case looks slightly
wrong, and adjusting one line would make it pass. That is the moment the proof dies.

## When green returns FAIL

The fix is not done. Hand the verdict block back to `tdd-implement` and let the loop
continue — the REASON line is the next failing case.

The verdict script counts failed green runs. When it prints `STOP`, three green runs
failed: stop and go to the human. Three failures means the understanding is wrong, not
the code.

## Writing standard

Write everything this skill produces in Simplified Technical English: short sentences,
active voice, one word for one meaning, the answer first, no jargon left unexplained.
Keep paths, commands and numbers exact.

A sentence that can be read two ways costs a round here. Call the `simple-english` skill
if it is installed. Short form: [WRITING-STANDARD.md](https://github.com/cjaymartin/cjm-skills-marketplace/blob/main/WRITING-STANDARD.md)
