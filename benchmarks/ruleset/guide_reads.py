"""What an arm read to find out how ElastiCORE works, from its events.jsonl (Claude Code or opencode).

usage: python guide_reads.py LABEL EVENTS.jsonl [LABEL EVENTS.jsonl ...]

Per arm, the tool calls that touched
  index   blueprint/elasticore-guide-index.md
  guides  the copied guides, blueprint/elasticore-*-guide.md (a search over blueprint/*.md counts here)
  kit     the kit's own pages (skills/elasticore/...)
  jar     a jar, ~/.m2 or ~/.gradle caches, javap - looking for what the docs did not say
with the number of calls, the characters their results brought into the context, and for the guides
how many reads took a whole file (no offset/limit, or a cat/type of it). Characters, not tokens: the
results are mostly Korean, which costs more tokens per character than English; the point is the
comparison between arms.
"""
import json
import re
import sys

sys.stdout.reconfigure(encoding="utf-8")

INDEX = re.compile(r"elasticore-guide-index\.md")
GUIDE = re.compile(r"elasticore-[a-z-]*guide\.md|blueprint[/\\]+\*\.md|blueprint[/\\]+[^\s\"']*\*\.md")
KIT = re.compile(r"skills[/\\]+elasticore")
JAR = re.compile(r"\.jar\b|[/\\]\.m2[/\\]|[/\\]\.gradle[/\\]caches|javap|jar tf|unzip", re.I)


def calls(path):
    """(tool, input dict, result text) for every tool call, in order."""
    events = []
    for line in open(path, encoding="utf-8", errors="replace"):
        line = line.strip()
        if line:
            try:
                events.append(json.loads(line))
            except ValueError:
                pass
    out, pending = [], {}
    for e in events:
        if e.get("type") == "tool_use" and "part" in e:  # opencode
            st = e["part"].get("state") or {}
            out.append((e["part"].get("tool"), st.get("input") or {}, str(st.get("output") or "")))
            continue
        msg = e.get("message") or {}
        content = msg.get("content") if isinstance(msg.get("content"), list) else []
        for b in content:
            if b.get("type") == "tool_use":
                pending[b.get("id")] = len(out)
                out.append((b.get("name"), b.get("input") or {}, ""))
            elif b.get("type") == "tool_result" and b.get("tool_use_id") in pending:
                c = b.get("content")
                if isinstance(c, list):
                    c = "".join(x.get("text", "") for x in c if isinstance(x, dict))
                i = pending.pop(b.get("tool_use_id"))
                out[i] = (out[i][0], out[i][1], str(c or ""))
    return out


def kind(tool, inp):
    text = json.dumps(inp, ensure_ascii=False)
    if INDEX.search(text):
        return "index"
    if GUIDE.search(text):
        return "guides"
    if KIT.search(text):
        return "kit"
    if JAR.search(text):
        return "jar"
    return None


def whole(tool, inp):
    if (tool or "").lower() == "read":
        return not (inp.get("offset") or inp.get("limit"))
    cmd = str(inp.get("command") or "")
    return bool(re.search(r"\b(cat|type|Get-Content)\b[^|]*guide\.md", cmd)) and not re.search(r"sed -n|head|tail|Select", cmd)


print("%-14s %-7s %6s %10s %6s" % ("arm", "kind", "calls", "chars", "whole"))
for label, path in zip(sys.argv[1::2], sys.argv[2::2]):
    totals = {}
    for tool, inp, result in calls(path):
        k = kind(tool, inp)
        if not k:
            continue
        t = totals.setdefault(k, [0, 0, 0])
        t[0] += 1
        t[1] += len(result)
        if k == "guides" and whole(tool, inp):
            t[2] += 1
    for k in ("index", "guides", "kit", "jar"):
        if k in totals:
            n, chars, w = totals[k]
            print("%-14s %-7s %6d %10d %6s" % (label, k, n, chars, w if k == "guides" else ""))
