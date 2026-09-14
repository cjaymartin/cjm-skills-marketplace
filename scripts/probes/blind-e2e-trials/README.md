# blind-e2e trial cases

Three cases that check `blind-e2e` can still tell its three verdicts apart. Run all
three after any edit to `skills/blind-e2e/SKILL.md`.

| Case | Required verdict |
|---|---|
| `echo-works.md` | PASS |
| `echo-fails.md` | FAIL, with a REASON naming the mismatch |
| `echo-blocked.md` | BLOCKED, naming the missing Setup section — **never** FAIL |

Invoke each as `blind-e2e` with the absolute path to the case.

If `echo-works.md` and `echo-fails.md` return the same verdict, the skill is worthless
and nothing downstream of it can be trusted. Fix that before anything else.

Results as of 2026-09-14: all three correct.
