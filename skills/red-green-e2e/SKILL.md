---
name: red-green-e2e
description: Proves a reported bug is real before the fix and proves it is gone after, by running the same plain-English test case through a source-blind agent twice. Use when replicating a failure, verifying a fix, or whenever a ticket needs end-to-end proof rather than a unit test.
arguments: mode ticket_id
argument-hint: [red|green] [ticket-id]
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

## Red mode — prove the failure

1. **Find or write the case** at `docs/test-cases/<ticket-id>-<slug>.md`, following
   [test-case-format.md](test-case-format.md). Create `docs/test-cases/` if it is not
   there and say that you did.
2. **Record its hash** so the green run can prove the question did not change:
   ```bash
   mkdir -p .sdlc/<ticket-id>
   sha256sum docs/test-cases/<ticket-id>-<slug>.md >> .sdlc/<ticket-id>/state.md
   ```
3. **Run it blind.** Call the Skill tool with `blind-e2e` and the absolute path to the
   case. Pass nothing else. Never paste the ticket, the diff, or your own expectations
   into that call.
4. **Gate on FAIL.** A FAIL verdict is the proof the bug is real. Anything else stops
   the chain.
5. **Persist the verdict** to `.sdlc/runs/<ticket-id>/red-<timestamp>.md`, verbatim.
   The blind agent cannot write files, so this is your job.

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

Three BLOCKED verdicts on the same case stops the chain and goes to the human. At that
point the problem is the environment or the ticket, not the wording.

## Green mode — prove the fix

1. **Read the same file.** Do not open it to edit. Do not improve it.
2. **Re-hash it** and compare against the hash recorded at red.
3. **Run it blind.** Same call, same path, nothing added.
4. **Gate on PASS.**
5. **Persist the verdict** to `.sdlc/runs/<ticket-id>/green-<timestamp>.md`.

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

After three failed green attempts, stop and go to the human. Three failures means the
understanding is wrong, not the code.

## Writing standard

Write everything this skill produces in Simplified Technical English: short sentences,
active voice, one word for one meaning, the answer first, no jargon left unexplained.
Keep paths, commands and numbers exact.

A sentence that can be read two ways costs a round here. Call the `simple-english` skill
if it is installed. Short form: [WRITING-STANDARD.md](https://github.com/cjaymartin/cjm-skills-marketplace/blob/main/WRITING-STANDARD.md)
