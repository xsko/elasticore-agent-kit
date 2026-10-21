"""Timeline of a Claude Code arm from its events.jsonl (stream-json).

  python timeline_claude.py EVENTS.jsonl          one line per tool call: wall time since start, tool, what, seconds it took
  python timeline_claude.py EVENTS.jsonl --sum    totals per bucket (model thinking, build, run/curl, read guide, ...)
"""
import json
import sys
from datetime import datetime


def ts(e):
    t = e.get("timestamp")
    if t is None:
        return None
    if isinstance(t, (int, float)):
        return t / 1000.0 if t > 1e12 else float(t)
    try:
        return datetime.fromisoformat(t.replace("Z", "+00:00")).timestamp()
    except Exception:
        return None


def short(b):
    i = b.get("input") or {}
    for k in ("command", "file_path", "pattern", "description", "prompt", "skill", "query"):
        if i.get(k):
            s = str(i[k]).replace("\n", " ")
            return s[:110]
    return json.dumps(i)[:110]


def bucket(tool, what):
    w = what.lower()
    if tool in ("Read", "Glob", "Grep"):
        if "blueprint" in w or "guide" in w or "skill" in w or "reference" in w or "quick-reference" in w or ".md" in w:
            return "read docs/guides"
        if ".jar" in w or ".m2" in w or "gradle" in w and "cache" in w:
            return "dig jars"
        return "read project"
    if tool in ("Write", "Edit", "MultiEdit"):
        return "write code"
    if tool in ("Bash", "PowerShell"):
        if "gradlew" in w or "gradle" in w:
            if "bootjar" in w or "build" in w or "compile" in w or "elcoregen" in w or "test" in w:
                return "gradle build"
            return "gradle other"
        if "java -jar" in w or "start-process" in w or "curl" in w or "invoke-" in w or "api-docs" in w or "localhost" in w:
            return "run+call api"
        if "unzip" in w or ".jar" in w or ".m2" in w or "javap" in w:
            return "dig jars"
        if "cat " in w or "ls " in w or "find " in w or "head " in w or "type " in w:
            return "read project"
        return "shell other"
    if tool in ("Task", "Agent"):
        return "subagent"
    if tool == "Skill":
        return "skill"
    return tool


def main():
    path = sys.argv[1]
    summarize = "--sum" in sys.argv
    events = []
    for line in open(path, encoding="utf-8"):
        line = line.strip()
        if not line:
            continue
        try:
            events.append(json.loads(line))
        except Exception:
            pass
    t0 = None
    for e in events:
        t = ts(e)
        if t is not None:
            t0 = t
            break
    pending = {}  # tool_use_id -> (t, tool, what)
    rows = []
    last_t = t0
    model_gaps = []  # time between a tool result and the next tool call = model thinking + output
    results = []
    for e in events:
        t = ts(e)
        if e.get("type") == "assistant":
            for b in e["message"].get("content", []):
                if b.get("type") == "tool_use":
                    pending[b["id"]] = (t, b["name"], short(b))
                    if last_t is not None and t is not None:
                        model_gaps.append(t - last_t)
                    last_t = t
        elif e.get("type") == "user":
            c = e["message"].get("content")
            if isinstance(c, list):
                for b in c:
                    if b.get("type") == "tool_result" and b.get("tool_use_id") in pending:
                        st, tool, what = pending.pop(b["tool_use_id"])
                        dur = (t - st) if (t is not None and st is not None) else None
                        rc = b.get("content")
                        txt = rc if isinstance(rc, str) else " ".join(x.get("text", "") for x in rc if isinstance(x, dict)) if isinstance(rc, list) else ""
                        rows.append((st - t0 if st and t0 else None, tool, what, dur, bool(b.get("is_error")), txt[:90].replace("\n", " | ")))
                        last_t = t
        elif e.get("type") == "result":
            results.append({k: e.get(k) for k in ("duration_ms", "duration_api_ms", "num_turns", "total_cost_usd")})
    if not summarize:
        for off, tool, what, dur, err, txt in rows:
            print("%7s  %-10s %5s  %s%s" % (
                "%d:%02d" % divmod(int(off), 60) if off is not None else "?",
                tool, "%.0fs" % dur if dur is not None else "?", "ERR " if err else "", what))
            if err:
                print("                            -> " + txt)
        print("results:", results)
        return
    tot = {}
    cnt = {}
    for off, tool, what, dur, err, txt in rows:
        b = bucket(tool, what)
        tot[b] = tot.get(b, 0) + (dur or 0)
        cnt[b] = cnt.get(b, 0) + 1
    wall = (rows[-1][0] + (rows[-1][3] or 0)) if rows else 0
    print("tool calls: %d, tool time: %.0fs, wall (first call to last result): %.0fs" % (len(rows), sum(r[3] or 0 for r in rows), wall))
    for b in sorted(tot, key=lambda k: -tot[k]):
        print("  %-16s %4d calls %6.0fs" % (b, cnt[b], tot[b]))
    print("model gaps (result -> next call): %d, total %.0fs, max %.0fs" % (len(model_gaps), sum(model_gaps), max(model_gaps) if model_gaps else 0))
    print("errors:", sum(1 for r in rows if r[4]))
    print("results:", results)


main()
