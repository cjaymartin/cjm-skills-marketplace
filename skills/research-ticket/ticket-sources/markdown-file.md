# Ticket source: a markdown file

Every adapter returns the same four things: **id, title, body, discussion.**

## When to use this one

The reference is a path ending in `.md`.

## How to read it

Read the file.

## What to return

| Field | Where it comes from |
|---|---|
| id | the file's basename without the extension, for example `docs/tickets/slow-export.md` gives `slow-export` |
| title | the first level-one heading, or the basename if there is none |
| body | everything up to the first section that reads as discussion |
| discussion | any section headed with a name, a date, or a comment marker |

## If the file has no structure

Many ticket files are one block of prose. That is fine. Put all of it in body and leave
discussion empty. Do not invent a split that is not there.

## If the file does not exist

Say the exact path you tried. Do not search for a file with a similar name — a near
match is how you end up researching the wrong ticket.
