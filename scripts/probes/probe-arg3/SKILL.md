---
name: probe-arg3
description: Probe skill that confirms a named argument interpolates inside a shell command injection. Use only when verifying skill argument mechanics.
arguments: casepath
argument-hint: [file-path]
---
Injected file content follows.

!`cat "$casepath"`

Report whether the line above reads PROBE-ARG-CONTENT or is empty.
