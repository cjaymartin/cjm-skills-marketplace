#!/usr/bin/env bash
# Start, find, and stop local servers without hand-written nohup, curl loops, or kill-by-port.
#
#   serve.sh start --name NAME [--port N|auto] [--ready PATH] [--timeout SEC] [--dir DIR] -- CMD...
#   serve.sh stop NAME|--all
#   serve.sh ls
#   serve.sh port NAME
#   serve.sh logs NAME [LINES]
#
# start  picks a free port (auto is the default), runs CMD with PORT=<port> in the environment
#        and every "{port}" in CMD replaced, then waits until the port answers. With --ready it
#        waits for an HTTP answer below 500 from that path. Prints one line:
#          OK name=api port=23817 pid=4242 url=http://localhost:23817 log=/tmp/...
#        On failure it prints the log tail, stops what it started, and exits 1.
# stop   stops only a process this script started, and only if its pid still belongs to it.
#        It never kills by port or by name pattern, so other people's servers are safe.
#
# State lives in $SERVE_STATE (default ${TMPDIR:-/tmp}/serve-<uid>), one folder per checkout,
# so two worktrees can each run a server named "api".

set -uo pipefail

STATE_ROOT="${SERVE_STATE:-${TMPDIR:-/tmp}/serve-$(id -u)}"
top="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
key="$(printf '%s' "$top" | cksum | cut -d' ' -f1)"
here="$STATE_ROOT/$key"

die() { echo "serve: $*" >&2; exit 1; }
usage() { sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }

# 0 when something accepts connections on the port.
listening() {
  curl -s -o /dev/null --max-time 1 "http://localhost:$1/"
  local rc=$?
  [ "$rc" -ne 7 ] && [ "$rc" -ne 28 ]
}

started_at() { ps -o lstart= -p "$1" 2>/dev/null; }
# A zombie (exited, not yet reaped) still has a start time, so it counts as gone.
running() { local st; st="$(ps -o stat= -p "$1" 2>/dev/null)" && [ -n "$st" ] && [ "${st#Z}" = "$st" ]; }

# 0 when a live, non-zombie process sits in process group $1.
group_has_members() { ps -A -o pgid=,stat= | awk -v g="$1" '$1 == g && $2 !~ /^Z/ { found = 1 } END { exit !found }'; }

# 0 when what this script started in a state folder still runs. The first process may
# have exited and left children behind (sh -c 'server &'). They keep its process group.
alive() {
  local d="$1" pid
  pid="$(cat "$d/pid" 2>/dev/null)" || return 1
  [ -n "$pid" ] || return 1
  if running "$pid"; then
    # Same pid, other start time: the pid was reused by an unrelated process.
    [ "$(started_at "$pid")" = "$(cat "$d/started" 2>/dev/null)" ]
  else
    # ponytail: assumes the group id was not reused after our whole group ended.
    group_has_members "$pid"
  fi
}

stop_one() {
  local d="$1" name pid
  name="$(basename "$d")"
  if alive "$d"; then
    pid="$(cat "$d/pid")"
    kill -TERM -- "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null
    for _ in $(seq 1 50); do alive "$d" || break; sleep 0.1; done
    if alive "$d"; then kill -KILL -- "-$pid" 2>/dev/null || kill -KILL "$pid" 2>/dev/null; fi
    echo "stopped name=$name pid=$pid port=$(cat "$d/port")"
  else
    echo "not running name=$name (cleared stale state)"
  fi
  rm -rf "$d"
}

