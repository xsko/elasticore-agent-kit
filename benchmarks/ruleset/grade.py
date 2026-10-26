"""Grades one arm of the team-rule task by building, starting and calling it - no judgement calls.

usage: python grade.py ARM_DIR PORT
  ARM_DIR  the folder run.py made (its project/ is graded on a copy, project/ itself is not touched)
  PORT     a free port for the graded server
Writes ARM_DIR/grade.json and prints one line per item: PASS / FAIL, the evidence. Score = PASS count.
The final report (task: what was checked, what was not) is read by a person - item D1 is not here.
Written for Windows (gradlew.bat, taskkill).
"""
import glob
import json
import os
import re
import shutil
import socket
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request

arm_dir, port = sys.argv[1], int(sys.argv[2])
src = os.path.join(arm_dir, "project")
work = tempfile.mkdtemp(prefix="grade-", dir=os.path.dirname(os.path.abspath(arm_dir)))
items = []


def item(key, ok, evidence):
    items.append({"item": key, "pass": bool(ok), "evidence": str(evidence)[:400]})
    print("%s  %-4s %s" % ("PASS" if ok else "FAIL", key, str(evidence)[:200]), flush=True)


def copy(name):
    dst = os.path.join(work, name)
    shutil.copytree(src, dst, ignore=shutil.ignore_patterns("build", ".gradle", "tmp", ".kotlin"))
    return dst


def gradle(project, *args):
    temp = os.path.join(work, "tmp")
    os.makedirs(temp, exist_ok=True)
    env = dict(os.environ, TEMP=temp, TMP=temp)
    p = subprocess.run([os.path.join(project, "gradlew.bat")] + list(args) + ["--no-daemon"], cwd=project,
                       env=env, capture_output=True, text=True, errors="replace", timeout=1200)
    return p.returncode, p.stdout + p.stderr


