"""Where a Claude Code arm struggled, from its events.jsonl: the calls worth an improvement.

usage: python struggles.py EVENTS.jsonl [--full]
Prints, in order, with wall time since the first event:
  JAR    a look inside a jar or ~/.m2 (the docs did not answer)
  GUIDE  a search or read of the copied guides (blueprint/elasticore-*.md)
  KIT    a read of the kit's pages
  ERR    a tool result that is an error, or a build that failed (first lines of it)
  HAND   a Write/Edit of a source file (java/kt/ts/js/html) - hand-written code
  DSL    a Write/Edit of the blueprint YAML
  GEN    generator output lines that are warnings or skips
--full prints the whole command or pattern instead of 160 characters.
"""
import json
import re
import sys
from datetime import datetime

sys.stdout.reconfigure(encoding="utf-8")
path = sys.argv[1]
full = "--full" in sys.argv
W = 100000 if full else 160


def ts(e):
    t = e.get("timestamp")
    if isinstance(t, str):
        try:
            return datetime.fromisoformat(t.replace("Z", "+00:00")).timestamp()
        except Exception:
            return None
    return None


events = [json.loads(l) for l in open(path, encoding="utf-8") if l.strip()]
t0 = None
pending = {}
for e in events:
    t = ts(e)
    if t and t0 is None:
        t0 = t
    when = "%3d:%02d" % divmod(int((t or t0 or 0) - (t0 or 0)), 60) if t0 else "  ?:??"
    msg = e.get("message") or {}
    for b in msg.get("content") or [] if isinstance(msg.get("content"), list) else []:
        if b.get("type") == "tool_use":
            i = b.get("input") or {}
            name = b.get("name")
            pending[b.get("id")] = (name, i)
            text = i.get("command") or i.get("pattern") or i.get("file_path") or ""
            text = str(text).replace("\n", " | ")
            fp = str(i.get("file_path") or "")
            tag = None
            if re.search(r"\.jar|\.m2|unzip|javap|jar tf|ZipFile|decompil", text, re.I):
                tag = "JAR"
            elif name in ("Write", "Edit"):
                if re.search(r"blueprint.*\.ya?ml$", fp):
                    tag = "DSL"
                elif re.search(r"\.(java|kt|ts|js|html|properties|sql)$", fp) or fp.endswith("application.yml"):
                    tag = "HAND"
            elif re.search(r"elasticore-[a-z-]+guide|blueprint/\*\.md|blueprint\\\*\.md", text):
                tag = "GUIDE"
            elif name in ("Grep", "Read") and re.search(r"elasticore-[a-z-]+guide|blueprint", text + str(i.get("path") or "")):
                tag = "GUIDE"
            elif re.search(r"plugin[/\\]skills", text):
                tag = "KIT"
            if tag:
                print("%s %-5s %-10s %s" % (when, tag, name, text[:W]))
        elif b.get("type") == "tool_result":
            content = b.get("content")
            if isinstance(content, list):
                content = " ".join(c.get("text", "") for c in content if isinstance(c, dict))
            content = str(content or "")
            name, i = pending.get(b.get("tool_use_id"), ("?", {}))
            bad = b.get("is_error") or re.search(r"BUILD FAILED|error:|^e: |Compilation error|FAILURE:", content, re.M)
            if bad:
                lines = [l for l in content.splitlines() if l.strip()][:6]
                print("%s ERR   %-10s %s" % (when, name, " | ".join(lines)[:W * 2]))
            gen = [l.strip() for l in content.splitlines()
                   if re.search(r"SKIP\(user-modified|unresolved|LOAD ERROR|warning:|which the selected rules", l)]
            for l in gen[:8]:
                print("%s GEN   %-10s %s" % (when, name, l[:W]))
