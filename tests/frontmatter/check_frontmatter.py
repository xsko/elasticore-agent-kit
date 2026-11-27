"""Parses the front matter of every skill, agent and command the kit ships with a strict YAML
parser (PyYAML's safe_load). A value such as `description: ... an //ecd: line ...` is not valid
YAML - the second `: ` starts a mapping - and a loader that parses strictly drops the whole skill
without a word (pi did). Claude Code is lenient, so only a test catches it.

usage: python tests/frontmatter/check_frontmatter.py      needs PyYAML (pip install pyyaml)
"""
import glob
import os
import sys

import yaml

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
FILES = sorted(set(
    glob.glob(os.path.join(ROOT, "plugins", "*", "skills", "*", "SKILL.md"))
    + glob.glob(os.path.join(ROOT, "plugins", "*", "agents", "*.md"))
    + glob.glob(os.path.join(ROOT, "opencode", "agents", "*.md"))
    + glob.glob(os.path.join(ROOT, "opencode", "commands", "*.md"))))

failed = 0
for path in FILES:
    rel = os.path.relpath(path, ROOT).replace(os.sep, "/")
    with open(path, encoding="utf-8") as f:
        text = f.read().replace("\r\n", "\n")
    problem = None
    if not text.startswith("---\n"):
        problem = "no front matter"
    else:
        end = text.find("\n---\n", 4)
        if end < 0:
            problem = "front matter not closed"
        else:
            try:
                data = yaml.safe_load(text[4:end])
            except yaml.YAMLError as e:
                problem = "not valid YAML: " + str(e).replace("\n", " ")
            else:
                if not isinstance(data, dict):
                    problem = "front matter is not a mapping"
                elif not isinstance(data.get("description"), str) or not data["description"].strip():
                    problem = "no description"
                elif rel.endswith("/SKILL.md") and data.get("name") != os.path.basename(os.path.dirname(path)):
                    problem = "name %r is not the folder's name" % data.get("name")
    if problem:
        failed += 1
        print("FAIL %s: %s" % (rel, problem))
        if os.environ.get("GITHUB_ACTIONS") == "true":
            print("::error file=%s,title=front matter::%s" % (rel, problem))

print("%d files, %d failed" % (len(FILES), failed))
sys.exit(1 if failed or not FILES else 0)
