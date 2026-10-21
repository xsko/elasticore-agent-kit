"""Runs one arm of the comparison with opencode (`opencode run --auto`) in an isolated setup.

usage: python run_opencode.py ROOT ARM PORT MINUTES
  ARM  plain       - no kit, the task as written
       elasticore  - the kit's skill and opencode plugin installed in the isolated config, the task
                     says to use ElastiCORE
Environment: OPENCODE_MODEL (required, e.g. myprovider/some-model), OPENCODE_PROVIDER (the provider
key of that model in the user's ~/.config/opencode/opencode.json; its block is copied into the
isolated config by opencode_config.py - values are never printed), KIT_DIR (default
../../plugins/elasticore next to this script), ELASTICORE_VERSION (default 3.0.261021), TASK
(default task.ko.md).
The isolated config (XDG_CONFIG_HOME/XDG_DATA_HOME under the arm) holds the model, that provider,
and permissions that refuse process kills by name and allow files outside the project; none of the
user's plugins, rules or skills. GRADLE_OPTS gets -Dorg.gradle.daemon=false for both arms: on
Windows a Gradle run that starts the daemon never returns to opencode's shell tool.
Writes ROOT/ARM/{project,config,data}, prompt.md, events.jsonl (opencode's JSON events), stderr.log
and result.json. Written for Windows (the opencode.exe path, taskkill, netstat, PowerShell).
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
MODEL = os.environ["OPENCODE_MODEL"]
PROVIDER = os.environ.get("OPENCODE_PROVIDER") or MODEL.split("/")[0]
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
config = os.path.join(base, "config", "opencode")
data = os.path.join(base, "data")
for d in (project, config, data):
    os.makedirs(d, exist_ok=True)
if os.listdir(project):
    sys.exit("project folder is not empty: " + project)

subprocess.run([sys.executable, os.path.join(HERE, "opencode_config.py"), "write",
                os.path.join(config, "opencode.json"), MODEL, PROVIDER,
                "elasticore" if arm == "elasticore" else ""], check=True)
if arm == "elasticore":
    shutil.copytree(os.path.join(KIT, "skills", "elasticore"), os.path.join(config, "skills", "elasticore"), dirs_exist_ok=True)
    os.makedirs(os.path.join(config, "plugins"), exist_ok=True)
    shutil.copy(os.path.join(KIT, "..", "..", "opencode", "plugins", "elasticore.js"), os.path.join(config, "plugins", "elasticore.js"))
    os.makedirs(os.path.join(config, "elasticore-kit"), exist_ok=True)
    shutil.copy(os.path.join(KIT, "hooks", "elasticore-hook.sh"), os.path.join(config, "elasticore-kit", "elasticore-hook.sh"))

spec = open(os.path.join(HERE, os.environ.get("TASK", "task.ko.md")), encoding="utf-8").read()
spec = spec.replace("{TOOL_LINE}", TOOL_LINE[arm]).replace("{PORT}", port)
prompt = "아래 과제를 끝까지 수행하라. 질문하지 말고 스스로 판단해 진행하라.\n\n" + spec
open(os.path.join(base, "prompt.md"), "w", encoding="utf-8").write(prompt)

temp = os.path.join(base, "tmp")
os.makedirs(temp, exist_ok=True)
env = dict(os.environ, XDG_CONFIG_HOME=os.path.join(base, "config"), XDG_DATA_HOME=data, PWD=project,
           TEMP=temp, TMP=temp, OPENCODE_DISABLE_AUTOUPDATE="1",
           OPENCODE_DISABLE_CLAUDE_CODE_SKILLS="1",
           GRADLE_OPTS=(os.environ.get("GRADLE_OPTS", "") + " -Dorg.gradle.daemon=false").strip())
# The executable itself: through the npm .cmd shim, cmd.exe cuts the prompt at its first line break.
opencode = os.environ.get("OPENCODE_EXE") or os.path.join(os.environ["APPDATA"], "npm", "node_modules", "opencode-ai", "bin", "opencode.exe")
started = time.time()
timed_out = False
with open(os.path.join(base, "events.jsonl"), "w", encoding="utf-8") as events, \
        open(os.path.join(base, "stderr.log"), "w", encoding="utf-8") as errors:
    p = subprocess.Popen([opencode, "run", "--auto", "--dir", project, "-m", MODEL, "--format", "json", prompt],
                         cwd=project, env=env, stdin=subprocess.DEVNULL, stdout=events, stderr=errors)
    try:
        p.wait(timeout=minutes * 60)
    except subprocess.TimeoutExpired:
        timed_out = True
        subprocess.run(["taskkill", "/PID", str(p.pid), "/T", "/F"], capture_output=True)
        p.wait()
elapsed = time.time() - started

# A server the agent left running on the arm's port: stopped when it is a java started after this
# arm began - the port is this arm's alone.
leftover = []
netstat = subprocess.run(["netstat", "-ano"], capture_output=True, text=True).stdout
for pid in sorted(set(re.findall(r"TCP\s+\S+:%s\s+\S+\s+LISTENING\s+(\d+)" % port, netstat))):
    info = subprocess.run(["powershell", "-NoProfile", "-Command",
                           "$p = Get-CimInstance Win32_Process -Filter 'ProcessId=%s'; "
                           "'{0}|{1}|{2}' -f $p.Name, ([DateTimeOffset]$p.CreationDate).ToUnixTimeSeconds(), $p.CommandLine" % pid],
                          capture_output=True, text=True).stdout.strip()
    name, created, line = (info.split("|", 2) + ["", "", ""])[:3]
    ours = name.lower() == "java.exe" and created.isdigit() and int(created) >= int(started)
    if ours:
        subprocess.run(["taskkill", "/PID", pid, "/T", "/F"], capture_output=True)
    leftover.append({"pid": pid, "stopped": ours, "command": line[:200]})

result = {"arm": arm, "tool": "opencode run --auto", "model": MODEL, "port": port, "seconds": round(elapsed),
          "timed_out": timed_out, "exit": p.returncode, "leftover_servers": leftover}
json.dump(result, open(os.path.join(base, "result.json"), "w", encoding="utf-8"), indent=2)
print(json.dumps(result))
