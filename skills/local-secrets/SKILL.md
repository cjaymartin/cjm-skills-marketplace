---
name: local-secrets
description: Puts every secret a task needs (API key, token, password, client secret, webhook secret, database URL with a password) into one gitignored .env.local file that the user fills in by hand, with steps to get each value written next to it. Use it whenever a command, script, test, or config needs a secret the user must supply. Use it instead of asking the user to paste a secret in chat or to edit a long command.
allowed-tools: Bash(${CLAUDE_SKILL_DIR}/scripts/secrets.sh *)
---

# Local secrets

The user keeps every secret for a project in one file: `.env.local` at the root of the
main checkout. Git ignores it. You add the keys. The user fills in the values. You never
see the values.

```bash
${CLAUDE_SKILL_DIR}/scripts/secrets.sh need STRIPE_SECRET_KEY \
  --used-by "the checkout tests in tests/checkout.test.ts" \
  --how "Sign in at https://dashboard.stripe.com and switch on Test mode (top right)." \
  --how "Open Developers > API keys." \
  --how "Next to 'Secret key', click Reveal test key and copy it. It starts with sk_test_." \
  --url https://dashboard.stripe.com/test/apikeys
${CLAUDE_SKILL_DIR}/scripts/secrets.sh check STRIPE_SECRET_KEY OPENAI_API_KEY
${CLAUDE_SKILL_DIR}/scripts/secrets.sh run -- npm test
${CLAUDE_SKILL_DIR}/scripts/secrets.sh path
```

`need` and `check` print one line per key, then the file path:

```
missing STRIPE_SECRET_KEY
file=/home/cj/code/shop/.env.local
```

Exit 0 means every key has a value. Exit 3 means a key is missing.

## The rules

- Do not ask the user to paste a secret in chat.
- Do not give the user a command with a blank to fill in, such as
  `export API_KEY=<your key>` or `curl -H "Authorization: Bearer YOUR_TOKEN"`.
- Do not read, `cat`, `grep`, or print `.env.local`. Use `check` to learn which keys are set.
- Do not write a value into the file. Only the user does that.
- Do not make a second secrets file. Use the one that `path` prints, in every session.
- Do not put a secret in a commit, a log, a test fixture, a PR, or another tool's input.

## When a task needs a secret

1. Pick the variable name the code or tool already reads. Search the code first. If
   nothing reads one yet, use the name the vendor's docs use.
2. Run `need` for each key. It creates the file if needed. It adds the file to
   `.gitignore` if nothing ignores it yet. It adds the key only if the key is not there.
3. If every key is `set`, continue the task. Do not tell the user.
4. If a key is `missing`, stop that part of the task. Tell the user in this form:

   > I need `STRIPE_SECRET_KEY`. Open `/home/cj/code/shop/.env.local`, and fill in the
   > value after `STRIPE_SECRET_KEY=`. The steps to get it are in the file above that
   > line. Tell me when it is saved.

   Give the full path from `file=`. Name every missing key in one message.
5. When the user says it is saved, run `check` again. Continue only on exit 0.

Do other work that needs no secret while you wait, if there is some.

## Write the steps for someone who has never done it

The `--how` steps are the only help the user gets. Write them so that the user does not
need to search.

- Give one `--how` per step. Start each with a verb.
- Name the exact site, menu, button, and page. Give the direct URL with `--url`.
- Say which account, project, or environment to use, such as test or live mode.
- Say which scopes or permissions to tick, and nothing more than the task needs.
- Say what the value looks like, such as "starts with `ghp_`" or "a 64-character hex string".
- Say if the vendor shows the value only once.
- Say what to do for a value the user makes up, such as a local database password.
- Use `--used-by` to say what needs the key and why.

If you are not sure of a vendor's current menus, read their docs first.

## Using the secrets

- To run a command with the secrets, use `run -- CMD`. It loads each filled key into the
  command's environment. The values do not show in your command or in its echo.
- Many tools read `.env.local` on their own, such as Next.js and Vite. You do not need
  `run` for them.
- If a tool reads a different file or a config setting, point that setting at an
  environment variable. Then start the tool with `run`.
- A key already set in the environment counts as `set`. CI can supply secrets that way.

## If something goes wrong

- `need` exits 1 and says the file is tracked by git: the file was committed before. Tell
  the user. Do not write to it. Git history may still hold old secrets there, so the user
  should also rotate them.
- The project has a secrets file with another name, such as `.env` or `.dev.vars`: keep
  using `.env.local` for new keys. Tell the user once that the other file exists.
- Set `LOCAL_SECRETS_FILE` only if the user asks for another path.

## Writing standard

Write everything this skill produces in Simplified Technical English: short sentences,
active voice, one word for one meaning, the answer first, no jargon left unexplained.
Keep paths, commands and numbers exact.
