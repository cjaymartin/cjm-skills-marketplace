#!/usr/bin/env bash
# Keep secrets in one gitignored file per environment that the user fills in, not in chat
# or in long commands.
#
#   secrets.sh [--env ENV] need KEY --how "step" [--how "step"]... [--url URL] [--used-by TEXT]
#   secrets.sh [--env ENV] check KEY...
#   secrets.sh [--env ENV] run -- CMD...
#   secrets.sh [--env ENV] path
#
# ENV is the environment the secrets are for, such as development, staging, or production.
# The default is $LOCAL_SECRETS_ENV, else development.
#
# need   makes sure the secrets file exists and is gitignored. If KEY is not in it, adds
#        "KEY=" under a comment block with the steps to get the value. Never writes a value.
# check  says which keys have a value. It never prints a value.
# run    runs CMD with every filled key from the file in its environment. Values in the
#        file win over the same names already in the environment.
# path   prints the path of the secrets file.
#
# need and check print one line per key, "set KEY" or "missing KEY line=N", then
# "file=PATH". When a key is missing they also print "open=URL", a link that opens the
# file in the editor at the first missing key. $LOCAL_SECRETS_EDITOR picks the editor's
# URL scheme: vscode (the default), cursor, windsurf, or vscode-insiders.
# Exit codes: 0 every key is set, 3 a key is missing, 1 error, 2 bad usage.
#
# The file is .env.ENV at the root of the main checkout, so every worktree and every
# session in one repo shares it. Outside git it is ./.env.ENV. If git already tracks
# .env.ENV (some projects commit defaults there), the file is .env.ENV.local instead.
# need makes sure git ignores the file. If nothing ignores it yet, it adds ".env.*" (and
# "!" rules for .env.example, .env.sample and .env.template) to the .gitignore of the
# checkout you run it in. In a linked worktree it also adds the rule to the repo's
# info/exclude, because the main checkout only sees the .gitignore change after a merge.
# $LOCAL_SECRETS_FILE overrides the path.

set -uo pipefail

die() { echo "secrets: $*" >&2; exit 1; }
usage() { sed -n '2,33p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }

# The root of the main checkout, not of a linked worktree, so all worktrees share one file.
# For a bare repo with worktrees (proj/.bare, proj/w1, proj/w2) it is the bare repo's parent.
root() {
  local common
  common="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || { git rev-parse --show-toplevel 2>/dev/null || pwd; return; }
  if [ "$(basename "$common")" = .git ] || [ "$(git --git-dir="$common" rev-parse --is-bare-repository 2>/dev/null)" = true ]; then
    dirname "$common"
  else
    git rev-parse --show-toplevel 2>/dev/null || pwd
  fi
}

ENVNAME="${LOCAL_SECRETS_ENV:-development}"
if [ "${1:-}" = --env ]; then ENVNAME="${2:-}"; shift 2 || shift; fi
[[ "$ENVNAME" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]] || { echo "secrets: --env must be a name such as production, got '$ENVNAME'" >&2; exit 2; }

tracked() { git -C "$(dirname "$1")" ls-files --error-unmatch -- "$1" >/dev/null 2>&1; }

if [ -n "${LOCAL_SECRETS_FILE:-}" ]; then
  FILE="$LOCAL_SECRETS_FILE"
else
  FILE="$(root)/.env.$ENVNAME"
  tracked "$FILE" && FILE="$FILE.local"
fi
case "$FILE" in /*) ;; *) FILE="$PWD/$FILE" ;; esac
DIR="$(dirname "$FILE")"

valid_key() { [[ "$1" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; }

# The value of KEY in the file, read the way dotenv reads it: a quoted value is the text
# between its quotes; an unquoted value stops at " #". Empty when not there.
file_value() {
  [ -f "$FILE" ] || return 0
  local v
  v="$(sed -n "s/^[[:space:]]*\(export[[:space:]]\{1,\}\)\{0,1\}$1[[:space:]]*=[[:space:]]*//p" "$FILE" | tail -1 | tr -d '\r')"
  case "$v" in
    \"*) v="${v#\"}"; v="${v%%\"*}" ;;
    \'*) v="${v#\'}"; v="${v%%\'*}" ;;
    \#*) v="" ;;
    *) v="${v%%[[:space:]]#*}"; v="${v%"${v##*[![:space:]]}"}" ;;
  esac
  printf '%s' "$v"
}

in_file() { [ -f "$FILE" ] && grep -Eq "^[[:space:]]*(export[[:space:]]+)?$1[[:space:]]*=" "$FILE"; }

# The line number of KEY in the file. Empty when not there.
line_of() { [ -f "$FILE" ] && grep -En "^[[:space:]]*(export[[:space:]]+)?$1[[:space:]]*=" "$FILE" | tail -1 | cut -d: -f1; }

# A link that opens the file at a line, such as vscode://file/home/cj/app/.env.production:12
open_url() {
  local path="${FILE//%/%25}"
  path="${path// /%20}"; path="${path//#/%23}"; path="${path//\?/%3F}"
  printf '%s://file%s:%s\n' "${LOCAL_SECRETS_EDITOR:-vscode}" "$path" "$1"
}

is_set() { [ -n "$(file_value "$1")" ]; }

# Stop if git tracks the file: a value written there would be committed.
# Add a gitignore rule if nothing ignores it yet.
guard_git() {
  git -C "$DIR" rev-parse --git-dir >/dev/null 2>&1 || return 0
  if tracked "$FILE"; then
    die "$FILE is tracked by git. Values in it would be committed. Remove it from git first: git rm --cached $FILE"
  fi
  git -C "$DIR" check-ignore -q -- "$FILE" && return 0

  # The rule: .env.* for the usual names, else the file's own path from the repo root.
  local rule top here gi ex
  top="$(git -C "$DIR" rev-parse --show-toplevel)"
  case "$(basename "$FILE")" in
    .env.*) rule='.env.*' ;;
    *) rule="/${FILE#"$top"/}" ;;
  esac

  # Add it to the .gitignore of the checkout the agent works in, so it gets committed.
  here="$(git rev-parse --show-toplevel 2>/dev/null || echo "$top")"
  gi="$here/.gitignore"
  if ! grep -qxF -- "$rule" "$gi" 2>/dev/null; then
    [ -s "$gi" ] && [ -n "$(tail -c1 "$gi")" ] && echo >> "$gi"
    {
      echo "# Local secrets. Filled in by hand. Never commit."
      echo "$rule"
      [ "$rule" = '.env.*' ] && printf '!.env.example\n!.env.sample\n!.env.template\n'
    } >> "$gi"
    echo "gitignored $rule in $gi. Commit this change." >&2
  fi

  # A linked worktree's .gitignore does not cover the main checkout until it is merged.
  if ! git -C "$DIR" check-ignore -q -- "$FILE"; then
    ex="$(git -C "$DIR" rev-parse --path-format=absolute --git-common-dir)/info/exclude"
    mkdir -p "$(dirname "$ex")" && printf '%s\n' "$rule" >> "$ex"
    echo "also excluded $rule in $ex" >&2
  fi
  git -C "$DIR" check-ignore -q -- "$FILE" || die "git still does not ignore $FILE. Nothing was written to it."
}

