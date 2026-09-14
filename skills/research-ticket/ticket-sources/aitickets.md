# Ticket source: aitickets — NOT IMPLEMENTED

This adapter is a placeholder. Until it is built, fall back to
[plain-text.md](plain-text.md).

## What this will be

A reader for the ticketing system under development at `~/WebstormProjects/aitickets`.

## The contract any adapter must satisfy

Return exactly these four things, and nothing the rest of the skill has to guess at:

| Field | Rules |
|---|---|
| id | unique, safe in a file path, stable across reads of the same ticket |
| title | one line |
| body | the reported problem, as reported |
| discussion | every comment, oldest first, each with its author |

## What to decide when building it

1. **How a reference is recognised.** Every adapter is chosen by the shape of the
   reference. This one needs a shape no other adapter claims — `#123` is already taken
   by GitHub.
2. **How it is read.** A CLI, an HTTP endpoint, or a file on disk. A CLI is easiest to
   make work without credentials living in a skill.
3. **What the id looks like.** Prefix it, the way GitHub issues become `gh-<number>`,
   so ids from two systems can never collide in `docs/research/`.
