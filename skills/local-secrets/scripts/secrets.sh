#!/usr/bin/env bash
# Keep secrets in one gitignored file that the user fills in, not in chat or in long commands.
#
#   secrets.sh need KEY --how "step" [--how "step"]... [--url URL] [--used-by TEXT]
#   secrets.sh check KEY...
#   secrets.sh run -- CMD...
#   secrets.sh path
#
# need   makes sure the secrets file exists and is gitignored. If KEY is not in it, adds
#        "KEY=" under a comment block with the steps to get the value. Never writes a value.
# check  says which keys have a value. It never prints a value.
# run    runs CMD with every filled key from the file in its environment. Values in the
#        file win over the same names already in the environment.
# path   prints the path of the secrets file.
#
# need and check print one line per key, "set KEY" or "missing KEY", then "file=PATH".
# Exit codes: 0 every key is set, 3 a key is missing, 1 error, 2 bad usage.
#
# The file is .env.local at the root of the main checkout, so every worktree and every
# session in one repo shares it. Outside git it is ./.env.local. $LOCAL_SECRETS_FILE
# overrides the path.

set -uo pipefail

die() { echo "secrets: $*" >&2; exit 1; }
usage() { sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }

# The root of the main checkout, not of a linked worktree, so all worktrees share one file.
root() {
  local common
  common="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || { git rev-parse --show-toplevel 2>/dev/null || pwd; return; }
  if [ "$(basename "$common")" = .git ]; then
    dirname "$common"
  else
    git rev-parse --show-toplevel 2>/dev/null || pwd
  fi
}

FILE="${LOCAL_SECRETS_FILE:-$(root)/.env.local}"
case "$FILE" in /*) ;; *) FILE="$PWD/$FILE" ;; esac
DIR="$(dirname "$FILE")"

valid_key() { [[ "$1" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; }

# The value of KEY in the file, with surrounding quotes removed. Empty when not there.
file_value() {
  [ -f "$FILE" ] || return 0
  sed -n "s/^[[:space:]]*\(export[[:space:]]\{1,\}\)\{0,1\}$1[[:space:]]*=[[:space:]]*//p" "$FILE" \
    | tail -1 | sed -e 's/[[:space:]]*$//' -e 's/^"\(.*\)"$/\1/' -e "s/^'\(.*\)'$/\1/"
}

in_file() { [ -f "$FILE" ] && grep -Eq "^[[:space:]]*(export[[:space:]]+)?$1[[:space:]]*=" "$FILE"; }

is_set() { [ -n "$(file_value "$1")" ] || [ -n "${!1:-}" ]; }

# Stop if git tracks the file: a value written there would be committed.
# Add a gitignore rule if nothing ignores it yet.
guard_git() {
  git -C "$DIR" rev-parse --git-dir >/dev/null 2>&1 || return 0
  if git -C "$DIR" ls-files --error-unmatch -- "$FILE" >/dev/null 2>&1; then
    die "$FILE is tracked by git. Values in it would be committed. Remove it from git first: git rm --cached $FILE"
  fi
  git -C "$DIR" check-ignore -q -- "$FILE" && return 0
  local top gi
  top="$(git -C "$DIR" rev-parse --show-toplevel)"
  gi="$top/.gitignore"
  [ -s "$gi" ] && [ -n "$(tail -c1 "$gi")" ] && echo >> "$gi"
  printf '# Local secrets. Filled in by hand. Never commit.\n.env*.local\n' >> "$gi"
  git -C "$DIR" check-ignore -q -- "$FILE" || die "added .env*.local to $gi but git still does not ignore $FILE"
  echo "gitignored .env*.local in $gi" >&2
}

create_file() {
  [ -f "$FILE" ] && return 0
  mkdir -p "$DIR" || die "cannot make $DIR"
  ( umask 077 && cat > "$FILE" <<'HEAD'
# Local secrets for this project. This file is gitignored. Never commit it.
#
# Agents add a key here when they need one. Each key has the steps to get its value.
# Paste each value after its = sign. No quotes are needed. Save the file.
# Agents check that a key has a value. They do not read or print the values.
HEAD
  ) || die "cannot write $FILE"
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
  local k missing=0
  for k in "$@"; do
    valid_key "$k" || { echo "secrets: '$k' is not a variable name" >&2; exit 2; }
    if is_set "$k"; then echo "set $k"; else echo "missing $k"; missing=1; fi
  done
  echo "file=$FILE"
  [ $missing = 0 ] || exit 3
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