create_file() {
  [ -f "$FILE" ] && return 0
  mkdir -p "$DIR" || die "cannot make $DIR"
  ( umask 077 && {
    echo "# Secrets for the $ENVNAME environment of this project."
    echo "# This file is gitignored. Never commit it."
    [ "$ENVNAME" = production ] && echo "# These are LIVE production values. Use the production account for each one."
    cat <<'HEAD'
#
# Agents add a key here when they need one. Each key has the steps to get its value.
# Paste each value after its = sign. No quotes are needed. Save the file.
# Agents check that a key has a value. They do not read or print the values.
HEAD
  } > "$FILE" ) || die "cannot write $FILE"
}

cmd_need() {
  local key="${1:-}"; shift || true
  valid_key "$key" || { echo "secrets: need KEY must be a variable name, got '$key'" >&2; exit 2; }
  local url="" used="" how=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --how) how+=("${2:?--how needs text}"); shift 2 ;;
      --url) url="${2:?--url needs a URL}"; shift 2 ;;
      --used-by) used="${2:?--used-by needs text}"; shift 2 ;;
      *) echo "secrets: unknown option $1" >&2; exit 2 ;;
    esac
  done
  [ ${#how[@]} -gt 0 ] || { echo "secrets: need $key needs at least one --how step" >&2; exit 2; }

  mkdir -p "$DIR" || die "cannot make $DIR"
  guard_git
  create_file
  if ! in_file "$key"; then
    {
      [ -n "$(tail -c1 "$FILE")" ] && echo
      echo
      echo "# ---- $key ----"
      [ -n "$used" ] && echo "# Used by: $used"
      echo "# How to get it:"
      local i=1 step
      for step in "${how[@]}"; do echo "#   $i. $step"; i=$((i + 1)); done
      [ -n "$url" ] && echo "# Link: $url"
      echo "$key="
    } >> "$FILE" || die "cannot write $FILE"
  fi
  cmd_check "$key"
}

cmd_check() {
  [ $# -gt 0 ] || usage
  local k n first=""
  for k in "$@"; do
    valid_key "$k" || { echo "secrets: '$k' is not a variable name" >&2; exit 2; }
    if is_set "$k"; then echo "set $k"; continue; fi
    n="$(line_of "$k")"
    if [ -n "$n" ]; then echo "missing $k line=$n"; else echo "missing $k"; fi
    [ -z "$first" ] && first="${n:-1}"
  done
  echo "env=$ENVNAME"
  echo "file=$FILE"
  [ -z "$first" ] && return 0
  echo "open=$(open_url "$first")"
  exit 3
}

cmd_run() {
  [ "${1:-}" = -- ] && shift
  [ $# -gt 0 ] || usage
  if [ -f "$FILE" ]; then
    local line k v
    while IFS= read -r line || [ -n "$line" ]; do
      [[ "$line" =~ ^[[:space:]]*(export[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*= ]] || continue
      k="${BASH_REMATCH[2]}"
      v="$(file_value "$k")"
      [ -n "$v" ] && export "$k=$v"
    done < "$FILE"
  fi
  exec "$@"
}

case "${1:-}" in
  need) shift; cmd_need "$@" ;;
  check) shift; cmd_check "$@" ;;
  run) shift; cmd_run "$@" ;;
  path) echo "$FILE" ;;
  *) usage ;;
esac
