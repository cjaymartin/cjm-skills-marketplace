---
name: probe-arg
description: Probe skill that confirms a positional argument interpolates inside a shell command injection. Use only when verifying skill argument mechanics.
argument-hint: [file-path]
---
Injected file content follows.

!`cat "$1"`

Report whether the line above reads PROBE-ARG-CONTENT or is empty.
