"""Runs the team-rule change request on a copy of a finished library project, with Claude Code or opencode.

usage: python run.py TOOL ROOT BASE ARM PORT MINUTES
  TOOL     claude | opencode
  BASE     a library project built from references/recipe-library.md (the contract test's `library`
           project will do), copied without build output to ROOT/ARM/project
  ARM      a name for this run
Environment: ELASTICORE_VERSION (required) - written into the copy's build files, which must already
take mavenLocal() for a -SNAPSHOT; KIT_DIR (the plugin folder, default ../../plugins/elasticore next
to this script); CLAUDE_MODEL (default sonnet); OPENCODE_MODEL and OPENCODE_PROVIDER for opencode
(see ../library/run_opencode.py).
Before the agent starts, the copy is generated once with that version - so the guides and their index
in blueprint/ are the version's, not the base project's - and committed in a fresh git repository, so
the change reads as a diff. Writes ROOT/ARM/{project, prompt.md, events.jsonl, stderr.log, result.json}
and, per tool, plugin/ (Claude Code) or config/ and data/ (opencode). Written for Windows.
"""
import glob
import json
import os
import re
import shutil
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
KIT = os.environ.get("KIT_DIR") or os.path.normpath(os.path.join(HERE, "..", "..", "plugins", "elasticore"))
VERSION = os.environ["ELASTICORE_VERSION"]
VERSION_IN_BUILD = re.compile(r"3\.0\.\d{6}(?:\.\d+)?(?:-[0-9A-Za-z.]+)?")

tool, root, src, arm, port, minutes = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5], int(sys.argv[6])
if tool not in ("claude", "opencode"):
    sys.exit("TOOL is claude or opencode")
base = os.path.join(root, arm)
project = os.path.join(base, "project")
if os.path.exists(base):
    sys.exit("arm folder exists: " + base)
os.makedirs(base)
shutil.copytree(src, project, ignore=shutil.ignore_patterns("build", ".gradle", "tmp", ".kotlin", ".git", "*.log"))

for name in ("settings.gradle", "build.gradle"):
    path = os.path.join(project, name)
    text = open(path, encoding="utf-8").read()
    if not VERSION_IN_BUILD.search(text) and name == "build.gradle":
        sys.exit("no ElastiCORE version in " + path)
    open(path, "w", encoding="utf-8", newline="").write(VERSION_IN_BUILD.sub(VERSION, text))
for old in glob.glob(os.path.join(project, "src", "main", "resources", "blueprint", "elasticore-*.md")):
    os.remove(old)

temp = os.path.join(base, "tmp")
os.makedirs(temp, exist_ok=True)
env = dict(os.environ, PWD=project, TEMP=temp, TMP=temp)
gradlew = os.path.join(project, "gradlew.bat")
prep = subprocess.run([gradlew, "compileJava", "--no-daemon", "-q"], cwd=project, env=env,
                      capture_output=True, text=True, errors="replace")
open(os.path.join(base, "prepare.log"), "w", encoding="utf-8").write(prep.stdout + prep.stderr)
if prep.returncode != 0:
    sys.exit("the copy does not generate and compile with %s - see prepare.log" % VERSION)
shutil.rmtree(os.path.join(project, "build"), ignore_errors=True)

git = ["git", "-c", "user.name=exp", "-c", "user.email=exp@example.invalid", "-c", "core.autocrlf=false"]
open(os.path.join(project, ".gitignore"), "a", encoding="utf-8").write("\nbuild/\n.gradle/\n")
subprocess.run(git + ["init", "-q"], cwd=project, check=True)
subprocess.run(git + ["add", "-A"], cwd=project, check=True)
subprocess.run(git + ["commit", "-q", "-m", "the library as delivered"], cwd=project, check=True)

where = " 이고, 로컬 Maven 저장소에 있다(build 설정에 이미 mavenLocal() 이 있다)." if VERSION.endswith("-SNAPSHOT") else " 이다."
tool_line = "\nElastiCORE(YAML DSL에서 Spring Boot 코드를 생성하는 도구)로 만든 프로젝트다. ElastiCORE 버전은 %s%s" % (VERSION, where)
spec = open(os.path.join(HERE, os.environ.get("TASK", "task.ko.md")), encoding="utf-8").read()
spec = spec.replace("{TOOL_LINE}", tool_line).replace("{PORT}", port)
prompt = "아래 변경 요청을 끝까지 수행하라. 질문하지 말고 스스로 판단해 진행하라.\n\n" + spec
open(os.path.join(base, "prompt.md"), "w", encoding="utf-8").write(prompt)

