"""Runs a change request on a copy of a finished pet store arm, with Claude Code and the kit's plugin.

usage: python run_change.py ROOT FROM_ARM NEW_ARM PORT MINUTES
  copies ROOT/FROM_ARM/project (without build, .gradle, tmp) to ROOT/NEW_ARM/project, commits it in a
  fresh git repository there (so the change can be read as a diff), and runs claude -p with
  TASK (default task-2.ko.md) in it.
Environment: KIT_DIR, CLAUDE_MODEL (default sonnet), ELASTICORE_VERSION (default 3.0.261021).
Writes ROOT/NEW_ARM/project, plugin, prompt.md, events.jsonl, stderr.log, result.json.
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

root, src_arm, arm, port, minutes = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], int(sys.argv[5])
src = os.path.join(root, src_arm, "project")
base = os.path.join(root, arm)
project = os.path.join(base, "project")
if os.path.exists(project):
    sys.exit("project folder exists: " + project)
os.makedirs(base)
shutil.copytree(src, project, ignore=shutil.ignore_patterns("build", ".gradle", "tmp", ".kotlin", "node_modules"))
git = ["git", "-c", "user.name=exp", "-c", "user.email=exp@example.invalid", "-c", "core.autocrlf=false"]
subprocess.run(git + ["init", "-q"], cwd=project, check=True)
subprocess.run(git + ["add", "-A"], cwd=project, check=True)
subprocess.run(git + ["commit", "-q", "-m", "phase 1 as delivered"], cwd=project, check=True)

where = (" 이고 로컬 Maven 저장소에 있다(이미 build 설정에 mavenLocal() 이 있다)." if "SNAPSHOT" in VERSION else " 이다.")
tool_line = "\nElastiCORE(YAML DSL에서 Spring Boot 코드를 생성하는 도구)로 만든 프로젝트다. ElastiCORE 버전은 %s%s\n" % (VERSION, where)
spec = open(os.path.join(HERE, os.environ.get("TASK", "task-2.ko.md")), encoding="utf-8").read()
spec = spec.replace("{TOOL_LINE}", tool_line).replace("{PORT}", port)
prompt = "아래 변경 요청을 끝까지 수행하라. 질문하지 말고 스스로 판단해 진행하라.\n\n" + spec
open(os.path.join(base, "prompt.md"), "w", encoding="utf-8").write(prompt)

temp = os.path.join(base, "tmp")
os.makedirs(temp, exist_ok=True)
env = dict(os.environ, PWD=project, TEMP=temp, TMP=temp)
plugin = os.path.join(base, "plugin")
shutil.copytree(KIT, plugin, dirs_exist_ok=True)
cmd = [shutil.which("claude"), "-p", "--model", MODEL, "--setting-sources", "project,local",
       "--strict-mcp-config", "--mcp-config", '{"mcpServers":{}}',
       "--permission-mode", "bypassPermissions", "--output-format", "stream-json", "--verbose",
       "--plugin-dir", plugin]
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

result = {"arm": arm, "from": src_arm, "model": MODEL, "version": VERSION, "port": port,
          "seconds": round(elapsed), "timed_out": timed_out, "exit": p.returncode, "leftover_servers": leftover}
json.dump(result, open(os.path.join(base, "result.json"), "w", encoding="utf-8"), indent=2)
print(json.dumps(result))