def call(method, path, body=None):
    data = None if body is None else json.dumps(body).encode("utf-8")
    req = urllib.request.Request("http://127.0.0.1:%d%s" % (port, path), data=data, method=method,
                                 headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            text = r.read().decode("utf-8", "replace")
            return r.status, text
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode("utf-8", "replace")


def js(text):
    try:
        return json.loads(text)
    except ValueError:
        return None


# --- the build ------------------------------------------------------------------------------
built = copy("built")
rc, out = gradle(built, "build")
open(os.path.join(arm_dir, "grade-build.log"), "w", encoding="utf-8").write(out)
item("B1", rc == 0, "gradlew build exit %d" % rc)
item("B2", "SKIP(user-modified" not in out, "no generated file edited by hand"
     if "SKIP(user-modified" not in out else re.findall(r".*SKIP\(user-modified.*", out)[:3])

settings = open(os.path.join(built, "settings.gradle"), encoding="utf-8").read()
modules = re.findall(r"include\s*\(?\s*['\"]:?([\w-]+)['\"]", settings)
root_build = open(os.path.join(built, "build.gradle"), encoding="utf-8").read()
item("B3", modules and re.search(r"\brules\s*=", root_build),
     "modules %s, rules in elasticore { }: %s" % (modules, bool(re.search(r"\brules\s*=", root_build))))
tests = 0
for m in modules:
    for xml in glob.glob(os.path.join(built, m, "build", "test-results", "test", "*.xml")):
        tests += int(re.search(r'tests="(\d+)"', open(xml, encoding="utf-8").read()).group(1))
item("B4", tests > 0 and rc == 0, "%d tests in the rule module(s), build exit %d" % (tests, rc))

# --- the running application ----------------------------------------------------------------
jars = [j for j in glob.glob(os.path.join(built, "build", "libs", "*.jar")) if not j.endswith("-plain.jar")]
server = None
if jars:
    java = os.path.join(os.environ["JAVA_HOME"], "bin", "java.exe") if os.environ.get("JAVA_HOME") else "java"
    log = open(os.path.join(arm_dir, "grade-server.log"), "w", encoding="utf-8")
    server = subprocess.Popen([java, "-jar", jars[0], "--server.port=%d" % port], cwd=built, stdout=log,
                              stderr=subprocess.STDOUT)
    for _ in range(120):
        try:
            socket.create_connection(("127.0.0.1", port), 1).close()
            break
        except OSError:
            time.sleep(1)
try:
    item("A0", server is not None and server.poll() is None, "server on %d from %s" % (port, jars[:1]))
    if server is not None and server.poll() is None:
        s, t = call("POST", "/api/library/member", {"name": "Kim", "email": "kim@example.com"})
        member = js(t) or {}
        item("P1", s == 200 and "email" not in member, "join: %d %s" % (s, t[:160]))
        mid = member.get("memberId")
        s, t = call("GET", "/api/library/member/%s" % mid)
        item("P2", s == 200 and "email" not in (js(t) or {"email": 1}), "read: %d %s" % (s, t[:160]))
        s, t = call("POST", "/api/library/member/search", {})
        content = (js(t) or {}).get("content") or []
        item("P3", s == 200 and content and all("email" not in c for c in content), "search: %d %s" % (s, t[:160]))
        s, t = call("POST", "/api/library/member", {"name": "Lee", "email": "kim@example.com"})
        item("P4", s == 409, "same e-mail again (stored, still unique): %d %s" % (s, t[:120]))

        book = {"isbn": "9780000000001", "title": "Dune", "author": "Frank Herbert", "pubYear": 1965, "copies": 1}
        s, t = call("POST", "/api/library/book", book)
        s1, t1 = call("DELETE", "/api/library/book/9780000000001")
        s2, t2 = call("POST", "/api/library/book/delete", ["9780000000001"])
        s3, _ = call("GET", "/api/library/book/9780000000001")
        item("N1", s == 200 and s1 in (404, 405) and s3 == 200, "create %d, DELETE /{isbn} %d, read after %d" % (s, s1, s3))
        item("N2", s2 not in (200, 204) and s3 == 200, "POST /delete %d %s" % (s2, t2[:100]))
        s, t = call("POST", "/api/library/member", {"name": "Park", "email": "park@example.com"})
        pid = (js(t) or {}).get("memberId")
        s1, _ = call("DELETE", "/api/library/member/%s" % pid)
        s2, _ = call("GET", "/api/library/member/%s" % pid)
        item("N3", s1 in (200, 204) and s2 == 404, "member delete still there: DELETE %d, read after %d" % (s1, s2))

        s1, t1 = call("POST", "/api/library/book/search", {"title": "D"})
        item("L1", s1 == 400 and "title" in t1, "title 'D': %d %s" % (s1, t1[:200]))
        s2, t2 = call("POST", "/api/library/book/search", {"title": "Du"})
        item("L2", s2 == 200 and (js(t2) or {}).get("totalElements") == 1, "title 'Du': %d %s" % (s2, t2[:120]))
        s3, t3 = call("POST", "/api/library/book/search", {})
        s4, t4 = call("POST", "/api/library/book/search", {"author": "F"})
        item("L3", s3 == 200 and s4 == 400 and "author" in t4, "no term %d; author 'F' %d %s" % (s3, s4, t4[:120]))

        s, t = call("POST", "/api/library/loan", {"memberId": mid, "bookIsbn": "9780000000001"})
        loan = (js(t) or {}).get("loanId")
        s1, _ = call("POST", "/api/library/loan", {"memberId": mid, "bookIsbn": "9780000000001"})
        s2, _ = call("POST", "/api/library/loan/%s/return" % loan)
        item("R1", s == 200 and s1 == 409 and s2 == 200, "lend %d, second lend %d, return %d" % (s, s1, s2))
finally:
    if server is not None:
        subprocess.run(["taskkill", "/PID", str(server.pid), "/T", "/F"], capture_output=True)
        server.wait()

# --- the model check --------------------------------------------------------------------------
check = copy("check")
model = glob.glob(os.path.join(check, "src", "main", "resources", "blueprint", "library", "model", "*.yml"))
changed = None
for path in model:
    text = open(path, encoding="utf-8").read()
    m = re.search(r"^  (\w+):\s*\n\s+meta:[^\n]*@expose\(20\)", text, re.M)
    if m:
        open(path, "w", encoding="utf-8").write(text.replace("@expose(20)", "@expose(80)", 1))
        changed = m.group(1)
        break
rc, out = gradle(check, "compileJava")
open(os.path.join(arm_dir, "grade-check.log"), "w", encoding="utf-8").write(out)
said = [l.strip() for l in out.splitlines() if changed and changed in l and re.search(r"50|80|expose", l)]
item("M1", changed and rc != 0 and said, "%s @expose(80): exit %d, %s" % (changed, rc, said[:2]))

score = sum(1 for i in items if i["pass"])
json.dump({"score": score, "of": len(items), "items": items}, open(os.path.join(arm_dir, "grade.json"), "w",
                                                                    encoding="utf-8"), indent=2, ensure_ascii=False)
print("score %d of %d" % (score, len(items)))
