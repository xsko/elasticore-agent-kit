# ElastiCORE agent kit for Codex CLI

The kit's skills, hooks and agents for [Codex CLI](https://github.com/openai/codex). The skills and
the hook script are the ones the Claude Code plugin uses; the hook script reads Codex's own payloads
when its hooks file passes it `codex`.

Checked with Codex CLI 0.172.0 on Windows, in live `codex exec` sessions with the plugin installed:
an `apply_patch` of a `//ecd:` file was refused and Codex said so, the DSL edit got the note to
build, and the end of the turn sent Codex back once; in a checkout of ElastiCORE the same patch of
a sample's generated file went through. The payloads the hook script reads were captured from
those sessions and are cases of `tests/hooks/test-hooks.sh`.

## Install

From a checkout of this repository:

```bash
bash codex/install.sh             # for you: ~/.agents/skills/, ~/.codex/ (or $CODEX_HOME)
bash codex/install.sh --project   # for the project in the current folder: .agents/skills/, .codex/
```

On Windows, run `powershell -ExecutionPolicy Bypass -File codex\install.ps1` (`-Project`,
`-NoHooks`, `-AgentsOnly`), or the script from Git Bash. `--no-hooks` installs the skills and the
agents; `--agents-only` the agents alone - next to the plugin, which brings the skills and hooks.
The hooks need Git for Windows: install.ps1 looks for its Git Bash (`bin\bash.exe`) in Program
Files, `%LOCALAPPDATA%\Programs\Git`, Scoop's `git\current` and next to `git.exe` on the PATH, and
the hooks call the one it found. It copies:

| From this repository | To |
|---|---|
| `plugins/elasticore/skills/elasticore/`, `report-issue/`, `contribute/` | `.agents/skills/` |
| `codex/agents/elasticore-modeler.toml`, `elasticore-reviewer.toml` | `.codex/agents/` |
| `plugins/elasticore/hooks/elasticore-hook.sh` | `.codex/elasticore-kit/elasticore-hook.sh` |
| - | `.codex/hooks.json`, written only when there is none: it runs that script on `apply_patch` and shell calls and at the end of a turn. A `hooks.json` of yours is left as it is, and the installer prints the hooks to add to it |

Run it again after `git pull` to update; it overwrites its own files and deletes nothing.

Then start Codex, open `/hooks` and trust the ElastiCORE hooks: Codex runs no hook it has not been
told to trust, and asks again when the script changes. A project's `.codex/` is read only in a
project Codex trusts.

## Or as a plugin

```bash
codex plugin marketplace add xsko/elasticore-agent-kit
codex plugin add elasticore@elasticore-agent-kit
```

