"""Where a Codex run's time went, from its session rollout.

  python timeline_codex.py EVENTS.jsonl        (finds the rollout by the thread id in events.jsonl)
  python timeline_codex.py ROLLOUT.jsonl

Codex's tool is `exec`: the model sends a script (custom_tool_call, input = the script) and gets
its output (custom_tool_call_output, same call_id). A call's time is output.timestamp -
call.timestamp; the rest of the run is model time (API latency). Buckets by what the script runs.
"""
import json
import os
import re
import sys
from datetime import datetime

BUCKETS = [
    ("gradle build/test", r"gradlew(\.bat)? (--no-daemon )?(build|test|check|compile|elcore)"),  # a patch + build script counts as the build
    ("file patch", r"\*\*\* Begin Patch|apply_patch"),  # before "gradle other": a patch of build.gradle is not a Gradle run
    ("stdin/wait", r"tools\.write_stdin"),
    ("gradle other", r"gradle(w(\.bat)?)? "),
    ("server start/stop", r"bootRun|Start-Process|Stop-Process|java -jar|Get-NetTCPConnection"),
    ("http requests", r"curl|Invoke-WebRequest|Invoke-RestMethod|http://localhost"),
    ("jar/cache search", r"\.gradle\\|jar tf|\.m2"),
    ("read/list", r"Get-Content|Get-ChildItem|cat |ls |type "),
]


def ts(s):
    return datetime.fromisoformat(s.replace("Z", "+00:00")).timestamp()


def rollout_for(path):
    if "rollout-" in os.path.basename(path):
        return path
    thread = None
    for line in open(path, encoding="utf-8"):
        e = json.loads(line)
        if e.get("type") == "thread.started":
            thread = e["thread_id"]
            break
    for d, _, files in os.walk(os.path.expanduser("~/.codex/sessions")):
        for f in files:
            if thread and f.endswith(thread + ".jsonl"):
                return os.path.join(d, f)
    sys.exit("no rollout for " + path)


def label(script):
    s = re.sub(r"\s+", " ", script)
    m = re.search(r"\*\*\* (Add|Update|Delete) File: (\S+)", s)
    if m:
        n = len(re.findall(r"\*\*\* (Add|Update|Delete) File:", s))
        return "patch %d file(s): %s%s" % (n, m.group(2), " ..." if n > 1 else "")
    m = re.search(r"tools\.(exec_command|write_stdin)\(\{(?:cmd:\")?(.{0,110})", s)
    return ((m.group(1) + ": " + m.group(2)) if m else s[:110]).rstrip("'\")")


def bucket(script):
    for name, rx in BUCKETS:
        if re.search(rx, script):
            return name
    return "other"


def main():
    path = rollout_for(sys.argv[1])
    calls, outputs, first, last = {}, {}, None, None
    for line in open(path, encoding="utf-8"):
        e = json.loads(line)
        t = ts(e["timestamp"])
        first = t if first is None else first
        last = t
        p = e.get("payload") or {}
        if e.get("type") == "response_item" and p.get("type") == "custom_tool_call":
            calls[p["call_id"]] = (t, p.get("input") or "")
        elif e.get("type") == "response_item" and p.get("type") == "custom_tool_call_output":
            outputs[p["call_id"]] = t
    rows, sums = [], {}
    for cid, (t0, script) in calls.items():
        t1 = outputs.get(cid, t0)
        rows.append((t0 - first, t1 - t0, bucket(script), label(script)))
        sums[bucket(script)] = sums.get(bucket(script), 0) + (t1 - t0)
    rows.sort()
    print("%7s %7s  %-18s %s" % ("at", "took", "bucket", "command"))
    for at, took, b, lab in rows:
        print("%4d:%02d %5.1fs  %-18s %s" % (at // 60, at % 60, took, b, lab))
    tool = sum(r[1] for r in rows)
    total = last - first
    print("\ncalls %d, total %d:%02d, in tools %d:%02d, model (API) time %d:%02d" % (
        len(rows), total // 60, total % 60, tool // 60, tool % 60, (total - tool) // 60, (total - tool) % 60))
    for b, s in sorted(sums.items(), key=lambda x: -x[1]):
        print("  %-18s %d:%02d" % (b, s // 60, s % 60))


main()