if tool == "claude":
    model = os.environ.get("CLAUDE_MODEL", "sonnet")
    plugin = os.path.join(base, "plugin")
    shutil.copytree(KIT, plugin)
    cmd = [shutil.which("claude"), "-p", "--model", model, "--setting-sources", "project,local",
           "--strict-mcp-config", "--mcp-config", '{"mcpServers":{}}',
           "--permission-mode", "bypassPermissions", "--output-format", "stream-json", "--verbose",
           "--plugin-dir", plugin]
    # Never kill processes by name: other people's programs run on the PC (by pid is the arm's own).
    kills = ["taskkill /IM", "taskkill //IM", "taskkill /F /IM", "taskkill //F //IM", "taskkill /im",
             "Stop-Process -Name", "Get-Process java | Stop-Process", "pkill", "killall", "wmic process"]
    cmd += ["--disallowedTools"] + ["Bash(%s:*)" % k for k in kills] + ["PowerShell(%s:*)" % k for k in kills]
    stdin_text = prompt
else:
    model = os.environ["OPENCODE_MODEL"]
    provider = os.environ.get("OPENCODE_PROVIDER") or model.split("/")[0]
    config = os.path.join(base, "config", "opencode")
    data = os.path.join(base, "data")
    os.makedirs(config)
    os.makedirs(data)
    subprocess.run([sys.executable, os.path.join(HERE, "..", "library", "opencode_config.py"), "write",
                    os.path.join(config, "opencode.json"), model, provider, "elasticore"], check=True)
    shutil.copytree(os.path.join(KIT, "skills", "elasticore"), os.path.join(config, "skills", "elasticore"))
    os.makedirs(os.path.join(config, "plugins"))
    shutil.copy(os.path.join(KIT, "..", "..", "opencode", "plugins", "elasticore.js"), os.path.join(config, "plugins"))
    os.makedirs(os.path.join(config, "elasticore-kit"))
    shutil.copy(os.path.join(KIT, "hooks", "elasticore-hook.sh"), os.path.join(config, "elasticore-kit"))
    env.update(XDG_CONFIG_HOME=os.path.join(base, "config"), XDG_DATA_HOME=data,
               OPENCODE_DISABLE_AUTOUPDATE="1", OPENCODE_DISABLE_CLAUDE_CODE_SKILLS="1",
               GRADLE_OPTS=(os.environ.get("GRADLE_OPTS", "") + " -Dorg.gradle.daemon=false").strip())
    exe = os.environ.get("OPENCODE_EXE") or os.path.join(os.environ["APPDATA"], "npm", "node_modules",
                                                         "opencode-ai", "bin", "opencode.exe")
    cmd = [exe, "run", "--auto", "--dir", project, "-m", model, "--format", "json", prompt]
    stdin_text = None

started = time.time()
timed_out = False
with open(os.path.join(base, "events.jsonl"), "w", encoding="utf-8") as events, \
        open(os.path.join(base, "stderr.log"), "w", encoding="utf-8") as errors:
    p = subprocess.Popen(cmd, cwd=project, env=env, stdout=events, stderr=errors,
                         stdin=subprocess.PIPE if stdin_text else subprocess.DEVNULL)
    if stdin_text:
        p.stdin.write(stdin_text.encode("utf-8"))
        p.stdin.close()
    try:
        p.wait(timeout=minutes * 60)
    except subprocess.TimeoutExpired:
        timed_out = True
        subprocess.run(["taskkill", "/PID", str(p.pid), "/T", "/F"], capture_output=True)
        p.wait()
elapsed = time.time() - started

# A server left on the arm's port: stopped only when it is a java started after this arm began.
leftover = []
netstat = subprocess.run(["netstat", "-ano"], capture_output=True, text=True, errors="replace").stdout
for pid in sorted(set(re.findall(r"TCP\s+\S+:%s\s+\S+\s+LISTENING\s+(\d+)" % port, netstat))):
    info = subprocess.run(["powershell", "-NoProfile", "-Command",
                           "$p = Get-CimInstance Win32_Process -Filter 'ProcessId=%s'; "
                           "'{0}|{1}|{2}' -f $p.Name, ([DateTimeOffset]$p.CreationDate).ToUnixTimeSeconds(), $p.CommandLine" % pid],
                          capture_output=True, text=True, errors="replace").stdout.strip()
    name, created, line = (info.split("|", 2) + ["", "", ""])[:3]
    ours = name.lower() == "java.exe" and created.isdigit() and int(created) >= int(started)
    if ours:
        subprocess.run(["taskkill", "/PID", pid, "/T", "/F"], capture_output=True)
    leftover.append({"pid": pid, "stopped": ours, "command": line[:200]})

result = {"arm": arm, "tool": tool, "model": model, "version": VERSION, "kit": KIT, "port": port,
          "seconds": round(elapsed), "timed_out": timed_out, "exit": p.returncode, "leftover_servers": leftover}
json.dump(result, open(os.path.join(base, "result.json"), "w", encoding="utf-8"), indent=2)
print(json.dumps(result))
