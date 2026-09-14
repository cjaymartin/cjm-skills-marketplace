---
name: probe-arg2
description: Probe skill that confirms the ARGUMENTS placeholder interpolates inside a shell command injection. Use only when verifying skill argument mechanics.
argument-hint: [file-path]
---
Injected file content follows.

!`cat "$ARGUMENTS"`

Report whether the line above reads PROBE-ARG-CONTENT or is empty.
