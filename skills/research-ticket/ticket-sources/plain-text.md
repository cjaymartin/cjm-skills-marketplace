# Ticket source: plain text

Every adapter returns the same four things: **id, title, body, discussion.**

## When to use this one

Nothing else matched. The reference is the ticket itself: pasted text, a sentence in
chat, a forwarded message.

This is also the fallback when another adapter fails.

## What to return

| Field | Where it comes from |
|---|---|
| id | a short slug the human confirms |
| title | one line, from the human |
| body | the text as given |
| discussion | empty, unless the paste contains a thread |

## Ask, do not invent

**Ask the human for the id and the title.** Both are used in file paths and in every
later step, so a guess propagates into `docs/research/`, `docs/test-cases/` and
`.sdlc/` and is awkward to unpick later.

Propose a slug and let them correct it. One question, one answer.

## Expect it to be thin

Pasted tickets are usually missing what a form would have required: the version, the
environment, the account, the steps that led there. Note each gap in the brief's
**Open questions** section rather than filling it in from likelihood.
