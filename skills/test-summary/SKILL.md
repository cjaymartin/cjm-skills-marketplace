---
name: test-summary
description: Runs a test, type-check, or lint command once, saves the full log, and prints only the totals and each failure. Use it for every test run (vitest, jest, node --test, pytest, go test, tsc) in place of piping the output through tail, head, or grep.
allowed-tools: Bash(${CLAUDE_SKILL_DIR}/scripts/testsum.sh *)
---

# Test summary

```bash
${CLAUDE_SKILL_DIR}/scripts/testsum.sh -- pnpm vitest run src/cart
${CLAUDE_SKILL_DIR}/scripts/testsum.sh --lines 200 -- npx jest --ci
```

It prints:

```
exit=1 time=4s log=/tmp/testsum.Ab12Cd lines=412
--- summary
 Test Files  1 failed | 9 passed (10)
      Tests  1 failed | 88 passed (89)
--- failures (first 120 lines; the rest is in the log)
 FAIL  src/cart.test.ts > applies the discount
AssertionError: expected 90 to be 81
...
```

The script exits with the test command's own exit code.

## The log is the whole output

Each run saves everything, with the color codes removed, to the `log=` path. If the
summary cut off what you need, read that file with `grep -n` or `sed -n`. If the code did
not change, do not run the tests again.

## Writing standard

Write everything this skill produces in Simplified Technical English: short sentences,
active voice, one word for one meaning, the answer first, no jargon left unexplained.
Keep paths, commands and numbers exact.
