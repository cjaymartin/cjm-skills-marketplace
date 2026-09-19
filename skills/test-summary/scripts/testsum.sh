#!/usr/bin/env bash
# Run a test command once, keep the whole log, and print only what matters.
#
#   testsum.sh [--lines N] -- CMD...
#
# Prints the exit code, the runner's summary lines, and each failure with context,
# capped at N lines (default 120). The full log is saved, and its path is printed,
# so a failure that got cut off is read from the log instead of running the tests again.
# Exits with the command's own exit code.

set -uo pipefail

max=120
while [ $# -gt 0 ]; do
  case "$1" in
    --lines) max="$2"; shift 2 ;;
    --) shift; break ;;
    *) break ;;
  esac
done
[ $# -gt 0 ] || { sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }

log="$(mktemp "${TMPDIR:-/tmp}/testsum.XXXXXX")"
start=$SECONDS
"$@" >"$log" 2>&1
rc=$?
# Colors and cursor codes make grep miss lines and waste tokens.
perl -pi -e 's/\e\[[0-9;?]*[A-Za-z]//g; s/\r$//' "$log"

# Summary lines from vitest, jest, node --test, mocha, pytest, go test, cargo, tsc.
summary='^ *(Test Files|Tests|Test Suites|Snapshots|Duration|Time)(:| {2})|^(# |ℹ )(tests|suites|pass|fail|cancelled|skipped|todo) [0-9]|^ *[0-9]+ (passing|failing|pending)|^=+ .*(passed|failed|error).* =+$|^(ok|FAIL|PASS)[[:space:]]|^test result:|^Found [0-9]+ errors?'
# Lines that start a failure report.
failure='(FAIL|✗|×|✖|not ok |AssertionError|Error:|error TS[0-9]+|--- FAIL|panicked at|Traceback|^E  |^ *[0-9]+\) )'

echo "exit=$rc time=$((SECONDS - start))s log=$log lines=$(wc -l <"$log" | tr -d ' ')"
echo "--- summary"
grep -E "$summary" "$log" | tail -n 12
if [ "$rc" -ne 0 ]; then
  echo "--- failures (first $max lines; the rest is in the log)"
  hits="$(grep -nE "$failure" "$log" | head -n 1)"
  if [ -n "$hits" ]; then
    grep -E -A 12 "$failure" "$log" | head -n "$max"
  else
    tail -n 40 "$log"
  fi
fi
exit "$rc"
