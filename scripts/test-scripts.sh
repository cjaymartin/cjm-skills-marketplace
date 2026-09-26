#!/usr/bin/env bash
# Smoke test for every script the skills call. Runs in throwaway repos under a temp dir.
#
#   scripts/test-scripts.sh
#
# pr-status.sh is not covered: it needs a real GitHub pull request.

set -uo pipefail
S="$(cd "$(dirname "${BASH_SOURCE[0]}")/../skills" && pwd -P)"
T="$(mktemp -d)"
export SERVE_STATE="$T/serve-state"
fails=0
ok() { echo "ok   $1"; }
no() { echo "FAIL $1"; fails=$((fails + 1)); }
check() { local name="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$name"; else no "$name"; fi; }
code() { local want="$1" name="$2"; shift 2; "$@" >"$T/out" 2>&1; local rc=$?; [ "$rc" = "$want" ] && ok "$name" || { no "$name (exit $rc, wanted $want)"; sed 's/^/     /' "$T/out"; }; }
trap 'rm -rf "$T"' EXIT

# A remote and a checkout, with a base branch and a feature branch.
git init -q --bare "$T/remote.git"
git clone -q "$T/remote.git" "$T/repo" 2>/dev/null
cd "$T/repo" || exit 1
git config user.email t@t; git config user.name t
mkdir -p docs/test-cases && printf '# A case\n\n## Setup\nx\n\n## Steps\n1. y\n\n## Expected\nz\n' > docs/test-cases/T-1-a.md
echo "SECRET=1" > .env.local && echo ".env.local" > .gitignore && echo "one" > app.txt
git add -A && git commit -qm base && git branch -M main && git push -q -u origin main 2>/dev/null
git remote set-head origin main
git checkout -q -b feature && echo "two" > app.txt && git commit -qam fix
CASE="$T/repo/docs/test-cases/T-1-a.md"
SD="$S/implement/scripts/sdlc.sh"
verdict() { printf 'VERDICT: %s\nTEST CASE: %s\nSTEPS OBSERVED:\n  1. a -> b\n' "$1" "${3:-$CASE}" | "$SD" verdict T-1 "$2" "${4:-$CASE}"; }

echo "--- sdlc.sh"
check "base finds origin/main" test "$("$SD" base)" = origin/main
h1="$("$SD" hash docs/test-cases/T-1-a.md)"
check "hash is stable" test "$h1" = "$("$SD" hash "$CASE")"
mkdir -p docs/test-cases/lib && echo lib > docs/test-cases/lib/x.sh
check "hash covers lib/" test "$h1" != "$("$SD" hash "$CASE")"
mkdir -p .sdlc/T-1 && printf -- '- [x] research\n- [ ] red\n- [ ] green\n' > .sdlc/T-1/state.md
echo ".sdlc/" >> .gitignore
code 3 "malformed verdict refused" bash -c "echo '**Verdict: FAIL**' | '$SD' verdict T-1 red '$CASE'"
code 3 "wrong TEST CASE refused" verdict FAIL red /elsewhere.md
code 2 "red BLOCKED exits 2" verdict BLOCKED red
code 1 "red PASS is gate not met" verdict PASS red
code 4 "green with no red FAIL first is void" verdict PASS green
code 0 "red FAIL is gate met" verdict FAIL red
check "state.md red ticked" grep -q '^- \[x\] red — .sdlc/runs/T-1/red-T-1-a-' .sdlc/T-1/state.md
code 1 "green FAIL is gate not met" verdict FAIL green
code 0 "green PASS is gate met" verdict PASS green
echo "edit" >> "$CASE"
code 4 "green after a case edit is void" verdict PASS green
git checkout -q docs/test-cases/T-1-a.md 2>/dev/null || sed -i '$d' "$CASE"

