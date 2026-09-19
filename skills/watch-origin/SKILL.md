---
name: watch-origin
description: Keeps a local checkout and its dev server level with the remote branch. It pulls, reinstalls, and restarts the server each time the remote moves.
disable-model-invocation: true
argument-hint: [dev-command]
---

# Watch origin

Run the watcher in the background with the command the user gave. If they gave none, use
the repository's dev script, for example `pnpm dev` or `npm run dev`:

```bash
node ${CLAUDE_SKILL_DIR}/scripts/watch-origin.mjs [options] -- <command>
```

The user's input is `$ARGUMENTS`. Put any option from it before `--` and the command
after it.

Every 60 seconds it fetches. If the upstream branch moved and this branch can
fast-forward, it pulls. If a lockfile or `package.json` changed, it reinstalls. Then it
restarts the command.

It never merges and never touches a dirty tree. In those cases it prints what is in the
way, once, and keeps watching.

## Options

- `--interval SEC` changes how often it looks.
- `--install "CMD"` sets the install command. Without it, the lockfile picks one: pnpm,
  npm, yarn, or bun.
- `--once` looks one time and does a safe pull. Then it exits and runs no command.

Tell the user how to stop it. From this session, end the background task. From their own
terminal, press Ctrl-C. Stopping the watcher also stops the command it runs.

## Writing standard

Write everything this skill produces in Simplified Technical English: short sentences,
active voice, one word for one meaning, the answer first, no jargon left unexplained.
Keep paths, commands and numbers exact.
