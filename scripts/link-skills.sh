#!/usr/bin/env bash
# Install this repo's skills into ~/.claude/skills so they work in every project
# on this machine.
#
#   scripts/link-skills.sh              link every skill
#   scripts/link-skills.sh blind-e2e    link one skill
#   scripts/link-skills.sh --copy       copy instead of symlink
#
# Copy mode exists because symlinked skills have had listing and validation bugs
# reported against Claude Code. If a linked skill runs but never appears in the
# skill list, rerun with --copy and rerun it after every edit.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="$REPO_ROOT/skills"
DEST_DIR="$HOME/.claude/skills"

MODE=link
ONLY=""
for arg in "$@"; do
  case "$arg" in
    --copy) MODE=copy ;;
    --link) MODE=link ;;
    -*) echo "unknown option: $arg" >&2; exit 2 ;;
    *) ONLY="$arg" ;;
  esac
done

mkdir -p "$DEST_DIR"

if [ ! -d "$SRC_DIR" ]; then
  echo "no skills/ directory yet — nothing to install"
  exit 0
fi

shopt -s nullglob
candidates=("$SRC_DIR"/*/)
shopt -u nullglob

if [ ${#candidates[@]} -eq 0 ]; then
  echo "skills/ holds no skills yet — nothing to install"
  exit 0
fi

failed=0

for path in "${candidates[@]}"; do
  name="$(basename "$path")"
  [ -n "$ONLY" ] && [ "$ONLY" != "$name" ] && continue

  src="$SRC_DIR/$name"
  dest="$DEST_DIR/$name"
  skill_md="$src/SKILL.md"

  if [ ! -f "$skill_md" ]; then
    printf '%-20s %-6s FAILED  no SKILL.md in %s\n' "$name" "$MODE" "$src"
    failed=1
    continue
  fi

  # The slash command comes from the directory name for a personal skill and
  # from the name field for a plugin skill. They must agree or the same repo
  # behaves differently depending on how it was installed.
  declared="$(sed -n 's/^name:[[:space:]]*//p' "$skill_md" | head -1 | tr -d '\r')"
  if [ "$declared" != "$name" ]; then
    printf '%-20s %-6s FAILED  name: is "%s" but the directory is "%s"\n' \
      "$name" "$MODE" "$declared" "$name"
    failed=1
    continue
  fi

  # Never clobber a real directory somebody else put there.
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    if [ "$MODE" = copy ] && [ -f "$dest/.installed-by-skillz" ]; then
      rm -rf "$dest"
    else
      printf '%-20s %-6s REFUSED %s exists and is not a link this script made\n' \
        "$name" "$MODE" "$dest"
      failed=1
      continue
    fi
  fi

  rm -rf "$dest"
  if [ "$MODE" = link ]; then
    ln -sfn "$src" "$dest"
  else
    cp -R "$src" "$dest"
    touch "$dest/.installed-by-skillz"
  fi

  if [ ! -r "$dest/SKILL.md" ]; then
    printf '%-20s %-6s FAILED  SKILL.md is not readable at %s\n' "$name" "$MODE" "$dest"
    failed=1
    continue
  fi

  printf '%-20s %-6s OK\n' "$name" "$MODE"
done

if [ "$failed" -ne 0 ]; then
  echo
  echo "one or more skills failed to install"
  exit 1
fi
