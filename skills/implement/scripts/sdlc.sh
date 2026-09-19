#!/usr/bin/env bash
# The fixed steps of the agent-sdlc chain, so no skill does them by hand.
#
#   sdlc.sh base                          the ref this branch will merge into
#   sdlc.sh hash CASE                     sha256 of a test case plus docs/test-cases/lib/*
#   sdlc.sh verdict TICKET MODE CASE      save a blind verdict (read from stdin) and apply the gate
#   sdlc.sh tree CASE [BASE]              a checkout of BASE with the case in it, for a red run
#   sdlc.sh tree --rm PATH                remove that checkout
#   sdlc.sh status TICKET                 everything needed to resume a ticket
#   sdlc.sh review TICKET [BASE]          one self-review packet per axis
#
# MODE is red, green, before, or after. verdict exit codes:
#   0 gate met   1 gate not met   2 BLOCKED   3 malformed verdict   4 case changed since red/before

set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
die() { echo "sdlc: $*" >&2; exit "${2:-1}"; }
top="$(git rev-parse --show-toplevel 2>/dev/null)" || die "not inside a git repository"
# Called from inside a red tree, work in the checkout that owns it, so .sdlc/ stays there.
case "$top" in */.sdlc/trees/*) top="${top%%/.sdlc/trees/*}" ;; esac
orig="$PWD"
cd "$top" || exit 1
# An absolute, symlink-free path. Portable: macOS realpath has no -m.
physical() {
  local d
  d="$(cd "$(dirname "$1")" 2>/dev/null && pwd -P)" && printf '%s/%s\n' "$d" "$(basename "$1")" || printf '%s\n' "$1"
}
# Case paths may be given relative to where the caller stood.
abs() { case "$1" in /*) physical "$1" ;; *) physical "$orig/$1" ;; esac; }

sha() { if command -v sha256sum >/dev/null; then sha256sum "$@"; else shasum -a 256 "$@"; fi; }
now() { date -u +%Y%m%d-%H%M%S; }

cmd_base() {
  local b
  if command -v gh >/dev/null && b="$(gh pr view --json baseRefName --jq .baseRefName 2>/dev/null)" && [ -n "$b" ]; then
    echo "origin/$b"; return
  fi
  if b="$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)"; then echo "$b"; return; fi
  for b in origin/main origin/master origin/develop main master; do
    git rev-parse --verify --quiet "$b" >/dev/null && { echo "$b"; return; }
  done
  die "cannot find a base branch. Pass one explicitly."
}

# The hash covers the case and the shared scripts it calls, because both are the question.
case_hash() {
  local c="$1" root lib
  [ -f "$c" ] || die "no test case at $c"
  root="$(git -C "$(dirname "$c")" rev-parse --show-toplevel)"
  lib="$root/docs/test-cases/lib"
  { sha "$c" | cut -d' ' -f1
    [ -d "$lib" ] && (cd "$lib" && find . -type f | LC_ALL=C sort | while read -r f; do sha "$f"; done)
  } | sha | cut -d' ' -f1
}

# A case's path inside its own checkout, so a tree copy and the original share one key.
rel() { local r; r="$(git -C "$(dirname "$1")" rev-parse --show-toplevel)"; echo "${1#"$r"/}"; }

cmd_verdict() {
  local t="$1" mode="$2" c; c="$(abs "$3")"; local raw v tc h key slug ts run want log hashes state n
  case "$mode" in red) want=FAIL ;; green|before|after) want=PASS ;; *) die "MODE must be red, green, before or after" ;; esac
  [ -f "$c" ] || die "no test case at $c"
  raw="$(cat)"
  key="$(rel "$c")"
  slug="$(basename "$c" .md)"
  ts="$(now)"
  mkdir -p ".sdlc/$t" ".sdlc/runs/$t"
  run=".sdlc/runs/$t/$mode-$slug-$ts.md"
  printf '%s\n' "$raw" > "$run"

  v="$(printf '%s\n' "$raw" | sed -n -E 's/^[[:space:]]*VERDICT:[[:space:]]*(PASS|FAIL|BLOCKED)[[:space:]]*$/\1/p')"
  tc="$(printf '%s\n' "$raw" | sed -n -E 's/^[[:space:]]*TEST CASE:[[:space:]]*(.*[^[:space:]])[[:space:]]*$/\1/p' | head -n 1)"
  if [ "$(printf '%s' "$v" | grep -c .)" != 1 ]; then
    mv "$run" "${run%.md}-malformed.md"
    die "MALFORMED: need exactly one line 'VERDICT: PASS|FAIL|BLOCKED'. Saved as ${run%.md}-malformed.md. Run the blind case again; do not rewrite its output." 3
  fi
  if [ -z "$tc" ] || [ "$(physical "$tc")" != "$c" ]; then
    mv "$run" "${run%.md}-malformed.md"
    die "MALFORMED: the TEST CASE line ('$tc') is not $c. The blind agent ran something else." 3
  fi

  h="$(case_hash "$c")"
  hashes=".sdlc/$t/hashes"
  touch "$hashes"
  if [ "$mode" = red ] || [ "$mode" = before ]; then
    # Each red or before run replaces the proof for this case. Only a run that met its
    # gate records a hash, so green and after need a red FAIL or a before PASS first.
    { grep -v -F "$key " "$hashes"; [ "$v" = "$want" ] && echo "$key $h"; } > "$hashes.tmp"; mv "$hashes.tmp" "$hashes"
  else
    local was; was="$(grep -F "$key " "$hashes" | tail -n 1 | cut -d' ' -f2)"
    if [ -z "$was" ]; then
      echo "$ts $mode $v $key $h $run VOID" >> ".sdlc/$t/verdicts.log"
      die "VOID: no passed red (or before) gate is recorded for $key. Run red (or before) first." 4
    elif [ "$was" != "$h" ]; then
      echo "$ts $mode $v $key $h $run VOID" >> ".sdlc/$t/verdicts.log"
      die "VOID: $key or docs/test-cases/lib changed since the red/before run ($was -> $h). The proof is void. Start again with a fresh red/before run." 4
    fi
  fi

  log=".sdlc/$t/verdicts.log"
  echo "$ts $mode $v $key $h $run" >> "$log"

  state=".sdlc/$t/state.md"
  if [ -f "$state" ] && [ "$v" != BLOCKED ] && grep -q -E "^- \[[ x]\] $mode( |$)" "$state"; then
    local box=" "; [ "$v" = "$want" ] && box=x
    sed -i.bak -E "s|^- \[[ x]\] $mode( .*)?$|- [$box] $mode — $run — $v|" "$state" && rm -f "$state.bak"
  fi

  echo "verdict=$v mode=$mode case=$key hash=${h:0:12} saved=$run"
  if [ "$v" = BLOCKED ]; then
    n="$(grep -c -E " $mode BLOCKED $key " "$log")"
    echo "BLOCKED $n of 3 on this case. Read the REASON line, repair Setup, run again."
    [ "$n" -ge 3 ] && echo "STOP: three BLOCKED verdicts on this case. Take it to the human."
    exit 2
  fi
  if [ "$v" = "$want" ]; then echo "GATE MET: $mode needs $want."; exit 0; fi
  echo "GATE NOT MET: $mode needs $want, got $v."
  if [ "$mode" = green ]; then
    n="$(grep -c -E " green FAIL $key " "$log")"
    echo "green FAIL $n of 3."
    [ "$n" -ge 3 ] && echo "STOP: three failed green runs. Take it to the human."
  fi
  exit 1
}

cmd_tree() {
  if [ "${1:-}" = --rm ]; then
    [ -n "${2:-}" ] || die "tree --rm needs a path"
    local p; p="$(git -C "$(abs "$2")" rev-parse --show-toplevel 2>/dev/null)" || die "$2 is not a checkout"
    # Only trees this script made. Any other worktree may hold someone's work.
    case "$p" in "$top"/.sdlc/trees/*) ;; *) die "refusing: $p is not under $top/.sdlc/trees/" ;; esac
    git worktree remove --force "$p" && echo "removed $p"
    return
  fi
  local c; c="$(abs "$1")"; local base="${2:-}" key sha7 dest f
  [ -f "$c" ] || die "no test case at $c"
  [ -n "$base" ] || base="$(cmd_base)"
  git fetch --quiet origin 2>/dev/null
  sha7="$(git rev-parse --short "$base")" || die "unknown base $base"
  key="$(rel "$c")"
  # Inside this checkout, so the agent's shell may cd there. .sdlc/ must be ignored.
  git check-ignore -q .sdlc/ || { echo ".sdlc/" >> "$(git rev-parse --git-path info/exclude)"; echo "note: added .sdlc/ to .git/info/exclude"; }
  dest=".sdlc/trees/$(basename "$c" .md)-$sha7"
  [ -e "$dest" ] && die "$dest already exists. Remove it first: sdlc.sh tree --rm $dest"
  git worktree add --quiet --detach "$dest" "$base" || die "git worktree add failed"
  mkdir -p "$dest/$(dirname "$key")"
  cp "$c" "$dest/$key"
  [ -d docs/test-cases/lib ] && mkdir -p "$dest/docs/test-cases" && cp -R docs/test-cases/lib "$dest/docs/test-cases/"
  # Local env files are ignored by git, so a fresh checkout lacks them.
  git ls-files --others --ignored --exclude-standard -- ':(glob)**/.env*' | grep -v -E '(^|/)node_modules/|^\.sdlc/' | while read -r f; do
    mkdir -p "$dest/$(dirname "$f")"; cp "$f" "$dest/$f"
  done
  [ "$(case_hash "$c")" = "$(case_hash "$dest/$key")" ] || die "hash mismatch after copy"
  echo "tree=$top/$dest base=$base@$sha7"
  echo "case=$top/$dest/$key"
}

