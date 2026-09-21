---
name: independent-implement
description: Runs a ticket end to end without waiting on the human, guessing any answer whose rework cost is small, stopping only when a wrong guess would be expensive, and ending with a numbered list of every guess so answers can be changed and the affected steps re-run. Use when asked to work a ticket unattended, in the background, or while the human is away.
disable-model-invocation: true
arguments: ticket_ref
argument-hint: [ticket-ref]
---

# Work a ticket unattended

Ticket: `$ticket_ref`

Same chain as `implement`. The difference is what happens at a gate: instead of waiting,
you decide, write down what you decided, and keep going.

This is ordinary agile practice. If the answer is not in the spec and nobody is
available, either choice is usually fine, **as long as it is written down**. The writing
down is the whole contract. A guess that is not logged is not a guess, it is a silent
decision, and silent decisions are what make unattended work untrustworthy.

## 1. Run implement with an autonomous gate policy

Call the Skill tool with `implement` and pass `$ticket_ref`.

Tell it, in the same invocation, that the gate policy is **autonomous**: at every human
gate it applies the assumption protocol below instead of waiting.

Everything else about the chain is unchanged. The blind proofs still gate on FAIL then
PASS. Nothing here weakens a verdict.

## 2. The 20-minute rule

At each question, ask one thing: **if this guess is wrong, how much agent work has to be
redone?**

- **Under 20 minutes** — guess, log it, continue.
- **20 minutes or more** — stop and wait for the human.
- **Cannot estimate it** — treat it as 20 minutes or more and stop.

Estimate the **rework**, not the difficulty of the decision. A hard question with a cheap
undo gets guessed. An easy question with an expensive undo does not.

### Usually under 20 minutes

- A name, a slug, a ticket id, a file location.
- The wording of a test case, **before** the red run.
- An error or log message.
- Which of two equivalent library calls to use.
- Adding a test.
- A change that stays inside one file.

### Usually 20 minutes or more

- Anything that voids the red proof. Once red has run, the test case is frozen, so a
  question that would change it now costs the whole proof.
- Changing a public interface, an exported type, or a data shape that other code depends
  on.
- A database migration or a data backfill.
- Choosing between two approaches that leave the modules in different shapes.
- Deleting or rewriting work already finished in this run.
- Anything that means running the full suite from scratch more than once again.

### The same question can change price

"How should this test case read?" costs minutes before the red run and costs the proof
after it. Price the question at the moment you meet it, not from this list alone.

## 3. The assumption protocol

When you guess:

1. Say the question out loud in your output. Do not guess quietly.
2. Say the answer you are taking and why. If the `jev` skill is available and the answer
   is one of a fixed set of options, send the question to Jev first. Take its pick when
   its confidence is 0.7 or higher, and put `(Jev, 0.NN)` in the `Because:` line.
3. Append the entry to `.sdlc/<ticket-id>/assumptions.md`, immediately, before continuing.
4. Continue.

The human can interrupt at any point. Announcing the guess in the same turn is what makes
that possible. A guess made silently removes their chance to catch it.

When you stop instead:

1. Say the question.
2. Say what it would cost to get it wrong, and why that is over the line.
3. Write the run state to `.sdlc/<ticket-id>/state.md` so the run resumes cleanly.
4. Wait.

## 4. The log format

`.sdlc/<ticket-id>/assumptions.md`, one entry per guess, numbered `A1`, `A2`, and on:

```markdown
## A1 — <the question, as a question>

Guessed: <the answer taken>
Because: <one line>
Rework if wrong: <minutes> — <what would have to be redone>
Affects from: <research | red | implement | green | review>
```

`Affects from` names the **earliest** step that would have to run again. It is the field
that makes changing an answer cheap, so get it right rather than guessing wide.

## 5. The end-of-run summary

Finish every run with the list, even when nothing was guessed. Say "no assumptions were
needed" rather than printing nothing.

```markdown
## Assumptions taken

| # | Question | Guessed | Rework if wrong | Re-runs from |
|---|---|---|---|---|
| A1 | <question> | <answer> | 5 min | implement |
| A2 | <question> | <answer> | 15 min | red |

Reply with the number and a different answer to change one, for example:
A2 should be <answer>
```

Put the most expensive rework at the top. That is the one worth the human's attention
first.

## 6. Changing an answer

When the human changes an answer:

1. Update that entry in `.sdlc/<ticket-id>/assumptions.md`. Keep the old value on a
   `Was:` line. The history is the point.
2. Re-enter the chain at the step named in `Affects from`.
3. Run forward from there. Do not restart the whole chain.
4. Re-check every later assumption. One of them may have rested on the answer that just
   changed. Any that no longer holds gets re-decided and re-logged.
5. Print the summary again.

When the change re-enters at `red`, the old proof is void. Say so plainly and run red
again. Never carry a red verdict across a change to the question it answered.

## 7. What this does not change

The blind verdicts. `blind-e2e` still cannot see the code, red still has to FAIL, green
still has to PASS, and BLOCKED is still never a pass or a fail.

Autonomy applies to questions of preference and approach. It never applies to evidence.

## Writing standard

Write everything this skill produces in Simplified Technical English: short sentences,
active voice, one word for one meaning, the answer first, no jargon left unexplained.
Keep paths, commands and numbers exact.

A sentence that can be read two ways costs a round here. Call the `simple-english` skill
if it is installed. Short form: [WRITING-STANDARD.md](https://github.com/cjaymartin/cjm-skills-marketplace/blob/main/WRITING-STANDARD.md)
