---
name: local-secrets
description: Puts every secret a task needs (API key, token, password, client secret, webhook secret, database URL with a password) into one gitignored .env.<environment> file per environment (.env.development, .env.production) that the user fills in by hand, with steps to get each value written next to it. Use it whenever a command, script, test, or config needs a secret the user must supply. Use it instead of asking the user to paste a secret in chat or to edit a long command.
allowed-tools: Bash(${CLAUDE_SKILL_DIR}/scripts/secrets.sh *)
---

# Local secrets

The user keeps the secrets for each environment of a project in one file at the root of
the main checkout: `.env.development`, `.env.staging`, `.env.production`, and so on. You
add the keys. The user fills in the values. You never see the values.

You must make sure git ignores the file before any value goes in it. `need` does this for
you. If no rule covers the file, it adds `.env.*` to the `.gitignore` of the checkout you
work in, with `!` rules that keep `.env.example`, `.env.sample` and `.env.template`
committable. Then it checks with `git check-ignore`. If git still does not ignore the
file, it stops with exit 1 and writes nothing.

When `need` prints `gitignored ... Commit this change.`, commit that `.gitignore` with the
rest of your work, so the rule reaches every clone. In a linked worktree it also prints
`also excluded ... info/exclude`: that keeps the file ignored in the main checkout until
your `.gitignore` change is merged.

Give `--env` first, before the command. Without it, the environment is `development`.

```bash
${CLAUDE_SKILL_DIR}/scripts/secrets.sh --env production need STRIPE_SECRET_KEY \
  --used-by "the checkout tests in tests/checkout.test.ts" \
  --how "Sign in at https://dashboard.stripe.com with the live account. Make sure Test mode (top right) is off." \
  --how "Open Developers > API keys." \
  --how "Next to 'Secret key', click Reveal live key and copy it. It starts with sk_live_." \
  --url https://dashboard.stripe.com/apikeys
${CLAUDE_SKILL_DIR}/scripts/secrets.sh --env production check STRIPE_SECRET_KEY OPENAI_API_KEY
${CLAUDE_SKILL_DIR}/scripts/secrets.sh --env production open STRIPE_SECRET_KEY OPENAI_API_KEY
${CLAUDE_SKILL_DIR}/scripts/secrets.sh --env production run -- npm run migrate
${CLAUDE_SKILL_DIR}/scripts/secrets.sh --env staging path
```

`need` and `check` print one line per key, then the environment and the file path:

```
missing STRIPE_SECRET_KEY line=12
env=production
file=/home/cj/code/shop/.env.production
at=/home/cj/code/shop/.env.production:12
```

Exit 0 means every key has a value. Exit 3 means a key is missing. `at=` is the path and
line of the first missing key.

## The rules

- Do not ask the user to paste a secret in chat.
- Do not give the user a command with a blank to fill in, such as
  `export API_KEY=<your key>` or `curl -H "Authorization: Bearer YOUR_TOKEN"`.
- Do not read, `cat`, `grep`, or print a secrets file. Use `check` to learn which keys are set.
- Do not write a value into the file. Only the user does that.
- Do not make a second file for the same environment. Use the one that `path` prints, in
  every session.
- Do not put a secret in a commit, a log, a test fixture, a PR, or another tool's input.

## When a task needs a secret

1. Pick the environment. Use the one the task acts on: `production` for live data or a
   live deploy, `staging` for staging, `development` for local work and tests. Ask the
   user if the task does not make it clear. Use the same name the project uses, if it
   has one.
2. Pick the variable name the code or tool already reads. Search the code first. If
   nothing reads one yet, use the name the vendor's docs use.
3. Run `need` for each key, with `--env`. It creates the file if needed. It adds the file to
   `.gitignore` if nothing ignores it yet. It adds the key only if the key is not there.
