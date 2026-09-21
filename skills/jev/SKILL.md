---
name: jev
description: Sends a multiple-choice or yes/no decision to Jev, a cheap and fast decision model from TypeSafe, and returns the pick with a confidence. Use it whenever you are about to pick between a fixed set of options on your own, or about to ask the user a low-stakes multiple-choice question. Examples are a file location, a name, which of two equal approaches, whether a guess is safe, or which handler fits a request. Not for open questions, writing text, or reasoning.
allowed-tools: Bash(${CLAUDE_SKILL_DIR}/scripts/jev.py *)
---

# Jev

Jev picks one answer from a list you give it. It does not chat, write, or reason. It is
much cheaper than you are, and it is calibrated: its confidence means something.

```bash
${CLAUDE_SKILL_DIR}/scripts/jev.py --state "<the facts>" --ask "<the question>" \
  --option edit="Edit the file directly" --option plan="Write a plan first"
${CLAUDE_SKILL_DIR}/scripts/jev.py --state "<the facts>" --ask "<the question>" --yes-no
echo "<long facts>" | ${CLAUDE_SKILL_DIR}/scripts/jev.py --state - --ask "..." --option ...
```

It prints the answer on line 1, then the numbers:

```
edit
confidence=0.68 edit=0.79 ask=0.21 plan=0.00
```

## When to call it

Call Jev when both are true:

1. The answer is one of a fixed set of options that you can list.
2. A wrong answer is cheap to undo.

Typical cases: where a file or test goes, a name, which of two equal library calls to
use, whether a request is in scope, which skill or agent fits a task, and whether a guess
is safe to take without the user.

Do not call Jev for:

- A question with no fixed options. Make the options first, then ask.
- A decision the user owns: a public interface, a data migration, money, deletion,
  anything that is hard to undo. Ask the user.
- A fact you can look up in the code. Look it up.

## Write the state for a model that cannot reason

Jev reads only the state and the options. It does not see the repo or this chat.

- Put every fact that decides the answer in the state. Keep it short and concrete.
- Give each option a description that says what it means, not only a key.
- Ask one question per call.
- Do not put secrets, keys, or personal data in the state. It goes to TypeSafe.

## Use the confidence

- `confidence` 0.7 or higher: take the answer. Say in one line what Jev picked.
- Under 0.7: Jev is split. Decide yourself, or ask the user if the choice is theirs.
- For `--yes-no`, treat `p_yes` between 0.3 and 0.7 as split.

If the script exits 2, the call failed. Decide yourself and continue. Do not retry in a
loop.

## Setup

Get a key at https://console.typesafe.ai/keys. The script reads it from
`$TYPESAFE_API_KEY`, else from `~/.config/jev/api_key`. Run
`${CLAUDE_SKILL_DIR}/scripts/jev.py --self-test` to test the script without the network.
API docs: https://docs.typesafe.ai/llms.txt
