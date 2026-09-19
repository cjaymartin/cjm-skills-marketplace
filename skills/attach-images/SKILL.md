---
name: attach-images
description: Publishes screenshots or other images to a side branch of the GitHub repository and prints a permanent link for each. It needs no browser and does not change the working tree. Use it to add screenshots, before-and-after images, or visual evidence to a pull request, issue, or comment.
allowed-tools: Bash(node ${CLAUDE_SKILL_DIR}/scripts/attach-images.mjs *)
---

# Attach images

GitHub has no API to upload an image to an issue or a pull request. This skill puts the
images in the repository itself, on a branch that is never merged.

```bash
node ${CLAUDE_SKILL_DIR}/scripts/attach-images.mjs pr-42 before.png after.png
```

The first argument names the branch: `attachments/pr-42`. Use `pr-<number>` or
`issue-<number>`. The script commits with git plumbing and a scratch index. It does not
check out a branch, stash, or touch your working tree or index.

It prints one URL per file:

```
pushed 2 file(s) to attachments/pr-42 at 3f9c2a1
https://github.com/owner/repo/blob/3f9c2a1.../before.png?raw=1
https://github.com/owner/repo/blob/3f9c2a1.../after.png?raw=1
```

Each link names the commit, not the branch, so it keeps working after more images land.
The links work in private repositories for anyone who can see the repository.

## Putting the links in the PR

Embed each link as an image in the PR body or a comment:

```markdown
![Cart total after the fix](https://github.com/owner/repo/blob/3f9c2a1.../after.png?raw=1)
```

Write what each image shows next to it. If the image does not render, the text still
tells the reader what it proves.

## Writing standard

Write everything this skill produces in Simplified Technical English: short sentences,
active voice, one word for one meaning, the answer first, no jargon left unexplained.
Keep paths, commands and numbers exact.
