#!/usr/bin/env bash
# Read a ticket into one fixed shape: id, title, state, labels, url, body, discussion.
#
#   fetch-ticket.sh REF
#
# REF shapes:
#   #123, 123, owner/repo#123, https://github.com/owner/repo/issues/123   GitHub issue (needs gh)
#   path/to/ticket.md                                                     markdown file
# Anything else exits 3: it is plain text, so ask the human for the id and the title.

set -uo pipefail

ref="${1:-}"
[ -n "$ref" ] || { sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }

repo=() num="" slug=""
if [[ "$ref" =~ ^#?([0-9]+)$ ]]; then
  num="${BASH_REMATCH[1]}"
elif [[ "$ref" =~ ^([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)#([0-9]+)$ ]]; then
  slug="${BASH_REMATCH[1]}"; num="${BASH_REMATCH[2]}"
elif [[ "$ref" =~ ^https?://github\.com/([^/]+/[^/]+)/issues/([0-9]+) ]]; then
  slug="${BASH_REMATCH[1]}"; num="${BASH_REMATCH[2]}"
fi
[ -n "$slug" ] && repo=(--repo "$slug")

if [ -n "$num" ]; then
  command -v gh >/dev/null || { echo "fetch-ticket: gh is not installed. Ask the human to paste the issue." >&2; exit 1; }
  gh issue view "$num" ${repo[@]+"${repo[@]}"} \
    --json number,title,state,labels,url,body,comments \
    --jq '"id: gh-\(.number)",
      "title: \(.title)",
      "state: \(.state)",
      "labels: \([.labels[].name] | join(", ") | if . == "" then "none" else . end)",
      "url: \(.url)",
      "",
      "## Body",
      "",
      (.body // "" | if . == "" then "(empty)" else . end),
      "",
      "## Discussion (\(.comments | length) comments, oldest first)",
      (.comments | sort_by(.createdAt)[] | "", "### \(.author.login) at \(.createdAt)", "", .body)' \
    || { echo "fetch-ticket: gh failed. Report the error above and ask the human to paste the issue." >&2; exit 1; }
  # Pull requests that mention the issue: one may already be doing this work.
  here_repo='{owner}/{repo}'
  prs="$(gh api "repos/${slug:-$here_repo}/issues/$num/timeline" --paginate \
    --jq '.[] | select(.event == "cross-referenced" and .source.issue.pull_request) | .source.issue | "#\(.number) \(.state) \(.title)"' 2>/dev/null | sort -u)"
  echo
  echo "## Pull requests that mention it"
  echo
  echo "${prs:-none}"
  exit 0
fi

if [[ "$ref" == *.md ]]; then
  [ -f "$ref" ] || { echo "fetch-ticket: no file at $ref. Do not guess a similar name." >&2; exit 1; }
  title="$(sed -n 's/^# \(.*\)/\1/p' "$ref" | head -n 1)"
  echo "id: $(basename "$ref" .md)"
  echo "title: ${title:-$(basename "$ref" .md)}"
  echo "state: n/a"
  echo "labels: none"
  echo "url: $ref"
  echo
  echo "## Body"
  echo
  cat "$ref"
  exit 0
fi

echo "fetch-ticket: '$ref' is not a GitHub issue or a .md file. Treat it as plain text." >&2
exit 3
