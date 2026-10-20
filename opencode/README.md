# ElastiCORE agent kit for opencode

The kit's skill, hooks, agents and commands for [opencode](https://opencode.ai). The skill and the
hook script are the ones the Claude Code plugin uses; a small opencode plugin,
[`plugins/elasticore.js`](plugins/elasticore.js), runs the hook script on opencode's tool calls and
hands its answers back to opencode.

Checked with opencode 1.18.31.

## Install

From a checkout of this repository, for the current user:

```bash
bash opencode/install.sh                                       # macOS, Linux, Git Bash
powershell -ExecutionPolicy Bypass -File opencode\install.ps1  # Windows PowerShell
```

They copy into `~/.config/opencode/` (`$XDG_CONFIG_HOME/opencode/` when that is set; on Windows
`%USERPROFILE%\.config\opencode\`). With `--project` (`-Project` in PowerShell) they copy into
`./.opencode/` of the current directory instead, for that project only. Each prints the files it
copied. Run it again after `git pull` to update: it overwrites its own files and deletes nothing, so
a file the kit no longer has stays behind until you delete it.

To copy by hand:

| From this repository | To `~/.config/opencode/` or `.opencode/` |
|---|---|
| `opencode/plugins/elasticore.js` | `plugins/elasticore.js` |
| `plugins/elasticore/hooks/elasticore-hook.sh` | `elasticore-kit/elasticore-hook.sh` |
| `plugins/elasticore/skills/elasticore/` (the whole folder) | `skills/elasticore/` |
| `opencode/agents/*.md` | `agents/` |
| `opencode/commands/*.md` | `commands/` |

The plugin finds the hook script at `../elasticore-kit/elasticore-hook.sh` from where it lies;
`ELASTICORE_KIT_HOOK` names another one. Start a new opencode session after installing.

The hook script runs in bash. On Windows the plugin uses Git Bash from `Program Files\Git`,
`Program Files (x86)\Git` or `%LOCALAPPDATA%\Programs\Git`, and otherwise the `bash` on the PATH -
which may be WSL's, which cannot run it. Without a bash that works, the refusals and notes are
off; opencode itself goes on working.

## What you get

| Part | What it does |
|---|---|
| Skill `elasticore` | The same skill as in Claude Code: which generator the build runs, whose a file is, where a change belongs, the loop, what to ask first. |
| Plugin `elasticore.js` | Refuses an edit to a generated file and a Gradle run with `-Pforce`; after a DSL edit or a build, adds a note to the tool's output; when the session goes idle with a DSL change no build has compiled, sends it back once. |
| Agent `elasticore-modeler` | Turns a requirement into a DSL change that generates and compiles, and reports it in business terms. Call it with `@elasticore-modeler`. |
| Agent `elasticore-reviewer` | Reviews a change; it cannot edit files. |
| `/elasticore-generate [task]` | Regenerates and compiles (default `compileJava`), then explains every warning, skipped file and error. |
| `/elasticore-change-report [range]` | What a DSL change means for the business and what needs a decision. |
| `/elasticore-review [range] [full]` | Runs `elasticore-reviewer`; with `full` it also builds, which regenerates files. |

## What works and what does not

Seen in a live `opencode run` with the kit installed:

- the skill is found (`opencode debug skill` lists it with where it was found);
- an `edit` or `write` of a file whose first line is `//ecd:` fails with the reason and where the
  change belongs, also when the model passes a path relative to the project;
- an edit of the model under `src/main/resources/blueprint/<domain>/` comes back with the note to
  run `./gradlew compileJava` and fix the warnings;
- `./gradlew ... -Pforce` fails with the reason.

Covered by [`tests/opencode/test-adapter.mjs`](../tests/opencode/test-adapter.mjs) with the tool
input opencode sends, but not seen live: the notes after a Gradle build (DSL validation warnings, a
YAML file that could not be read, hand-edited generated files), the whole output opencode saves when
it cuts a long one, and `apply_patch`, the edit tool opencode gives some models instead of `edit`.

On Windows, two things stop a session that have nothing to do with the kit, seen in the same runs:

- When opencode's shell tool runs PowerShell (it does when opencode is started from PowerShell,
  cmd or Windows Terminal; from Git Bash it runs bash), a Gradle run that starts the Gradle daemon
  never returns - the daemon keeps the tool's output pipe open, and the session sits until the
  daemon is stopped. Start opencode with `GRADLE_OPTS=-Dorg.gradle.daemon=false` in its
  environment, or build with `./gradlew --no-daemon ...`; `run-and-check.md` tells the agent so.
  The same holds for a server started with `Start-Process -RedirectStandardOutput`, which is why
  the PowerShell start in `run-and-check.md` lets the server write its own log instead.
- `opencode run` asks before a tool touches a file outside the project (`$env:TEMP`, `~/.gradle`),
  and with nobody to answer, the run waits forever. For unattended runs add
  `"external_directory": "allow"` to `permission` in `opencode.json`; in the TUI you answer the
  question.

Does not work everywhere: the reminder when the session goes idle. The plugin sends it as a new
message to the session; `opencode run` has finished by then and does not go on. In the TUI or
`opencode serve` the session should take it up - that has not been checked.

As in Claude Code, a change made another way - a script run through bash - is not stopped. To let
the agent edit generated files or use `-Pforce` anyway, start opencode with
`ELASTICORE_ALLOW_GENERATED_EDITS=1` or `ELASTICORE_ALLOW_FORCE=1` in its environment.

The plugin keeps what a session has done in `elasticore-agent-kit-opencode-<user>` in the temp
directory.

## Recommended opencode.json

```json
{
  "$schema": "https://opencode.ai/config.json",
  "permission": {
    "skill": { "*": "deny", "elasticore": "allow" },
    "bash": {
      "*": "allow",
      "*taskkill*/IM*": "deny",
      "*taskkill*/im*": "deny",
      "*Stop-Process*-Name*": "deny",
      "*pkill *": "deny",
      "*killall *": "deny"
    }
  }
}
```

- **`skill`** keeps other skills from being loaded in place of the kit's. opencode also reads
  `~/.claude/skills/` and `~/.agents/skills/`, and in one run an old copy of a different ElastiCORE
  skill there was loaded instead of this one. `"*": "deny"` turns off every other skill: add an
  `"allow"` line for each one you want to keep.
- A rule matches a skill by name, so it cannot tell two skills that are both named `elasticore`
  apart. opencode then logs `duplicate skill name` and keeps one of them, and which one is not
  guaranteed.
  Remove or rename the other copy, or start opencode with `OPENCODE_DISABLE_CLAUDE_CODE_SKILLS=1`
  so that it does not read `.claude/skills/`.
- **`bash`**: the last rule that matches wins, so `"*"` comes first - keep your own `"*"` rule if
  you have one, and put the deny lines after it. They keep the agent from stopping processes by
  name - a small model once killed every `java.exe` on the machine - and still let it stop the
  server it started by its process id, as `run-and-check.md` shows. The two agents carry the same
  deny lines.

## Uninstall

Delete what the installer copied: `plugins/elasticore.js`, the folders `elasticore-kit/` and
`skills/elasticore/`, `agents/elasticore-*.md` and `commands/elasticore-*.md` in
`~/.config/opencode/` or `.opencode/`.

## Develop

```bash
node tests/opencode/test-adapter.mjs   # Node 18 or later; runs the plugin against the real hook script
```
