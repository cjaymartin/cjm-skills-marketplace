#!/usr/bin/env bash
# One answer to "can this PR merge, and if CI is red, why?"
#
#   pr-status.sh [PR] [--wait] [--repo OWNER/REPO]
#
# PR is a number, URL, or branch. Without it, the PR for the current branch.
# --wait blocks until every check finishes, then reports.
# Prints the merge state, one line per check, and the failing log lines of each failed
# GitHub Actions run. Exit 0 when checks passed and the PR is ready to merge, 1 otherwise.

set -uo pipefail
command -v jq >/dev/null || { echo "pr-status: needs jq (https://jqlang.org)" >&2; exit 2; }

pr="" wait=0 repo=()
while [ $# -gt 0 ]; do
  case "$1" in
    --wait) wait=1; shift ;;
    --repo) repo=(--repo "$2"); shift 2 ;;
    -h|--help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) pr="$1"; shift ;;
  esac
done

if [ $wait = 1 ]; then
  # A PR whose checks have not registered yet reports "no checks"; give them a moment.
  sleep 5
  gh pr checks $pr ${repo[@]+"${repo[@]}"} --watch --interval 15 >/dev/null 2>&1
fi

fields=number,title,state,isDraft,mergeable,mergeStateStatus,reviewDecision,baseRefName,headRefName,url,statusCheckRollup
# GitHub computes mergeability lazily and answers UNKNOWN right after a push.
for _ in 1 2 3 4 5; do
  json="$(gh pr view $pr ${repo[@]+"${repo[@]}"} --json "$fields")" || exit 1
  [ "$(jq -r '.mergeable != "UNKNOWN" or .state != "OPEN"' <<<"$json")" = true ] && break
  sleep 3
done

jq -r '
  "#\(.number) \(.title)",
  "state=\(.state)\(if .isDraft then " draft" else "" end) mergeable=\(.mergeable) merge_state=\(.mergeStateStatus) review=\(.reviewDecision | if . == null or . == "" then "NONE" else . end) \(.headRefName) -> \(.baseRefName)",
  .url,
  "--- checks",
  (if (.statusCheckRollup | length) == 0 then "none" else
    (.statusCheckRollup[] |
      if .__typename == "StatusContext"
      then "\(.state | ascii_downcase)\t\(.context)"
      else "\((.conclusion // "") | if . == "" then "pending" else ascii_downcase end)\t\(.name)\(if .workflowName then " (\(.workflowName))" else "" end)"
      end)
  end)' <<<"$json"

failed_runs="$(jq -r '.statusCheckRollup[]? | select(.__typename != "StatusContext")
  | select(.conclusion == "FAILURE" or .conclusion == "TIMED_OUT" or .conclusion == "STARTUP_FAILURE")
  | (.detailsUrl // "" | capture("/actions/runs/(?<id>[0-9]+)") | .id)?' <<<"$json" | sort -u)"

for run in $failed_runs; do
  echo "--- failed run $run (full log: gh run view $run --log-failed)"
  gh run view "$run" ${repo[@]+"${repo[@]}"} --json jobs \
    --jq '.jobs[] | select(.conclusion == "failure") | "job: \(.name)", (.steps[] | select(.conclusion == "failure") | "  step: \(.name)")'
  lines="$(gh run view "$run" ${repo[@]+"${repo[@]}"} --log-failed 2>/dev/null | perl -pe 's/\e\[[0-9;]*m//g' \
    | grep -E -i 'error|fail|✗|×|expected|assert' | grep -v -E 'continue-on-error|fail-fast' | head -n 40)"
  echo "${lines:-(GitHub returned no log lines for this run)}"
done

ok="$(jq -r '
  ([.statusCheckRollup[]? | (.conclusion // .state // "") | ascii_upcase]
    | all(. == "SUCCESS" or . == "SKIPPED" or . == "NEUTRAL"))
  and .mergeable == "MERGEABLE" and (.isDraft | not)
  and (.mergeStateStatus == "CLEAN" or .mergeStateStatus == "HAS_HOOKS" or .mergeStateStatus == "UNSTABLE")' <<<"$json")"
[ "$ok" = true ]