cmd_status() {
  local t="$1" base ab
  echo "branch=$(git branch --show-current) head=$(git rev-parse --short HEAD)"
  if base="$(cmd_base 2>/dev/null)"; then
    ab="$(git rev-list --left-right --count "HEAD...$base" 2>/dev/null)"
    echo "base=$base ahead=${ab%%[[:space:]]*} behind=${ab##*[[:space:]]}"
  fi
  local unpushed; unpushed="$(git rev-list --count '@{u}..HEAD' 2>/dev/null)" && echo "unpushed=$unpushed" || echo "upstream=none"
  echo "--- uncommitted"
  git status --short | head -n 20
  echo "--- .sdlc/$t/state.md"
  cat ".sdlc/$t/state.md" 2>/dev/null || echo "(none: fresh start)"
  if [ -f ".sdlc/$t/verdicts.log" ]; then
    echo "--- last verdict per mode and case"
    awk '{last[$2" "$4]=$0} END {for (k in last) print last[k]}' ".sdlc/$t/verdicts.log" | sort
  fi
  if [ -f ".sdlc/$t/hashes" ]; then
    echo "--- case hash since red/before"
    local k h
    while read -r k h; do
      if [ ! -f "$k" ]; then echo "missing $k"
      elif [ "$(case_hash "$k")" = "$h" ]; then echo "same $k"
      else echo "CHANGED $k (the proof is void)"; fi
    done < ".sdlc/$t/hashes"
  fi
  [ -f ".sdlc/$t/assumptions.md" ] && echo "assumptions=$(grep -c '^## A' ".sdlc/$t/assumptions.md")"
  if [ -d .sdlc/trees ] && [ -n "$(ls -A .sdlc/trees)" ]; then echo "--- trees"; ls -d .sdlc/trees/*; fi
  [ -x "$here/../../serve/scripts/serve.sh" ] && { echo "--- servers"; "$here/../../serve/scripts/serve.sh" ls; }
  command -v gh >/dev/null && gh pr view --json url,state,isDraft --jq '"pr=\(.url) state=\(.state)\(if .isDraft then " draft" else "" end)"' 2>/dev/null
  true
}

cmd_review() {
  local t="$1" base="${2:-}" out checklist diff name slug
  [ -n "$base" ] || base="$(cmd_base)"
  checklist="$here/../../self-review/review-checklist.md"
  [ -f "$checklist" ] || die "cannot find $checklist"
  out=".sdlc/$t/review"
  rm -rf "$out"; mkdir -p "$out"
  diff="$out/diff.patch"
  # Everything since the branch left the base: commits, uncommitted edits, new files.
  # The brief goes to reviewers by path, so its own diff is left out.
  local mb f; mb="$(git merge-base "$base" HEAD)" || die "no merge base with $base"
  git diff "$mb" -- . ':(exclude)docs/research' ':(exclude).sdlc' > "$diff"
  git ls-files --others --exclude-standard -- . ':(exclude)docs/research' | while read -r f; do
    git diff --no-index -- /dev/null "$f"
  done >> "$diff"
  [ -s "$diff" ] || die "no change since $base"
  echo "base=$base diff=$diff"
  git diff --stat "$mb" -- . ':(exclude)docs/research' | tail -n 1
  for name in "Correctness and edge cases" "Error handling" "Tests" "Security and performance" "Style and accuracy"; do
    slug="$(echo "$name" | tr 'A-Z ' 'a-z-')"
    { echo "# Review packet: $name"
      echo
      echo "Review only this axis. Report each finding with file, line, and a concrete failure: the input, and what goes wrong."
      echo "The change was meant to do what docs/research/$t.md says."
      echo
      awk -v h="## $name" '$0==h {on=1; next} on && /^## / {exit} on && !/^---$/ {print}' "$checklist"
      echo
      echo "## The diff (since $base, uncommitted work included)"
      echo
      echo '```diff'
      cat "$diff"
      echo '```'
    } > "$out/$slug.md"
    echo "packet=$out/$slug.md"
  done
}

case "${1:-}" in
  base) cmd_base ;;
  hash) [ -n "${2:-}" ] || die "hash needs a case path"; case_hash "$(abs "$2")" ;;
  verdict) [ $# -eq 4 ] || die "usage: sdlc.sh verdict TICKET MODE CASE < verdict.txt"; cmd_verdict "$2" "$3" "$4" ;;
  tree) shift; [ $# -ge 1 ] || die "usage: sdlc.sh tree CASE [BASE]"; cmd_tree "$@" ;;
  status) [ -n "${2:-}" ] || die "status needs a ticket id"; cmd_status "$2" ;;
  review) [ -n "${2:-}" ] || die "review needs a ticket id"; cmd_review "$2" "${3:-}" ;;
  *) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