out="$("$SD" tree "$CASE")"; tcase="$(sed -n 's/^case=//p' <<<"$out")"; tdir="$(sed -n 's/^tree=\([^ ]*\).*/\1/p' <<<"$out")"
check "tree holds base code" test "$(cat "$tdir/app.txt" 2>/dev/null)" = one
check "tree holds the case" cmp -s "$CASE" "$tcase"
check "tree holds .env.local" test -f "$tdir/.env.local"
check "tree case has the same hash" test "$("$SD" hash "$tcase")" = "$("$SD" hash "$CASE")"
code 0 "red on the tree copy is gate met" verdict FAIL red "$tcase" "$tcase"
check "a verdict saved from inside the tree lands in the main checkout" bash -c "cd '$tdir' && printf 'VERDICT: FAIL\nTEST CASE: %s\n' '$tcase' | '$SD' verdict T-1 red '$tcase' >/dev/null; test ! -e '$tdir/.sdlc' && test -f '$T/repo/.sdlc/T-1/hashes'"
git worktree add -q --detach "$T/userwt" main 2>/dev/null
code 1 "tree --rm refuses a worktree it did not make" "$SD" tree --rm "$T/userwt"
check "that worktree still exists" test -d "$T/userwt"
code 0 "green on the original after a tree red" verdict PASS green
check "status runs" bash -c "'$SD' status T-1 | grep -q 'same docs/test-cases/T-1-a.md'"
code 0 "tree --rm" "$SD" tree --rm "$tdir"
check "review writes 5 packets" bash -c "'$SD' review T-1 | grep -c '^packet=' | grep -qx 5"
check "packet holds its checklist section and the diff" bash -c "grep -q 'Empty input' .sdlc/T-1/review/correctness-and-edge-cases.md && grep -q '+two' .sdlc/T-1/review/tests.md"
echo "four" > uncommitted.txt
check "packets include uncommitted new files" bash -c "'$SD' review T-1 >/dev/null && grep -q '+four' .sdlc/T-1/review/tests.md"
rm uncommitted.txt

echo "--- serve.sh"
SV="$S/serve/scripts/serve.sh"
out="$("$SV" start --name web --ready / -- python3 -m http.server {port} 2>&1)"
port="$(sed -n 's/.* port=\([0-9]*\) .*/\1/p' <<<"$out")"
check "start answers" curl -sf "http://localhost:$port/"
check "port prints it" test "$("$SV" port web)" = "$port"
code 1 "second start with the same name refused" "$SV" start --name web -- python3 -m http.server {port}
code 1 "a command that exits early fails fast" "$SV" start --name bad -- false
code 0 "stop" "$SV" stop web
"$SV" start --name forked -- sh -c 'exec 1>/dev/null; python3 -m http.server $PORT & exit 0' >/dev/null 2>&1
fport="$("$SV" port forked 2>/dev/null)"
check "a server whose launcher exited is still tracked" curl -sf "http://localhost:$fport/"
"$SV" stop forked >/dev/null
check "and stop ends it" bash -c "sleep 0.5; ! curl -s -o /dev/null --max-time 1 http://localhost:$fport/"
check "port is free after stop" bash -c "! curl -s -o /dev/null --max-time 1 http://localhost:$port/"

echo "--- testsum.sh"
TS="$S/test-summary/scripts/testsum.sh"
printf "import t from 'node:test'; import a from 'node:assert';\nt('good', () => a.equal(1, 1));\nt('bad', () => a.equal(1, 2));\n" > "$T/x.test.mjs"
code 1 "passes the exit code through" "$TS" -- node --test "$T/x.test.mjs"
check "shows the failing test" grep -q 'bad' "$T/out"
check "names the full log" bash -c "grep -o 'log=[^ ]*' '$T/out' | cut -d= -f2 | xargs test -s"

echo "--- attach-images.mjs"
printf 'GIF89a' > "$T/Shot One.gif"
code 0 "publishes" node "$S/attach-images/scripts/attach-images.mjs" pr-1 "$T/Shot One.gif"
check "file is on the branch" bash -c "git -C '$T/remote.git' ls-tree --name-only attachments/pr-1 | grep -qx shot-one.gif"
check "working tree untouched" test "$(git branch --show-current)" = feature
code 1 "refuses a non-image" node "$S/attach-images/scripts/attach-images.mjs" pr-1 "$T/x.test.mjs"

echo "--- watch-origin.mjs"
git clone -q -b main "$T/remote.git" "$T/other" 2>/dev/null
(cd "$T/other" && git config user.email t@t && git config user.name t && echo three > app.txt && git commit -qam three && git push -q 2>/dev/null)
git add -A && git commit -qm wip && git checkout -q main && echo .sdlc/ >> .git/info/exclude
code 0 "--once pulls" node "$S/watch-origin/scripts/watch-origin.mjs" --once
check "fast-forwarded" test "$(cat app.txt)" = three

