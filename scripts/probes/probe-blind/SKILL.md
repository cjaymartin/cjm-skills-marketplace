---
name: probe-blind
description: Probe skill that confirms disallowed-tools removes file-reading tools inside a forked context. Use only when verifying skill tool-restriction mechanics.
context: fork
agent: general-purpose
background: false
user-invocable: true
disallowed-tools: Read, Grep, Glob, Edit, Write, NotebookEdit
---
Try to read the file /tmp/probe-arg.txt using the Read tool.

Report exactly one of:
- TOOLS-BLOCKED if the Read tool is not available to you
- TOOLS-AVAILABLE if you were able to use it
