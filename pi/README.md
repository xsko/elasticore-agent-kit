# ElastiCORE agent kit for pi and oh-my-pi

The kit's skills and hooks for [pi](https://pi.dev) (`@earendil-works/pi-coding-agent`, the `pi`
command) and [oh-my-pi](https://omp.sh) (`@oh-my-pi/pi-coding-agent`, the `omp` command), and for
omp the modeler and the reviewer as task agents. The skills and the hook script are the ones the
Claude Code plugin uses; one small extension,
[`plugins/elasticore/pi/elasticore.js`](../plugins/elasticore/pi/elasticore.js), runs the hook script
on the tool calls of either host and hands its answers back. It needs nothing but Node's built-ins
and the bash the hooks run in (Git Bash on Windows).

Checked with pi 1.6.1 and omp 19.2.1 on Windows, in live print-mode sessions (`-p --mode json`) with a
local model: in each, an edit of a file whose first line is `//ecd:` was refused with the hook's
reason and the agent did not try it another way, the edit of the model under
`src/main/resources/blueprint/<domain>/` came back with the note to run `./gradlew compileJava`, and
at the end the run was sent back once with the reminder that no build had compiled the change - and
the agent answered that the user had asked it not to build. pi was checked installed with
`install.ps1 -Project` and as a package (`pi install` of a local clone); omp with
`install.ps1 -Omp -Project` and from its marketplace (`omp plugin marketplace add` of a local clone).

## pi

### Install

As a pi package, for you:

```bash
pi install git:github.com/xsko/elasticore-agent-kit@v1.4.0
```

That adds the package to `~/.pi/agent/settings.json`: the extension and the skills `elasticore`,
`report-issue` and `contribute`. With `-l` it goes to the project's `.pi/settings.json` instead. pi
pins the tag; for a newer version, install again with its tag (pi tells a git package by its URL
without the tag, so the declaration is the same package). `pi list` shows what is installed, and
`pi remove git:github.com/xsko/elasticore-agent-kit` takes it out.

Or copy the files, from a checkout of this repository:

```bash
bash pi/install.sh              # for you: ~/.pi/agent/ ($PI_CODING_AGENT_DIR when set)
bash pi/install.sh --project    # for the project in the current folder: .pi/extensions/, .agents/skills/
```

On Windows: `powershell -ExecutionPolicy Bypass -File pi\install.ps1` (`-Project`), or the script from
Git Bash.

| From this repository | To `~/.pi/agent/` | To the project, with `--project` |
|---|---|---|
| `plugins/elasticore/pi/elasticore.js` | `extensions/elasticore/index.js` | `.pi/extensions/elasticore/index.js` |
| `plugins/elasticore/hooks/elasticore-hook.sh` | `extensions/elasticore/elasticore-hook.sh` | `.pi/extensions/elasticore/elasticore-hook.sh` |
| `plugins/elasticore/skills/elasticore/`, `report-issue/`, `contribute/` | `skills/` | `.agents/skills/` |

Run it again after `git pull` to update; it overwrites its own files and deletes nothing.
`.agents/skills/` is read by Codex and omp as well, and `~/.agents/skills/` (where `codex/install.sh`
puts the skills) by pi: with both installed, pi lists each skill twice, which does no harm.

**Trust.** pi loads a project's own files - `.pi/settings.json`, `.pi/extensions/`, `.agents/skills/` -
only once you trust the project. Start pi in the project and say yes when it asks, or run `/trust`;
`pi -a` trusts it for one run, and `pi -na` ignores the project's files. Without trust the kit
installed with `--project` or `pi install -l` is simply not there - no refusal, no note. An install
for you (`~/.pi/agent/`, or `pi install` without `-l`) needs no trust.

### What you get

| Part | What it does |
|---|---|
| Skill `elasticore` | The same skill as in Claude Code: which generator the build runs, whose a file is, where a change belongs, the loop, the recipes. `/skill:elasticore` loads it by hand. |
| Skills `report-issue`, `contribute` | As in Claude Code: draft a reproducible ElastiCORE issue (posted only on your yes); plan work on ElastiCORE itself in a checkout of it. |
| Extension `elasticore.js` | Blocks an edit or write of a generated file and a Gradle run with `-Pforce`; after a DSL edit or a build, appends a note to the tool's result; when the run is about to end with a DSL change no build has compiled, sends it back once (not after a run that ended in an error or was aborted). In an ElastiCORE checkout, the contributor checks instead. When the hooks cannot run - no hook script, a bash that does not run it - it says so once, at the start of the session. |

pi has no subagents, so there is no modeler or reviewer for it; the skill holds what they follow.

## oh-my-pi (omp)

omp needs Bun 1.4.4 or later: on an older Bun it does not start ("Bun runtime must be >= 1.4.4").
omp has no project trust - a project's `.omp/` is always read.

### Install

From a checkout of this repository:

```bash
bash pi/install.sh --omp              # for you: ~/.omp/agent/ ($PI_CODING_AGENT_DIR when set)
bash pi/install.sh --omp --project    # for the project in the current folder: .omp/
```

On Windows: `powershell -ExecutionPolicy Bypass -File pi\install.ps1 -Omp` (`-Project`).

| From this repository | To `~/.omp/agent/`, or `.omp/` with `--project` |
|---|---|
| `plugins/elasticore/pi/elasticore.js` | `extensions/elasticore/index.js` |
| `plugins/elasticore/hooks/elasticore-hook.sh` | `extensions/elasticore/elasticore-hook.sh` |
| `plugins/elasticore/skills/elasticore/`, `report-issue/`, `contribute/` | `skills/` |
| `plugins/elasticore/agents/modeler.md`, `reviewer.md` | `agents/elasticore-modeler.md`, `agents/elasticore-reviewer.md`: the same instructions, with omp's tool names (`read, grep, glob, edit, write, bash`; the reviewer without `edit` and `write`) |

Or from omp's marketplace, which reads the kit's Claude Code marketplace:

```bash
omp plugin marketplace add xsko/elasticore-agent-kit
omp plugin install elasticore@elasticore-agent-kit
```

That brings every skill of the Claude Code plugin, the extension (named in
`plugins/elasticore/package.json`) and the Claude Code agents under their Claude Code names,
`modeler` and `reviewer`. omp lets an agent of a plugin replace a bundled agent of the same name, and
omp has a `reviewer` of its own: installed this way, the kit's reviewer stands in for omp's in every
project (seen: omp's agent list then has no bundled `reviewer`). The installer above keeps omp's
reviewer and adds `elasticore-reviewer` beside it. Use one way, not both.

**The kit installed in Claude Code too.** omp can also read Claude Code's own plugins
(`~/.claude/plugins/installed_plugins.json`), but only when its Claude sources are turned on:
`enabledProviders` in omp's settings names `claude-plugins`, `claude` or `*`, or `CLAUDE_CONFIG_DIR` is
set. omp 19.2.1 leaves them off by default. With them on, omp takes Claude Code's copy of the kit -
its skills and its `modeler` and `reviewer`, at the version Claude Code has - and that `reviewer`
again replaces omp's own, beside the installer's `elasticore-*` agents (seen on a machine with the kit
in Claude Code: by default omp's agent list had only its own agents; with `CLAUDE_CONFIG_DIR` set it
had `elasticore-modeler`, `elasticore-reviewer`, `modeler` and `reviewer`, and no bundled
`reviewer`). That copy brings no extension: omp loads extensions only from
its own installs. To keep omp's reviewer, leave the Claude sources off, or turn the plugins off alone
with `disabledProviders: [claude-plugins]`.

### What you get

As for pi, and the task agents `elasticore-modeler` (turns a requirement into a DSL change that
generates and compiles, and reports it in business terms) and `elasticore-reviewer` (reviews a change;
it cannot edit files). A subagent's edits count for the session that started it: a DSL change a
subagent made still sends the main session back once at its end, as in Claude Code.

### Why the agents are called elasticore-modeler and elasticore-reviewer here

In Claude Code they are `elasticore:modeler` and `elasticore:reviewer` - Claude Code puts the plugin's
name in front - and the `review` skill hands its work to `elasticore:reviewer`. omp puts nothing in
front, and the first agent of a name wins over its bundled ones. Renaming the plugin's agents would
have changed them for every Claude Code user, so the installer gives omp copies the names opencode and
Codex use instead. omp reads a marketplace plugin's agents from its `agents/` folder whatever its
manifest says, so the marketplace route cannot be given other names without moving the Claude Code
agents.

## How the extension sees the two hosts

| Host event | Hook script | Back to the host |
|---|---|---|
| `tool_call` of `write` | `pre-edit`, as a Write | a refusal blocks the call: `{ block: true, reason }`, which the model reads as the tool's error |
| `tool_call` of `edit` - pi `{ path, edits: [{ oldText, newText }] }`, omp `replace` mode | `pre-edit`: one replacement as an Edit - the one-block insertion into a generated file goes through - several as one MultiEdit, as Claude Code sends them | as above |
| `tool_call` of `edit` - omp `hashline`, `apply_patch`, `sloppy`, `patch` or `magic` mode | `pre-edit` per file it names: a change (Patch), a new content (Write: an added file, the target of a move), a delete (Delete - goes through, as deleting a generated file and generating again is how one is restored) | as above |
| omp `ast_edit`, then `resolve` | `pre-edit` as a Patch for each file `ast_edit` names; for a folder or a glob, for each file its preview lists. A refused preview says so, and the `resolve` that would apply it is blocked (`reject` discards it); an applied one gets `post-edit` | as above; the preview's note as `additionalContext` |
| `tool_call` of `bash` (and pi's `powershell`) | `pre-bash`, with the folder the command runs in (omp's `cwd` when given, else the session's) and the call's id; an `apply_patch` run as a shell command (omp hands it to its patch tool) as the patch it is, file by file | as above |
| `tool_result` | `post-edit` once per file, or `post-bash`: the whole output (pi's `structuredContent.output`, or the file pi saved a cut one to), the exit code; a failure as `PostToolUseFailure`. An omp command run `async` comes back before it ran and is not read | pi: the note appended to the result's content; omp: `additionalContext`, which omp shows the model as a separate message |
| pi `agent_before_settle` (pi only) | `stop`, `stop_hook_active` while the run is the extension's own continuation (a new prompt ends it); not for an `outcome` other than `completed` | a message and `continue: true` - once |
| omp `session_stop` (omp only) | `stop`, with omp's own `stop_hook_active` | `continue: true` and the reminder - once |

Every payload carries the folder (`cwd`): the contributor checks tell a checkout of ElastiCORE by
it, and a build whose output goes to a file is read from the file it names, relative to it. A path
is read as the host reads it: a leading `@` or stray `:` dropped, a `file://` URL, `~`, and on
Windows `/c/...`, `/mnt/c/...` and `/cygdrive/c/...`. The hook script runs unchanged, as for Claude
Code: no argument names the host. The extension tells omp by its API (`arktype`, `zod` and `logger`,
which pi's has not).

## What it does not do

- **omp's other edit modes are judged file by file.** In `hashline` (omp's default for many models),
  `apply_patch`, `sloppy`, `patch` and `magic` mode, and with `ast_edit`, the hook cannot see the
  replaced text, so a change is never
  the one-block Edit it lets into a generated file: adding a preserved block to a `//ecd:` file is
  refused there, and the agent is told to put the change in the DSL. In `replace` mode - which omp
  chose by itself for the local model of the checks - it goes through as in Claude Code; set omp's
  `edit.mode` setting to `replace` to get it. A change of a merged generated file (a project
  with `.elasticore/generated-base.zip`) goes through in every mode; a whole new content over one is
  refused.
- **omp cuts a long command output in the middle.** It keeps the head and the tail and puts the whole
  output in an artifact (`local://...`), not a file the hook can read: a DSL warning in the middle of
  a very long Gradle log can be missed. A build whose output goes to a file (`> build.log 2>&1`,
  `| tee build.log`) is read from that file whole. pi keeps the whole output for the hook.
- **omp's previews are followed for `ast_edit` only.** `resolve` applies the newest pending preview;
  the extension keeps the same stack of `ast_edit` previews. A preview staged by a custom tool of
  yours sits on omp's stack but not on the extension's, so a `resolve` right after it is judged by
  the `ast_edit` preview under it.
- **A very long output can outlast the hook.** Reading several megabytes of output takes the hook
  script seconds (about 5 s for 1 MB, 9 s for 4 MB on a Windows PC), and it is stopped after 15 s, as
  in Claude Code: then that build's note is lost, and the extension says so once. A build whose output
  goes to a file is read the same way.
- **No subagents in pi.** The modeler and the reviewer are omp's only.
- **Print and json mode only.** The checks ran `pi -p` and `omp -p`; the interactive TUIs were not
  run. pi's documentation says `agent_before_settle` is the same in every mode.
- As in Claude Code, a change made another way - a script run through bash - is not stopped.

To let the agent edit generated files or use `-Pforce` anyway, start pi or omp with
`ELASTICORE_ALLOW_GENERATED_EDITS=1` or `ELASTICORE_ALLOW_FORCE=1` in its environment.

The hook script runs in bash. On Windows the extension runs Git Bash's launcher, `bin\bash.exe`: the
one `install.ps1` found (it writes its path to `extensions/elasticore/bash-path`), else one in
Program Files, `%LOCALAPPDATA%\Programs\Git`, Scoop's `git\current` or next to `git.exe` on the PATH -
the places `codex/install.ps1` looks in - and only then the `bash` on the PATH, which may be WSL's
and cannot run it. Without a bash that works, the refusals and notes are off; pi and omp go on
working, and the extension says so once, in the host's UI (or on stderr) - checked with a quick run
of the hook script when the session starts. The extension keeps what a session has done in `elasticore-agent-kit-pi-<user>` in the temp
directory.

## Uninstall

- pi package: `pi remove git:github.com/xsko/elasticore-agent-kit` (`-l` for a project's).
- Installed with `pi/install.sh`: delete `extensions/elasticore/` and the skill folders `elasticore/`,
  `report-issue/` and `contribute/` it copied, and for omp `agents/elasticore-modeler.md` and
  `agents/elasticore-reviewer.md`.
- omp marketplace: `omp plugin uninstall elasticore@elasticore-agent-kit`.

## Develop

```bash
node tests/pi/test-adapter.mjs   # Node 18 or later: the extension against the real hook script, install.sh, the package manifests
```
