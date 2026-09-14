#!/usr/bin/env bash
# Bump the plugin version and push. Do this for EVERY change you want installed
# users to receive.
#
#   scripts/release.sh 0.3.0
#
# `claude plugin update` compares versions, not commits. If the version in
# .claude-plugin/plugin.json has not changed, the update reports "already at the
# latest version" and pulls nothing — your change never reaches anyone.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$REPO_ROOT/.claude-plugin/plugin.json"

if [ $# -ne 1 ]; then
  echo "usage: scripts/release.sh <version>   e.g. scripts/release.sh 0.3.0" >&2
  exit 2
fi

NEW="$1"
if ! printf '%s' "$NEW" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  echo "version must look like 1.2.3, got: $NEW" >&2
  exit 2
fi

OLD="$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['version'])" "$MANIFEST")"
if [ "$OLD" = "$NEW" ]; then
  echo "version is already $NEW — pick a higher one" >&2
  exit 2
fi

python3 - "$MANIFEST" "$NEW" <<'PY'
import json, sys
path, new = sys.argv[1], sys.argv[2]
with open(path) as f:
    d = json.load(f)
d["version"] = new
with open(path, "w") as f:
    json.dump(d, f, indent=2)
    f.write("\n")
PY

cd "$REPO_ROOT"
git add .claude-plugin/plugin.json
git commit -m "Release $NEW"
git push

echo
echo "released $OLD -> $NEW"
echo "installed users now get it with:"
echo "  claude plugin marketplace update skillz && claude plugin update agent-sdlc@skillz"
