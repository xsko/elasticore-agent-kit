"""Writes the isolated opencode config of one arm from the user's opencode.json (JSONC).

  python opencode_config.py write OUT MODEL PROVIDER [SKILL]
      OUT       the opencode.json to write
      MODEL     provider/model
      PROVIDER  the provider key whose block is copied from ~/.config/opencode/opencode.json
                (values copied, never printed)
      SKILL     the one skill allowed (the kit's `elasticore` for that arm; none for the plain arm)
  python opencode_config.py shape [KEYS]
      the structure of the user's settings with values hidden (URLs cut to the host)
"""
import json
import os
import re
import sys

PATH = os.path.expanduser("~/.config/opencode/opencode.json")


def load():
    t = open(PATH, encoding="utf-8").read()
    out, i, in_str = [], 0, False
    while i < len(t):
        c = t[i]
        if in_str:
            out.append(c)
            if c == "\\":
                out.append(t[i + 1])
                i += 2
                continue
            if c == '"':
                in_str = False
            i += 1
            continue
        if c == '"':
            in_str = True
            out.append(c)
            i += 1
            continue
        if t.startswith("//", i):
            j = t.find("\n", i)
            i = len(t) if j < 0 else j
            continue
        if t.startswith("/*", i):
            j = t.find("*/", i)
            i = len(t) if j < 0 else j + 2
            continue
        out.append(c)
        i += 1
    return json.loads(re.sub(r",(\s*[}\]])", r"\1", "".join(out)))


def shape(v):
    if isinstance(v, dict):
        return {k: shape(x) for k, x in v.items()}
    if isinstance(v, list):
        return [shape(x) for x in v[:3]]
    if isinstance(v, str):
        if v.startswith("http"):
            return re.sub(r"(https?://[^/]+).*", r"\1/...", v)
        if v.startswith("{env:"):
            return v
        return "<str %d>" % len(v)
    return v


config = load()
if sys.argv[1] == "shape":
    keys = sys.argv[2:] or list(config)
    print(json.dumps({k: shape(config[k]) for k in keys if k in config}, indent=1))
elif sys.argv[1] == "write":
    out, model, providers = sys.argv[2], sys.argv[3], sys.argv[4].split(",")
    # opencode also reads ~/.claude/skills and ~/.agents/skills, outside the isolated config:
    # every skill is denied except the ones named here (none for the plain arm).
    allowed_skills = [s for s in (sys.argv[5].split(",") if len(sys.argv) > 5 else []) if s]
    # Never kill processes by name: other people's programs run on the PC. A kill by the process
    # id the agent recorded (the kit's run-and-check.md) stays allowed.
    kills = ["*taskkill*/IM*", "*taskkill*/im*", "*Stop-Process*-Name*", "*pkill *", "*killall *", "*wmic*process*"]
    isolated = {
        "$schema": "https://opencode.ai/config.json",
        "model": model,
        "provider": {p: config["provider"][p] for p in providers},
        "autoupdate": False,
        "share": "disabled",
        "permission": {"bash": dict([("*", "allow")] + [(k, "deny") for k in kills]),
                       "skill": dict([("*", "deny")] + [(s, "allow") for s in allowed_skills]),
                       # A file outside the project (the arm's tmp folder, ~/.gradle) makes `opencode run` ask,
                       # and with no one to answer, the run sits until its timeout.
                       "external_directory": "allow"},
    }
    with open(out, "w", encoding="utf-8") as f:
        json.dump(isolated, f, indent=2)
    print("wrote", out, "with providers", providers)
