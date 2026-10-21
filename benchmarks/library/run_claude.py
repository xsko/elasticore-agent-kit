"""Runs one arm of the comparison with Claude Code (headless, `claude -p`).

usage: python run_claude.py ROOT ARM PORT MINUTES
  ARM  plain       - no plugin, the task as written
       elasticore  - the kit's Claude Code plugin loaded (--plugin-dir on a copy of it), the task
                     says to use ElastiCORE
Environment: KIT_DIR (the plugin folder; default ../../plugins/elasticore next to this script),
CLAUDE_MODEL (default sonnet), ELASTICORE_VERSION (default 3.0.261021; a -SNAPSHOT version makes
the task say to use the local Maven repository), TASK (default task.ko.md).
The user's settings, plugins, hooks and MCP servers are not loaded (--setting-sources project,local,
--strict-mcp-config); the user's ~/.claude/CLAUDE.md is, the same for both arms.
Writes ROOT/ARM/project, prompt.md, events.jsonl (stream-json), stderr.log and result.json.
Written for Windows (taskkill, netstat, PowerShell for the leftover-server check).
"""
import json
import os
import re
import shutil
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
KIT = os.environ.get("KIT_DIR") or os.path.normpath(os.path.join(HERE, "..", "..", "plugins", "elasticore"))
MODEL = os.environ.get("CLAUDE_MODEL", "sonnet")
VERSION = os.environ.get("ELASTICORE_VERSION", "3.0.261021")
TOOL_LINE = {
    "plain": "",
    "elasticore": "\nElastiCORE(YAML DSL에서 Spring Boot 코드를 생성하는 도구)로 만든다. ElastiCORE 버전은 " + VERSION
                  + (" 이고 로컬 Maven 저장소에 있다: settings.gradle 의 pluginManagement 와 build.gradle 의 repositories 에 "
                     "mavenLocal() 을 mavenCentral() 앞에 둔다.\n" if VERSION.endswith("-SNAPSHOT") else " 이다.\n"),
}

root, arm, port, minutes = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])
base = os.path.join(root, arm)
project = os.path.join(base, "project")
os.makedirs(project, exist_ok=True)
if os.listdir(project):
    sys.exit("project folder is not empty: " + project)

spec = open(os.path.join(HERE, os.environ.get("TASK", "task.ko.md")), encoding="utf-8").read()
spec = spec.replace("{TOOL_LINE}", TOOL_LINE[arm]).replace("{PORT}", port)
prompt = "아래 과제를 끝까지 수행하라. 질문하지 말고 스스로 판단해 진행하라.\n\n" + spec
open(os.path.join(base, "prompt.md"), "w", encoding="utf-8").write(prompt)

temp = os.path.join(base, "tmp")
os.makedirs(temp, exist_ok=True)
env = dict(os.environ, PWD=project, TEMP=temp, TMP=temp)
cmd = [shutil.which("claude"), "-p", "--model", MODEL, "--setting-sources", "project,local",
       "--strict-mcp-config", "--mcp-config", '{"mcpServers":{}}',
       "--permission-mode", "bypassPermissions", "--output-format", "stream-json", "--verbose"]
if arm == "elasticore":
    # A copy, so that work on the kit during the run does not change what this arm uses.
    plugin = os.path.join(base, "plugin")
    shutil.copytree(KIT, plugin, dirs_exist_ok=True)
    cmd += ["--plugin-dir", plugin]
started = time.time()
timed_out = False
with open(os.path.join(base, "events.jsonl"), "w", encoding="utf-8") as events, \
        open(os.path.join(base, "stderr.log"), "w", encoding="utf-8") as errors:
    p = subprocess.Popen(cmd, cwd=project, env=env, stdin=subprocess.PIPE, stdout=events, stderr=errors)
    p.stdin.write(prompt.encode("utf-8"))
    p.stdin.close()
    try:
        p.wait(timeout=minutes * 60)
    except subprocess.TimeoutExpired:
        timed_out = True
        subprocess.run(["taskkill", "/PID", str(p.pid), "/T", "/F"], capture_output=True)
        p.wait()
elapsed = time.time() - started

# A server left listening on the arm's port is stopped when its command line names the arm.
leftover = []
netstat = subprocess.run(["netstat", "-ano"], capture_output=True, text=True).stdout
for pid in sorted(set(re.findall(r"TCP\s+\S+:%s\s+\S+\s+LISTENING\s+(\d+)" % port, netstat))):
    line = subprocess.run(["powershell", "-NoProfile", "-Command",
                           "(Get-CimInstance Win32_Process -Filter 'ProcessId=%s').CommandLine" % pid],
                          capture_output=True, text=True).stdout.strip()
    if project.lower() in line.lower() or os.path.basename(base) in line:
        subprocess.run(["taskkill", "/PID", pid, "/T", "/F"], capture_output=True)
        leftover.append({"pid": pid, "stopped": True})
    else:
        leftover.append({"pid": pid, "stopped": False, "command": line[:200]})

result = {"arm": arm, "tool": "claude -p", "model": MODEL, "port": port, "seconds": round(elapsed),
          "timed_out": timed_out, "exit": p.returncode, "leftover_servers": leftover}
json.dump(result, open(os.path.join(base, "result.json"), "w", encoding="utf-8"), indent=2)
print(json.dumps(result))