The plugin brings the skills and the hooks (`plugins/elasticore/hooks/codex-hooks.json`, named in
the plugin's `.codex-plugin/plugin.json`); trust them in `/hooks` as above. Checked: both
`codex plugin marketplace add` from a local clone and from GitHub (`--ref` a branch) install it.
On Windows its hooks look for Git Bash in the same places as install.ps1; with none found, each
hook fails with "no Git Bash found ... its Codex hooks are off", which Codex shows as a hook error.
The agents are not part of a Codex plugin: add them with `bash codex/install.sh --agents-only`
(`-AgentsOnly`). Install the hooks one way only - from
the plugin, or from the installer - or they run twice. `codex plugin marketplace upgrade` and the
same `codex plugin add` update it.

## Update

Codex does not update the kit on its own. Update it the way you installed it, then start a new
Codex session and trust the hooks again in `/hooks` if Codex asks (it does when the hook script
changed).

**Installed as a plugin:**

```bash
codex plugin marketplace upgrade elasticore-agent-kit   # fetch the newest kit
codex plugin add elasticore@elasticore-agent-kit        # install that version
codex plugin list                                       # the VERSION column shows what you have
```

A marketplace added with `--ref` stays on that ref: `upgrade` does not move it to a newer tag.
To change the version, remove the marketplace and add it again with the new ref (or none), then add
the plugin - the old version's cache is removed:

```bash
codex plugin marketplace remove elasticore-agent-kit
codex plugin marketplace add xsko/elasticore-agent-kit           # or --ref vX.Y.Z
codex plugin add elasticore@elasticore-agent-kit
```

If you installed the agents with `--agents-only`, update them as below too.

**Installed with the installer:** update your clone and run the installer again with the same
options (`--project`, `--no-hooks`, `--agents-only`):

```bash
cd elasticore-agent-kit          # your clone of this repository
git pull                         # or git checkout vX.Y.Z for one version
git describe --tags              # the version you are about to install
bash codex/install.sh                                         # macOS, Linux, Git Bash
powershell -ExecutionPolicy Bypass -File codex\install.ps1    # Windows PowerShell
```

It overwrites the skills, the agents and the hook script and deletes nothing. It writes
`hooks.json` only when there is none: an existing one - the kit's from an earlier install, or yours -
stays as it is, and the installer prints the hooks it would add, to compare with yours. On Windows
use `install.ps1` or Git Bash itself: a `bash` from MSYS2 or WSL has a home of its own and installs
there.

Checked with Codex CLI 0.172.0, each in a fresh `CODEX_HOME`: the plugin from GitHub, then
`marketplace upgrade` and `plugin add` (1.4.0); the marketplace added with `--ref v1.3.0` (plugin
1.3.0), removed and added again without a ref (plugin 1.4.0, the 1.3.0 cache gone); and
`install.ps1 -Project` from v1.4.0 over a project.

## What you get

| Part | What it does |
|---|---|
| Skill `elasticore` | Which generator the build runs, whose a file is, where a change belongs, the loop, the recipes. |
| Skill `report-issue` | Reproduces an ElastiCORE defect in a minimal project, searches the existing issues, drafts one with the private details taken out; posts with `gh` only on your yes. |
| Skill `contribute` | In a checkout of ElastiCORE itself: plans the change for an issue by the checkout's `CONTRIBUTING.md` before any code. |
| Hooks | Refuse an `apply_patch` that changes a generated file (or replaces a merged one with a whole new content) and a Gradle run with `-Pforce`; after a DSL change or a build, add what to do next; at the end of a turn with a DSL change no build has compiled, send Codex back once. In an ElastiCORE checkout, the contributor checks instead. |
| Agents `elasticore-modeler`, `elasticore-reviewer` | As in Claude Code. Name them in a prompt ("have elasticore-reviewer review the change"). Codex gives a custom agent the session's sandbox and approvals; the reviewer's instructions keep it from editing. |

## How the hooks see Codex

- An edit is the `apply_patch` tool, the patch in `tool_input.command`, with paths relative to
  the call's `cwd`. The hook checks each file the patch names: `*** Add File:` and `*** Move to:`
  give a file a whole new content, like a Write; `*** Update File:` edits it; `*** Delete File:`
  goes through - deleting a generated file and generating again is how one is restored.
- A shell call is `Bash`, the command in `tool_input.command` as the model wrote it (Codex runs it
  through PowerShell on Windows; the hook sees the command itself).
- The end of a turn is `Stop`: the hook answers `{"decision": "block", "reason": "..."}`, which
  Codex takes as the next prompt, and only when `stop_hook_active` is false - so it asks once.
- Codex has no `PostToolUseFailure`: a shell command that failed comes as PostToolUse too, and its
  `tool_response` is the output as one string, with no exit code. So the hook tells a failed build
  by what Gradle printed (`BUILD FAILED`, no `BUILD SUCCESSFUL`), as it does for a successful one;
  a command whose output looks successful but that exited non-zero cannot be told apart. (An
  `apply_patch` response starts `Exit code: N`, which the hook reads.)
- On Windows Codex runs a hook's command with PowerShell. The plugin's hooks therefore have a
  `commandWindows` that looks for Git Bash's launcher (`bin\bash.exe`) and calls it with `&` and
  `$env:PLUGIN_ROOT/hooks/...`; the installer writes `& '<Git Bash>' '<hook script>'` with the paths
  it found. A plain `bash "..."` there may start WSL's bash, and a quoted path followed by arguments
  is a PowerShell syntax error. The hook script puts `/usr/bin` first on its PATH itself, so that
  Git's `usr\bin\bash.exe`, started with only `Git\cmd` on the Windows PATH, still finds its tools.
- The plugin's hooks file is named in `.codex-plugin/plugin.json`. The plugin's root `plugin.json`
  must not be a portable manifest (`$schema`): with one, Codex 0.172 runs none of the plugin's
  hooks, and without `.codex-plugin` it runs `hooks/hooks.json`, which is Claude Code's.

To let Codex edit generated files or use `-Pforce` anyway, start it with
`ELASTICORE_ALLOW_GENERATED_EDITS=1` or `ELASTICORE_ALLOW_FORCE=1` in its environment.

## Develop

```bash
bash tests/codex/test-codex.sh   # the agents against their Markdown, the manifest, the hooks file, install.sh
bash tests/hooks/test-hooks.sh   # the hook script, with the payloads Codex sends among the cases
```