cmd_start() {
  local name="" port="auto" ready="" timeout=60 dir="$PWD"
  while [ $# -gt 0 ]; do
    case "$1" in
      --name) name="$2"; shift 2 ;;
      --port) port="$2"; shift 2 ;;
      --ready) ready="$2"; shift 2 ;;
      --timeout) timeout="$2"; shift 2 ;;
      --dir) dir="$2"; shift 2 ;;
      --) shift; break ;;
      *) die "unknown option $1 (the command goes after --)" ;;
    esac
  done
  [ -n "$name" ] || die "--name is required"
  [ $# -gt 0 ] || die "no command given after --"
  [[ "$name" =~ ^[A-Za-z0-9._-]+$ ]] || die "--name may use letters, digits, dot, dash, underscore"
  [[ "$timeout" =~ ^[0-9]+$ ]] || die "--timeout must be whole seconds"
  [ -d "$dir" ] || die "--dir $dir does not exist"

  local d="$here/$name"
  if [ -d "$d" ]; then
    alive "$d" && die "$name is already running on port $(cat "$d/port"). Stop it first: serve.sh stop $name"
    rm -rf "$d"
  fi

  if [ "$port" = auto ]; then
    # ponytail: random pick then probe; two starts in the same instant can still race.
    local tries=0
    port=$((20000 + RANDOM % 20000))
    while listening "$port"; do
      tries=$((tries + 1)); [ $tries -lt 200 ] || die "no free port found"
      port=$((20000 + RANDOM % 20000))
    done
  else
    [[ "$port" =~ ^[0-9]+$ ]] || die "--port must be digits or auto"
    listening "$port" && die "port $port is already in use. Use --port auto, or run serve.sh ls"
  fi

  local args=() a
  for a in "$@"; do args+=("${a//\{port\}/$port}"); done

  mkdir -p "$d"
  local log="$d/log"
  printf '%s\n' "$port" > "$d/port"
  printf '%s\n' "$top" > "$d/checkout"
  printf '%q ' "${args[@]}" > "$d/cmd"

  # set -m puts the job in its own process group, so stop can end its children too.
  set -m
  (cd "$dir" && PORT="$port" exec nohup "${args[@]}" </dev/null >"$log" 2>&1) &
  local pid=$!
  set +m
  printf '%s\n' "$pid" > "$d/pid"
  started_at "$pid" > "$d/started"

  local deadline=$((SECONDS + timeout)) code=""
  while [ $SECONDS -lt $deadline ]; do
    if ! alive "$d"; then
      echo "FAILED name=$name: the command and its children exited before the port answered. Log tail:" >&2
      tail -n 30 "$log" >&2
      rm -rf "$d"
      exit 1
    fi
    if [ -n "$ready" ]; then
      code="$(curl -s -o /dev/null --max-time 2 -w '%{http_code}' "http://localhost:$port/${ready#/}")"
      [ "$code" != 000 ] && [ "$code" -lt 500 ] && break
    elif listening "$port"; then
      break
    fi
    sleep 0.5
  done
  if [ $SECONDS -ge $deadline ]; then
    echo "FAILED name=$name: no answer on port $port after ${timeout}s. Log tail:" >&2
    tail -n 30 "$log" >&2
    stop_one "$d" >/dev/null
    exit 1
  fi
  echo "OK name=$name port=$port pid=$pid url=http://localhost:$port${code:+ http=$code} log=$log"
}

cmd_ls() {
  local d found=0
  for d in "$STATE_ROOT"/*/*/; do
    [ -d "$d" ] || continue
    d="${d%/}"
    alive "$d" || { rm -rf "$d"; continue; }
    found=1
    printf 'name=%s port=%s pid=%s checkout=%s\n  cmd: %s\n' "$(basename "$d")" "$(cat "$d/port")" \
      "$(cat "$d/pid")" "$(cat "$d/checkout")" "$(cat "$d/cmd")"
  done
  [ $found = 1 ] || echo "no servers started by serve.sh are running"
}

need_name() {
  [ -n "${1:-}" ] || die "name required"
  [ -d "$here/$1" ] || die "no server named $1 in $top. Run: serve.sh ls"
}

case "${1:-}" in
  start) shift; cmd_start "$@" ;;
  stop)
    [ -n "${2:-}" ] || die "stop needs a name or --all"
    if [ "$2" = --all ]; then
      for d in "$here"/*/; do [ -d "$d" ] && stop_one "${d%/}"; done; true
    else
      need_name "$2"; stop_one "$here/$2"
    fi ;;
  ls) cmd_ls ;;
  port) need_name "${2:-}"; cat "$here/$2/port" ;;
  logs) need_name "${2:-}"; tail -n "${3:-50}" "$here/$2/log" ;;
  *) usage ;;
esac
