---
name: serve
description: Starts, lists, and stops local dev servers on free ports with one command each, and waits until the server answers. Use it to run an app, API, or dev server in the background. Also use it to find a server's port, or to restart or stop a server. It replaces nohup, sleep-and-curl loops, pkill, and fuser.
allowed-tools: Bash(${CLAUDE_SKILL_DIR}/scripts/serve.sh *)
---

# Serve

One script does the whole server lifecycle. It picks a free port, starts the command,
waits until the port answers, and stops only the process it started.

```bash
${CLAUDE_SKILL_DIR}/scripts/serve.sh start --name api --ready /health -- node dist/main.js
${CLAUDE_SKILL_DIR}/scripts/serve.sh start --name web -- npx vite --port {port} --strictPort
${CLAUDE_SKILL_DIR}/scripts/serve.sh ls
${CLAUDE_SKILL_DIR}/scripts/serve.sh port api
${CLAUDE_SKILL_DIR}/scripts/serve.sh logs api 80
${CLAUDE_SKILL_DIR}/scripts/serve.sh stop api
${CLAUDE_SKILL_DIR}/scripts/serve.sh stop --all
```

## start

- The command runs with `PORT=<port>` set, and every `{port}` in it is replaced. Use
  `{port}` for tools that take a flag, such as vite.
- `--port auto` is the default. If something outside your control fixes the port, give
  `--port N`.
- `--ready PATH` waits for an HTTP answer below 500 from that path. Without it, start
  waits until the port accepts a connection.
- `--dir DIR` runs the command in DIR. The default is the current directory.
- One server needs another one's port? Put it in the environment:
  `API_URL=http://localhost:$(serve.sh port api) serve.sh start --name web -- ...`

It prints one line. Read the port and the URL from it:

```
OK name=api port=23817 pid=4242 url=http://localhost:23817 http=200 log=/tmp/serve-1000/.../api/log
```

If the command exits early or never answers, start prints the log tail, stops what it
started, and exits 1. Fix the cause from that log. Do not retry the same command.

## Stopping

Stop a server with `serve.sh stop NAME`. It ends the whole process group, and it checks
that the pid still belongs to the process it started.

A server you did not start with this script belongs to someone else. Leave it running
and pick another port. Other agents and the user share this machine.

## Answering "what port?"

Run `serve.sh ls`. It lists every running server started by this script, in every
checkout, with its port, pid, and command.

## Writing standard

Write everything this skill produces in Simplified Technical English: short sentences,
active voice, one word for one meaning, the answer first, no jargon left unexplained.
Keep paths, commands and numbers exact.
