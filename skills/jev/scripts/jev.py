#!/usr/bin/env python3
"""Ask Jev (TypeSafe System One) one multiple-choice or yes/no question.

  jev.py --state TEXT --ask QUESTION --option KEY="description" --option KEY2="..."
  jev.py --state TEXT --ask QUESTION --yes-no

--state is the context Jev reads. Use --state - to read it from stdin.
Prints the answer on line 1 (the option key, or yes/no), then confidence and the
probability of each answer. Exit 0 on an answer, 2 on a usage or API error.
Key: $TYPESAFE_API_KEY, else ~/.config/jev/api_key.
"""
import argparse, json, os, sys, urllib.error, urllib.request
from pathlib import Path


def key():
    k = os.environ.get("TYPESAFE_API_KEY")
    if k:
        return k.strip()
    f = Path.home() / ".config/jev/api_key"
    if f.exists():
        return f.read_text().strip()
    sys.exit("jev: no key. Set TYPESAFE_API_KEY or write it to ~/.config/jev/api_key")


def build(state, ask, options, yes_no):
    if yes_no:
        q = {"type": "noul", "instructions": ask}
    else:
        criteria = {}
        for o in options:
            k, sep, desc = o.partition("=")
            if not sep or not k.strip():
                raise ValueError(f"--option must be KEY=description, got {o!r}")
            criteria[k.strip()] = desc.strip()
        if len(criteria) < 2:
            raise ValueError("give at least two --option values, or --yes-no")
        q = {"type": "choice", "instructions": ask, "criteria": criteria}
    return {"model": os.environ.get("TYPESAFE_DEFAULT_MODEL", "jev-latest"),
            "state": state, "questions": {"q": q}}


def render(a):
    if a["type"] == "noul":
        p = a["noul"]
        return f"{'yes' if p >= 0.5 else 'no'}\np_yes={p:.2f}"
    probs = " ".join(f"{k}={v:.2f}" for k, v in sorted(a["probabilities"].items(), key=lambda kv: -kv[1]))
    return f"{a['choice']}\nconfidence={a['confidence']:.2f} {probs}"


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--state", required=True)
    ap.add_argument("--ask", required=True)
    ap.add_argument("--option", action="append", default=[])
    ap.add_argument("--yes-no", action="store_true")
    a = ap.parse_args()
    state = sys.stdin.read() if a.state == "-" else a.state
    try:
        body = build(state, a.ask, a.option, a.yes_no)
    except ValueError as e:
        print(f"jev: {e}", file=sys.stderr); sys.exit(2)
    base = os.environ.get("TYPESAFE_BASE_URL", "https://api.typesafe.ai")
    req = urllib.request.Request(f"{base}/v1/systemone", json.dumps(body).encode(),
                                 {"Authorization": f"Bearer {key()}", "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            print(render(json.load(r)["answers"]["q"]))
    except urllib.error.HTTPError as e:
        print(f"jev: HTTP {e.code} {e.read().decode(errors='replace')[:300]}", file=sys.stderr); sys.exit(2)
    except (urllib.error.URLError, TimeoutError) as e:
        print(f"jev: {e}", file=sys.stderr); sys.exit(2)


def demo():
    b = build("s", "which?", ["a=one", "b = two"], False)
    assert b["questions"]["q"]["criteria"] == {"a": "one", "b": "two"}
    assert build("s", "ok?", [], True)["questions"]["q"]["type"] == "noul"
    for bad in (["a=one"], ["nokey"]):
        try: build("s", "x", bad, False); raise AssertionError(bad)
        except ValueError: pass
    assert render({"type": "noul", "noul": 0.9}).startswith("yes")
    assert render({"type": "choice", "choice": "b", "confidence": 0.5,
                   "probabilities": {"a": 0.2, "b": 0.8}}) == "b\nconfidence=0.50 b=0.80 a=0.20"
    print("ok")


if __name__ == "__main__":
    demo() if sys.argv[1:] == ["--self-test"] else main()
