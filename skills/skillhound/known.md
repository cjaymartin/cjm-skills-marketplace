# Known findings

One line per finding: the date, what it was, and what happened to it. A hunt leaves
these out of its report, unless the counts show the problem came back.

## Built

- 2026-09-19: dev servers started, polled, and killed by hand. Built `serve`.
- 2026-09-19: test output cut by tail or grep, then the tests ran again. Built `test-summary`.
- 2026-09-19: `gh pr view` and `gh run view` polling loops. Built `pr-status`.
- 2026-09-19: screenshots put on PRs a different way in each project. Built `attach-images`.
- 2026-09-19: pull-and-restart watchers written per project. Built `watch-origin`.
- 2026-09-19: blind-e2e verdicts saved, hashed, and gated by hand. Built `sdlc.sh verdict`.
- 2026-09-19: base-commit trees for red runs made by hand. Built `sdlc.sh tree`.
- 2026-09-19: resume state rebuilt by hand. Built `sdlc.sh status`.
- 2026-09-19: self-review diffs and reviewer inputs made by hand. Built `sdlc.sh review`.
- 2026-09-19: tickets read with a different command each run. Built `fetch-ticket.sh`.

## Turned down

- 2026-09-19: lifeos skills (populate-daily, build-carts). The user excluded lifeos.
- 2026-09-19: bloodsuckers canvas screenshot kit and preflight. One project only.
- 2026-09-19: inline `python3 -` file rewrites. That is a CLAUDE.md rule, not a skill.