echo "--- fetch-ticket.sh"
FT="$S/research-ticket/scripts/fetch-ticket.sh"
check "reads a markdown ticket" bash -c "'$FT' '$CASE' | grep -qx 'title: A case'"
code 3 "plain text exits 3" "$FT" "the login is slow"
code 1 "missing file exits 1" "$FT" "$T/nope.md"

echo "--- hound.py"
mkdir -p "$T/logs/-home-x-proj"
printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"nohup node a.js &"}}]}}' > "$T/logs/-home-x-proj/s.jsonl"
check "counts a chore pattern" bash -c "python3 '$S/skillhound/scripts/hound.py' --root '$T/logs' --out '$T/hound' | grep -q 'start a server in the background'"

echo "--- secrets.sh"
SC="$S/local-secrets/scripts/secrets.sh"
git init -q "$T/sec" && cd "$T/sec" && git config user.email t@t && git config user.name t && git commit -q --allow-empty -m base
F=.env.development
code 3 "need reports a new key as missing" "$SC" need API_KEY --how "Open the site." --how "Copy the key." --url https://x.test --used-by "the tests"
check "the default file is .env.development at the repo root" test -f "$T/sec/$F"
check "the file is private" bash -c "ls -l '$T/sec/$F' | grep -q '^-rw-------'"
check "the file is gitignored" git check-ignore -q $F
check ".env.example is not ignored" bash -c "! git check-ignore -q .env.example"
check "need gives the path and line of the key" grep -qx "at=$T/sec/$F:$(grep -n '^API_KEY=' $F | cut -d: -f1)" "$T/out"
check "the steps are written" bash -c "grep -qx '#   2. Copy the key.' $F && grep -qx 'API_KEY=' $F && grep -q 'Used by: the tests' $F"
"$SC" need API_KEY --how "Other steps." >/dev/null 2>&1
check "a second need adds nothing" test "$(grep -c '^API_KEY=' $F)" = 1
check "a second need does not add a second ignore rule" test "$(grep -c '^\.env\.\*$' .gitignore)" = 1
sed 's/^API_KEY=$/API_KEY="s3cr3t value" # a note/' $F > "$T/f" && cat "$T/f" > $F
code 0 "check passes once filled" "$SC" check API_KEY
check "check never prints the value" bash -c "! grep -q s3cr3t '$T/out'"
check "check prints no at= when every key is set" bash -c "! grep -q '^at=' '$T/out'"
code 3 "check fails on one missing key" "$SC" check API_KEY OTHER
code 3 "a key in the shell environment does not count" env OTHER=1 "$SC" check OTHER
check "run loads the value without quotes or comment" test "$("$SC" run -- sh -c 'printf %s "$API_KEY"')" = "s3cr3t value"
printf 'P1=abc # note\nP2=p=q#r\nP3=val\r\nexport P4=g\nP5=# nothing\nP6=last' >> $F
check "values read like dotenv" test "$("$SC" run -- sh -c 'printf "%s|" "$P1" "$P2" "$P3" "$P4" "${P5:-}" "$P6"')" = "abc|p=q#r|val|g||last|"
"$SC" need P7 --how x >/dev/null 2>&1
check "need appends after a file with no final newline" bash -c "grep -qx 'P6=last' $F && grep -qx 'P7=' $F"
check "a new key leaves other keys alone" test "$("$SC" run -- sh -c 'printf %s "$P1"')" = abc
mkdir -p "$T/bin" && for e in code webstorm pbcopy; do printf '#!/bin/sh\necho "$@" >> "%s/%s.log"\ncat >> "%s/%s.log" 2>/dev/null; exit 0\n' "$T" "$e" "$T" "$e" > "$T/bin/$e"; chmod +x "$T/bin/$e"; done
local_env() { env -u SSH_CONNECTION -u SSH_TTY -u CLAUDE_CODE_REMOTE_ENVIRONMENT_TYPE -u TERMINAL_EMULATOR -u TERM_PROGRAM PATH="$T/bin:$PATH" "$@"; }
code 0 "open runs" local_env "$SC" open API_KEY P7
check "open starts VS Code at the first missing key" bash -c "grep -qx -- '-g $T/sec/$F:$(grep -n '^P7=' $F | cut -d: -f1)' '$T/code.log'"
check "open copies path:line" bash -c "grep -q '$T/sec/$F:' '$T/pbcopy.log' && grep -qx 'copied=yes' '$T/out'"
code 0 "open with no key finds the first empty key" local_env "$SC" open
check "that is P7" grep -qx "at=$T/sec/$F:$(grep -n '^P7=' $F | cut -d: -f1)" "$T/out"
code 0 "open in a JetBrains terminal still picks VS Code" local_env TERMINAL_EMULATOR=JetBrains-JediTerm "$SC" open P7
check "opened=code" grep -qx 'opened=code' "$T/out"
code 0 "LOCAL_SECRETS_EDITOR wins" local_env LOCAL_SECRETS_EDITOR=webstorm "$SC" open P7
check "WebStorm gets --line" bash -c "grep -q -- '--line [0-9]* $T/sec/$F' '$T/webstorm.log' && grep -qx 'opened=webstorm' '$T/out'"
code 0 "open over SSH" local_env SSH_CONNECTION="1 2 3 4" "$SC" open P7
check "starts no editor over SSH" bash -c "grep -qx 'opened=none' '$T/out' && grep -qx 'copied=no' '$T/out'"
code 3 "production is its own file" "$SC" --env production need API_KEY --how "Use the live account."
check "production file is .env.production" grep -q "^file=$T/sec/.env.production$" "$T/out"
check "production file warns it holds live values" grep -q 'LIVE production values' .env.production
check "run --env production does not load development values" test -z "$("$SC" --env production run -- sh -c 'printf %s "${API_KEY:-}"')"
code 0 "LOCAL_SECRETS_ENV picks the environment" env LOCAL_SECRETS_ENV=development "$SC" check API_KEY
code 2 "an env name with a slash is bad usage" "$SC" --env ../x path
mkdir -p sub && check "a subfolder uses the root file" test "$(cd sub && "$SC" path)" = "$T/sec/$F"
code 3 "a file in a folder that does not exist yet" env LOCAL_SECRETS_FILE=cfg/sec/.env.x "$SC" need K --how x
check "that file is gitignored too" git check-ignore -q cfg/sec/.env.x
code 3 "a custom file name" env LOCAL_SECRETS_FILE=my.secrets "$SC" need K --how x
check "gets its own ignore rule" bash -c "grep -qx '/my.secrets' .gitignore && git check-ignore -q my.secrets"
git worktree add -q "$T/secwt" 2>/dev/null
check "a worktree uses the main checkout's file" test "$(cd "$T/secwt" && "$SC" path)" = "$T/sec/$F"
git init -q "$T/sec2" && git -C "$T/sec2" -c user.email=t@t -c user.name=t commit -q --allow-empty -m base && git -C "$T/sec2" worktree add -q "$T/sec2wt" 2>/dev/null
code 3 "need in a linked worktree of a repo with no ignore rule" bash -c "cd '$T/sec2wt' && '$SC' need K --how x"
check "the rule goes in the worktree's .gitignore, to commit" grep -qx '.env.\*' "$T/sec2wt/.gitignore"
check "the main checkout ignores the file now" git -C "$T/sec2" check-ignore -q "$T/sec2/.env.development"
check "the main checkout's own files are not changed" test -z "$(git -C "$T/sec2" status --porcelain)"
git init -q --bare "$T/bare/.bare" && git -C "$T/bare/.bare" worktree add -q ../w1 2>/dev/null
check "a bare repo's worktrees share the file" test "$(cd "$T/bare/w1" && "$SC" path)" = "$T/bare/.env.development"
mkdir -p "$T/a b#c" && (cd "$T/a b#c" && "$SC" check X) > "$T/out" 2>&1
check "at= keeps the path as it is" grep -q "^at=$T/a b#c/.env.development:1$" "$T/out"
echo "PUBLIC_URL=x" > .env.staging && git add -f .env.staging && git commit -qm defaults
check "a tracked .env.staging falls back to .env.staging.local" test "$("$SC" --env staging path)" = "$T/sec/.env.staging.local"
code 1 "need refuses a tracked file" env LOCAL_SECRETS_FILE=.env.staging "$SC" need NEW_KEY --how "x"
code 2 "need without steps is bad usage" "$SC" need NEW_KEY
cd "$T/repo" || exit 1

echo
[ $fails = 0 ] && echo "all passed" || { echo "$fails failed"; exit 1; }
