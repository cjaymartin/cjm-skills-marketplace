# Ticket source: a GitHub issue

Every adapter returns the same four things: **id, title, body, discussion.**

## When to use this one

The reference looks like `#123`, `owner/repo#123`, or a github.com issue URL.

## How to read it

```bash
gh issue view <number> --json number,title,body,comments,labels,state,url
```

For an issue in another repository:

```bash
gh issue view <number> --repo <owner>/<repo> --json number,title,body,comments,labels,state,url
```

## What to return

| Field | Where it comes from |
|---|---|
| id | `gh-<number>` |
| title | the `title` field |
| body | the `body` field |
| discussion | every entry in `comments`, oldest first, each with its author |

## Also check

**Linked pull requests**, because one may already be attempting this work:

```bash
gh issue view <number> --json closedByPullRequestsReferences
```

**The state.** If the issue is already `CLOSED`, say so at the top of the brief and ask
the human whether to continue before doing any more reading. A closed issue usually
means the work is done, duplicated, or rejected.

**The labels.** They often carry the reproduction environment, the affected version, or
a triage decision that the body leaves out.

## If `gh` fails

An authentication error or a missing repository is not a reason to guess. Report the
exact error and fall back to [plain-text.md](plain-text.md) by asking the human to paste
the issue.