4. If every key is `set`, continue the task. Do not tell the user.
5. If a key is `missing`, run `open` once with every key the task needs. It opens the
   file in VS Code at the first missing key, so the user does not have to find it. It uses
   VS Code's own CLI when `code` is not on PATH. It falls back to Cursor or another
   editor only when there is no VS Code. It also copies `PATH:LINE` to the clipboard. It
   prints:

   ```
   opened=code
   copied=yes
   at=/home/cj/code/shop/.env.production:12
   ```

6. Stop that part of the task. Tell the user in this form:

   > I need the production `STRIPE_SECRET_KEY`. I opened `.env.production` in VS Code at
   > line 12. Fill in the value after `STRIPE_SECRET_KEY=`. The steps to get it are just
   > above that line. Tell me when it is saved.
   >
   > `/home/cj/code/shop/.env.production:12`

   - Say where you opened it, from `opened=`. If it is `none`, say that the path is on
     the clipboard (if `copied=yes`), so the user can paste it into the editor's "Go to
     file" box (Cmd+P in VS Code).
   - Always give the plain `PATH:LINE` from `at=`, in backticks, on its own line. Many
     terminals and IDEs let the user Cmd+click it.
   - Do not make `vscode://` or other editor links. Chat apps and many terminals block
     them.
   - Name every missing key in one message, each with its line number.
   - Always name the environment. A production value in the wrong file is a real risk.
   - `open` starts no editor over SSH or in a cloud container, because the user cannot
     see it there. In that case, say the file is on that machine, not on the user's.
   - If the user names an editor, set `LOCAL_SECRETS_EDITOR` to its command, such as
     `cursor` or `webstorm`, before the call.
7. When the user says it is saved, run `check` again. Continue only on exit 0.

Do other work that needs no secret while you wait, if there is some.

## Write the steps for someone who has never done it

The `--how` steps are the only help the user gets. Write them so that the user does not
need to search.

- Give one `--how` per step. Start each with a verb.
- Name the exact site, menu, button, and page. Give the direct URL with `--url`.
- Say which account, project, or mode to use. Match it to `--env`: live keys for
  `production`, test or sandbox keys for `development`.
- Say which scopes or permissions to tick, and nothing more than the task needs.
- Say what the value looks like, such as "starts with `ghp_`" or "a 64-character hex string".
- Say if the vendor shows the value only once.
- Say what to do for a value the user makes up, such as a local database password.
- Use `--used-by` to say what needs the key and why.

If you are not sure of a vendor's current menus, read their docs first.

## Using the secrets

- To run a command with the secrets, use `--env ENV run -- CMD`. It loads each filled key
  from that environment's file into the command's environment. The values do not show in
  your command or in its echo. Values in the file win over the shell's.
- Only the file counts for `check`. A variable already set in the shell does not count,
  because it can be a value for another environment.
- Some tools read `.env.production` and the like on their own, such as Next.js and Vite.
  You still use `run` when you start them by hand, so that the right file is loaded.
- If a tool reads a different file or a config setting, point that setting at an
  environment variable. Then start the tool with `run`.
- Before you run a command with `--env production`, tell the user what it will change.
  Wait for a yes if it writes to live data.

## If something goes wrong

- Some projects commit `.env.production` with defaults that are not secret. Then the
  script uses `.env.production.local` for secrets instead. Use the path it prints.
- `need` exits 1 and says the file is tracked by git: the file was committed before. Tell
  the user. Do not write to it. Git history may still hold old secrets there, so the user
  should also rotate them.
- The project has a secrets file with another name, such as `.env`, `.env.local`, or
  `.dev.vars`: keep using the `.env.ENV` file for new keys. Tell the user once that the
  other file exists.
- Set `LOCAL_SECRETS_FILE` only if the user asks for another path.

## Writing standard

Write everything this skill produces in Simplified Technical English: short sentences,
active voice, one word for one meaning, the answer first, no jargon left unexplained.
Keep paths, commands and numbers exact.
