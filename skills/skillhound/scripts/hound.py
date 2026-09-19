#!/usr/bin/env python3
"""Mine Claude Code chat logs for repeated work.

    hound.py [--since YYYY-MM-DD] [--root DIR] [--out DIR] [--top N]

Reads every transcript under --root (default ~/.claude/projects), writes one event per
line to OUT/events.jsonl, and prints the counts a skill hunt starts from: tools, Bash
command heads spread across projects, web lookups, skills called, repeated user prompts,
and known chore patterns. Only transcripts modified on or after --since are read.

events.jsonl fields: p project, s session file, sub subagent (bool), k prompt|tool|title,
n tool name, v main input, d Bash description.
"""
import argparse, collections, glob, json, os, re, sys, datetime

ap = argparse.ArgumentParser()
ap.add_argument('--since')
ap.add_argument('--root', default=os.path.expanduser('~/.claude/projects'))
ap.add_argument('--out', default='/tmp/skillhound')
ap.add_argument('--top', type=int, default=40)
a = ap.parse_args()
since = datetime.datetime.fromisoformat(a.since).timestamp() if a.since else 0
os.makedirs(a.out, exist_ok=True)

def project(cwd, path):
    """The project a chat ran in, from its working folder. Worktrees count as their parent."""
    if not cwd:
        return path[len(a.root) + 1:].split('/')[0]
    m = re.search(r'/\.t3/worktrees/([^/]+)', cwd)
    if m:
        return m.group(1)
    return os.path.basename(re.split(r'/\.claude/worktrees/', cwd)[0].rstrip('/')) or cwd

events, files = [], 0
for f in glob.glob(a.root + '/**/*.jsonl', recursive=True):
    if os.path.getmtime(f) < since:
        continue
    files += 1
    sub, s = '/subagents/' in f, os.path.basename(f)
    rows = []
    for line in open(f, errors='ignore'):
        try:
            rows.append(json.loads(line))
        except ValueError:
            pass
    # The first working folder is where the chat started.
    p_now = project(next((o['cwd'] for o in rows if isinstance(o, dict) and o.get('cwd')), None), f)
    for o in rows:
        if not isinstance(o, dict):
            continue
        t = o.get('type')
        if t == 'ai-title':
            events.append({'p': p_now, 's': s, 'sub': sub, 'k': 'title', 'v': o.get('aiTitle') or o.get('title')})
        c = (o.get('message') or {}).get('content')
        if t == 'user' and not o.get('isMeta'):
            texts = [c] if isinstance(c, str) else [x.get('text', '') for x in c or [] if isinstance(x, dict) and x.get('type') == 'text']
            for x in texts:
                if x and not x.startswith('<'):
                    events.append({'p': p_now, 's': s, 'sub': sub, 'k': 'prompt', 'v': x[:1500]})
        if t == 'assistant' and isinstance(c, list):
            for x in c:
                if x.get('type') != 'tool_use':
                    continue
                i = x.get('input') or {}
                v = next((i[k] for k in ('command', 'query', 'url', 'skill', 'file_path', 'pattern', 'prompt') if isinstance(i.get(k), str)), json.dumps(i)[:300])
                d = i.get('description') if isinstance(i.get('description'), str) else ''
                events.append({'p': p_now, 's': s, 'sub': sub, 'k': 'tool', 'n': x['name'], 'v': v[:800], 'd': d[:200]})

with open(os.path.join(a.out, 'events.jsonl'), 'w') as out:
    for e in events:
        out.write(json.dumps(e) + '\n')

tools = [e for e in events if e['k'] == 'tool']
bash = [e for e in tools if e['n'] == 'Bash']
sessions = collections.defaultdict(set)
for e in events:
    sessions[e['p']].add(e['s'])

def head(cmd):
    cmd = re.sub(r'^(cd [^&;]+(&&|;)\s*|[A-Z_]+=\S+\s+)+', '', cmd.strip())
    toks = cmd.split()
    if not toks:
        return ''
    h = toks[0]
    if h in ('npx', 'npm', 'pnpm', 'yarn', 'bun', 'git', 'gh', 'python3', 'node', 'docker', 'uv', 'cargo', 'go') and len(toks) > 1:
        h += ' ' + toks[1]
        if toks[1] in ('run', 'exec', 'api', 'pr', 'issue', 'run', '--filter') and len(toks) > 2:
            h += ' ' + toks[2]
    return h

def section(title):
    print(f'\n## {title}')

print(f'# skillhound: {files} transcripts, {len(tools)} tool calls, {len(bash)} Bash calls')
print(f'events: {a.out}/events.jsonl')
section('Sessions per project')
for p, ss in sorted(sessions.items(), key=lambda kv: -len(kv[1])):
    print(f'{len(ss):5} {p}')

section('Tools')
for n, c in collections.Counter(e['n'] for e in tools).most_common(a.top):
    print(f'{c:6} {n}')

section('Bash command heads in 2+ projects (calls, projects, head)')
spread, count = collections.defaultdict(set), collections.Counter()
for e in bash:
    h = head(e['v'])
    count[h] += 1
    spread[h].add(e['p'])
for h, c in [(h, c) for h, c in count.most_common() if len(spread[h]) >= 2 and c >= 5][:a.top * 2]:
    print(f'{c:6} {len(spread[h]):3} {h}')

# Chores worth a script. Each is a regex over Bash commands.
PATTERNS = {
    'start a server in the background': r'\bnohup\b|\bsetsid\b|&\s*echo \$!',
    'poll until something answers': r'for i in \$\(seq|until (curl|\[)|while ! curl',
    'kill by port or name': r'\bfuser -k|\bpkill\b|\bkillall\b|kill \$\(lsof',
    'look up who holds a port': r'\blsof -i|\bss -[lnpt]+',
    'cut test output with tail or grep': r'(vitest|jest|node --test|pytest|go test|pnpm test|npm test).*\|\s*(tail|grep|head)',
    'poll PR or CI state': r'gh (pr (view|checks)|run (list|view|watch))',
    'make a git worktree': r'git worktree add',
    'hash a file': r'sha256sum|shasum',
    'rewrite a file with an inline script': r"python3 - <<|node -e .*writeFileSync",
}
section('Chore patterns (calls, sessions, projects)')
for name, rx in PATTERNS.items():
    hits = [e for e in bash if re.search(rx, e['v'])]
    if hits:
        print(f"{len(hits):6} {len({e['s'] for e in hits}):4} {len({e['p'] for e in hits}):3}  {name}")

section('Web lookups (count, target)')
web = collections.Counter()
for e in tools:
    if e['n'] in ('WebFetch', 'WebSearch'):
        web[re.sub(r'[?#].*', '', e['v'])[:110]] += 1
for v, c in web.most_common(a.top):
    print(f'{c:5} {v}')

section('Skills called')
for v, c in collections.Counter(e['v'] for e in tools if e['n'] == 'Skill').most_common(a.top):
    print(f'{c:5} {v}')

section('User prompts seen in 2+ sessions (first 100 chars)')
seen = collections.defaultdict(set)
for e in events:
    if e['k'] == 'prompt' and not e['sub']:
        key = re.sub(r'\s+', ' ', e['v'].strip().lower())[:100]
        if len(key) > 8:
            seen[key].add(e['s'])
for k, ss in sorted(seen.items(), key=lambda kv: -len(kv[1]))[:a.top]:
    if len(ss) >= 2:
        print(f'{len(ss):4} {k}')
