# Running and checking the application from an agent's shell

`./gradlew bootRun` never returns: in a tool's shell it holds the call until the tool's timeout, and
in the background it keeps the build open. Build a jar, start it in the background with its process
id written down, call it, and stop that process - only that one.

## Build

```bash
./gradlew bootJar          # generates, compiles and packages; read its output as for compileJava
```

The jar is the file in `build/libs/` that does not end in `-plain.jar`.

## Start, wait, call, stop - bash (macOS, Linux, Git Bash on Windows)

```bash
JAR=$(ls build/libs/*.jar | grep -v -- -plain.jar | head -1)
mkdir -p build/tmp
java -Djava.io.tmpdir="$PWD/build/tmp" -jar "$JAR" --server.port=PORT > build/app.log 2>&1 &
echo $! > build/app.pid
for i in $(seq 1 90); do curl -s -o /dev/null localhost:PORT/v3/api-docs && break; sleep 1; done
curl -s localhost:PORT/v3/api-docs | head -c 400      # the generated API, every path and field

curl -s -X POST localhost:PORT/api/DOMAIN/ENTITY/search -H 'Content-Type: application/json' -d '{}'

kill "$(cat build/app.pid)"                           # stop the server you started
```

If it does not answer within the wait, read `build/app.log` - "Port PORT was already in use" means
another program has the port: pick another one, do not stop that program.

## The same in PowerShell

```powershell
$jar = Get-ChildItem build\libs\*.jar | Where-Object { $_.Name -notlike '*-plain.jar' } | Select-Object -First 1
New-Item -ItemType Directory -Force build\tmp | Out-Null
$app = Start-Process java -ArgumentList "-Djava.io.tmpdir=$PWD\build\tmp", '-jar', $jar.FullName, '--server.port=PORT' `
       -RedirectStandardOutput build\app.log -RedirectStandardError build\app.err -PassThru -WindowStyle Hidden
for ($i = 0; $i -lt 90; $i++) { try { Invoke-WebRequest -UseBasicParsing http://localhost:PORT/v3/api-docs | Out-Null; break } catch { Start-Sleep 1 } }
Invoke-RestMethod -Method Post -ContentType 'application/json' -Body '{}' http://localhost:PORT/api/DOMAIN/ENTITY/search
Stop-Process -Id $app.Id                               # stop the server you started
```

## Never

- Stop processes by name (`taskkill /IM java.exe`, `pkill java`, `Stop-Process -Name java`): other
  programs on the machine run Java too.
- Leave the server running when you finish, or start a second copy on another port to get around
  the first.

## What to check, in this order

1. The build output has no `[elcore3] DSL validation warnings:` and no `* LOAD ERROR:` line.
2. The server answers `/v3/api-docs`.
3. Every operation the task names answers as the task says - including the refusals (400 for
   invalid input, 404 for an unknown id).
