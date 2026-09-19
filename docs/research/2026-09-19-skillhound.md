# Skillhound report, 2026-09-19

Source: 657 chat logs in `~/.claude/projects/` (29,546 tool calls). The extracted index is in `/tmp/skillhound/events.jsonl`. The extractor is `/tmp/skillhound/extract.py`.

## Status

Parts 1 and 2 are built on the `skillhound-scripts` branch. The user excluded lifeos. The bloodsuckers items in Part 3 stay in that project, because they fit one project only.

## The main result

One problem shows up in all three areas: the agent starts, polls, and kills local servers by hand. There are about 1,000 such calls in 87+ sessions and 3 projects. At least 5 of 9 BLOCKED blind-e2e verdicts came from start commands the agent wrote by hand. One script fixes this everywhere.

## Part 1: new skills (ranked)

| # | Skill | What it does | Evidence | Script? |
|---|---|---|---|---|
| 1 | `serve` | Start a command on a free port, wait for health, write a pidfile. Stop by pidfile only. List what runs. | ~1,000 calls. 26 user prompts like "what port?" and "server not running". `fuser -k` killed other agents' servers. | Yes, bash |
| 2 | `test-summary` | Run vitest, jest, or `node --test` with a JSON reporter. Print totals and each failure, then save the full log. | 1,411 test runs. 701 piped through `tail`. 138 reruns only because `tail` cut off the failure. | Yes, node |
| 3 | `pr-status` | Print one line per PR: mergeable, merge state, and each check. Add the failing log lines. `--wait` blocks until the checks finish. | 269 `gh pr view` calls. 38 hand-written `until ... sleep 15` loops. | Yes, bash |
| 4 | `attach-images` | Push screenshots to an `attachments/<ref>` branch with git plumbing. Print markdown links. No browser. | 154 calls in 45 sessions. Each project built its own method. `github-upload-image-to-pr` needs a browser, so agents used it 4 times only. | Yes, generalize bloodsuckers `scripts/screenshots.mjs` |
| 5 | `watch-origin` | Poll origin and fast-forward. If the lockfile changed, reinstall. Restart the dev loop. | The user asked for it in 3 sessions. It was built twice. | Yes, copy the existing scripts |

Dropped: the 937 `python3 -` heredocs. About 376 of them only rewrite files instead of using Edit. That is a CLAUDE.md line, not a skill.

## Part 2: make the agent-sdlc skills deterministic (this repo)

The cost driver: 162 blind runs for 20 test cases, and the cases went through 78 versions. Each edit voided red, so red and green ran again. A blind run uses a median of 367K input tokens (66.7M total). Most edits fixed app start logic that the agent wrote by hand in each case's Setup.

| # | Script | Skill | What it does |
|---|---|---|---|
| 1 | `serve.sh` | blind-e2e, test-case-format.md | Same as `serve` above. Test-case Setup calls it instead of writing its own start logic. The red/green hash must also cover `docs/test-cases/lib/*`. |
| 2 | `red-tree.sh` | red-green-e2e, green-green-e2e | Make a base-commit checkout inside the agent's own worktree. Copy the case, `lib/`, and `.env*`. Check the sha256. `--rm` removes it. Replaces 147 hand-written `git worktree add` runs. |
| 3 | `record-verdict.sh` | red-green-e2e, green-green-e2e | Read the blind result on stdin. Accept only `VERDICT: PASS|FAIL|BLOCKED`. Check the case hash. Save it verbatim. Tick `state.md`. Count BLOCKED for the three-strikes rule. Exit codes carry the gate result. |
| 4 | `fetch-ticket.sh` | research-ticket | Pick the adapter from the reference shape (`#12`, `AIT-4`, URL, file). Print one JSON ticket. 12 of 17 agents wrote their own version. The aitickets adapter says "NOT IMPLEMENTED". |
| 5 | `sdlc-status.sh` | implement, independent-implement | Print branch, ahead/behind, dirty files, the `state.md` checklist, the last verdict per mode, the hash status, and live pidfiles. Replaces 34 hand-written "Resume:" messages. |
| 6 | `review-packets.sh` | self-review | Find the base, write the diff, and write one packet per review axis. Stops the agent from merging axes (seen in 4 runs). |

Keep with the LLM: writing test-case steps, choosing seams, choosing reviewers, and reading the verdicts.

## Part 3: your project skills (lifeos, bloodsuckers)

| # | Skill | Change | Evidence |
|---|---|---|---|
| 1 | lifeos `populate-daily` | Add `scripts/daily-data.mjs`. It prints one JSON object with date, holidays, tasks due and overdue, weather in words, and trash/recycling from `recycling-schedule.json`. The LLM writes only the briefing. | 31 daily runs. 15 to 40 tool calls each, about 28K output tokens each. 234 single-file Reads. 19 runs had shell loops that the permission layer blocked. Wrong weekday on Aug 24. `recycling: null` on Aug 28 and 29. |
| 2 | lifeos `populate-daily` | Calendar and Gmail tools do not exist in headless `claude -p`. 30 of 31 runs spent about 5 ToolSearch calls looking for them. Tell the skill to skip them, or fetch the Google Calendar private iCal URL in the script. | 163 wasted searches. |
| 3 | lifeos `build-carts` | The LLM writes only new matches to `.cart-matches.json`. The server merges carts and the product map with the existing `rebuildCartUrl` code. | One logged run: $0.56 and 13 turns for one item (carrots). About half was the JSON merge. |
| 4 | bloodsuckers `bug-report`, `feature-request` | Add `scripts/agent-preflight.sh`: start or find the dev server for this worktree, report a stale Playwright profile lock, and print the issue and label lists. | Same setup reads in 16 to 18 sessions. Stale browser lock made the user type "Try again" twice. |
| 5 | bloodsuckers canvas QA | Commit the `shotkit/shoot.mjs` screenshot script that the agent rebuilt in 9 sessions. Add a dev-only `window.__ui` hit map so steps click by name, not by pixel. | 791 `browser_run_code_unsafe` calls, mostly guessed pixel clicks. |
| 6 | lifeos `grocery-purchase-scan` | Get Walmart items from `node scripts/walmart.mjs get-history`, not from emails. Emails show 3 of about 15 items. | `.scan-log`. |
