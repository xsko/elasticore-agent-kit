# Running and checking the application from an agent's shell

`./gradlew bootRun` never returns: in a tool's shell it holds the call until the tool's timeout, and
in the background it keeps the build open. Build a jar, start it in the background with its process
id written to a file, call it, and stop that process - only that one. Each tool call may be a new
shell, so the process id lives in `build/app.pid`, not in a variable.

## Build

Stop a server you started before building again - on Windows the running jar is locked and
`bootJar` cannot replace it.

```bash
./gradlew bootJar          # generates, compiles and packages; read its output as for compileJava
```

The jar is the file in `build/libs/` that does not end in `-plain.jar` - `<project>.jar` when
`build.gradle` sets no `version`. In the README write the name you see there, not a guessed
`<project>-0.0.1-SNAPSHOT.jar`.

On Windows, run `./gradlew.bat` - from Git Bash too, where it works as well. Not `./gradlew`,
`sh ./gradlew` or `bash ./gradlew`: when the Unix wrapper script starts a Gradle daemon, the daemon
inherits the tool's output pipe, and the call does not return until that daemon exits. Claude Code
waits for the call's timeout, moves it to the background and stops it ten minutes later - a build
that was done in twelve seconds cost ten minutes that way. `./gradlew.bat` does not have this, in
bash or in PowerShell; where only the script can be used, add `--no-daemon`. (`./gradlew` in Git
Bash may also fail with `ClassNotFoundException: GradleWrapperMain` - the same answer,
`./gradlew.bat`; the wrapper is fine, do not regenerate it.)

In opencode on Windows, when its shell tool runs PowerShell, a Gradle run that starts the daemon
does not return either, with `gradlew.bat` too: build with `--no-daemon` there
(`./gradlew.bat --no-daemon compileJava`), or start opencode with
`GRADLE_OPTS=-Dorg.gradle.daemon=false` in its environment.

In Codex (`codex exec`) on Windows the answer arrives, but the `codex` process does not end while
a Gradle daemon that one of its shell calls started is alive - the daemon holds that call's pipe
(seen with `gradle wrapper`: still running after five minutes and after twenty; with `--no-daemon`
the process ended the moment the answer was written). Bootstrap and build with the daemon off
there - `gradle --no-daemon wrapper --gradle-version 8.14.3`, `./gradlew.bat --no-daemon build` -
or start Codex with `GRADLE_OPTS=-Dorg.gradle.daemon=false` in its environment.

## Start, wait, call, stop - bash (macOS, Linux, Git Bash on Windows)

```bash
[ -f build/app.pid ] && kill "$(cat build/app.pid)" 2>/dev/null; sleep 1   # the server you started before, if any
JAR=$(ls build/libs/*.jar | grep -v -- -plain.jar | head -1)
mkdir -p build/tmp
java -Djava.io.tmpdir="$PWD/build/tmp" -jar "$JAR" --server.port=PORT < /dev/null > build/app.log 2>&1 &
echo $! > build/app.pid
for i in $(seq 1 90); do
  kill -0 "$(cat build/app.pid)" 2>/dev/null || { echo "the server stopped:"; tail -30 build/app.log; break; }
  curl -s -o /dev/null localhost:PORT/v3/api-docs && break; sleep 1
done
curl -s localhost:PORT/v3/api-docs > build/api-docs.json   # the generated API: every path and field

curl -s -X POST localhost:PORT/api/DOMAIN/ENTITY/search -H 'Content-Type: application/json' -d '{}'

kill "$(cat build/app.pid)" && rm build/app.pid             # stop the server you started
```

If it does not answer within the wait, read `build/app.log`. "Port PORT was already in use" means
another program has the port: use another port - do not stop that program.

Start the server in one tool call and call it in the next ones. A script of your own that builds,
starts the server and runs its requests in one call held a Claude Code call for close to seven
minutes on Windows (every `curl` in it answered `000`), while the same requests in a later call
answered at once. Keep scratch files - request bodies, cookie jars, logs - under `build/`, not in
`/tmp`, which in Git Bash is the user's temporary folder outside the project.

## The same in PowerShell

```powershell
if (Test-Path build\app.pid) { Stop-Process -Id (Get-Content build\app.pid) -ErrorAction SilentlyContinue; Remove-Item build\app.pid }
$jar = Get-ChildItem build\libs\*.jar | Where-Object { $_.Name -notlike '*-plain.jar' } | Select-Object -First 1
New-Item -ItemType Directory -Force build\tmp | Out-Null
$app = Start-Process java -PassThru -WindowStyle Hidden `
       -ArgumentList "`"-Djava.io.tmpdir=$PWD\build\tmp`"", '-jar', "`"$($jar.FullName)`"", '--server.port=PORT', "`"--logging.file.name=$PWD\build\app.log`""
$app.Id | Set-Content build\app.pid
for ($i = 0; $i -lt 90; $i++) {
  if (-not (Get-Process -Id (Get-Content build\app.pid) -ErrorAction SilentlyContinue)) { "the server stopped:"; Get-Content build\app.log -Tail 30 -ErrorAction SilentlyContinue; break }
  try { Invoke-WebRequest -UseBasicParsing -TimeoutSec 2 http://localhost:PORT/v3/api-docs | Out-Null; break } catch { Start-Sleep 1 }
}
Invoke-RestMethod -Method Post -ContentType 'application/json' -Body '{}' http://localhost:PORT/api/DOMAIN/ENTITY/search
Stop-Process -Id (Get-Content build\app.pid); Remove-Item build\app.pid   # stop the server you started
```

The server writes its own log to `build\app.log` (`--logging.file.name`). Do not add
`-RedirectStandardOutput` or `-RedirectStandardError` to `Start-Process`: the server then holds the
shell's output pipe, and in opencode the tool call does not return until the server exits.

## Never

- Stop processes by name (`taskkill /IM java.exe`, `pkill java`, `Stop-Process -Name java`): other
  programs on the machine run Java too.
- Leave the server running when you finish, or start a second copy on another port to get around
  the first - stop the first by its process id.

## What to check, in this order

1. The build output has no `[elcore3] DSL validation warnings:` and no `* LOAD ERROR:` line.
2. The server answers `/v3/api-docs`.
3. Every operation the task names answers as the task says - including the refusals (400 for
   invalid input, 404 for an unknown id).
