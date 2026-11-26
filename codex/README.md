# ElastiCORE agent kit for Codex CLI

The kit's skills, hooks and agents for [Codex CLI](https://github.com/openai/codex). The skills and
the hook script are the ones the Claude Code plugin uses; the hook script reads Codex's own payloads
when its hooks file passes it `codex`.

Checked with Codex CLI 0.172.0: the plugin installs from this repository as a marketplace
(`.agents/plugins/marketplace.json`), and `codex/install.sh` installs into a project and a home
folder. **Not yet seen in a live Codex session in this version:** the hooks' answers reaching the
model - the payload shapes the hook script reads are those of Codex's hooks documentation.

## Install

From a checkout of this repository:

```bash
bash codex/install.sh             # for you: ~/.agents/skills/, ~/.codex/ (or $CODEX_HOME)
bash codex/install.sh --project   # for the project in the current folder: .agents/skills/, .codex/
```

On Windows, run it from Git Bash, or `powershell -ExecutionPolicy Bypass -File codex\install.ps1`
(`-Project`, `-NoHooks`), which runs the same script with Git Bash. It copies:

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
the plugin's `plugin.json`); trust them in `/hooks` as above. The agents are not part of a Codex
plugin: add them with `bash codex/install.sh --no-hooks`. Install the hooks one way only - from
the plugin, or from the installer - or they run twice. `codex plugin marketplace upgrade` and the
same `codex plugin add` update it.

## What you get

| Part | What it does |
|---|---|
| Skill `elasticore` | Which generator the build runs, whose a file is, where a change belongs, the loop, the recipes. |
| Skill `report-issue` | Reproduces an ElastiCORE defect in a minimal project, searches the existing issues, drafts one with the private details taken out; posts with `gh` only on your yes. |
| Skill `contribute` | In a checkout of ElastiCORE itself: plans the change for an issue by the checkout's `CONTRIBUTING.md` before any code. |
| Hooks | Refuse an `apply_patch` that changes a generated file (or replaces a merged one with a whole new content) and a Gradle run with `-Pforce`; after a DSL change or a build, add what to do next; at the end of a turn with a DSL change no build has compiled, send Codex back once. In an ElastiCORE checkout, the contributor checks instead. |
| Agents `elasticore-modeler`, `elasticore-reviewer` | As in Claude Code. Name them in a prompt ("have elasticore-reviewer review the change"). Codex gives a custom agent the session's sandbox and approvals; the reviewer's instructions keep it from editing. |

## How the hooks see Codex

- An edit is the `apply_patch` tool, the patch in `tool_input.command`. The hook checks each file
  the patch names: `*** Add File:` and `*** Move to:` give a file a whole new content, like a
  Write; `*** Update File:` and `*** Delete File:` edit it. A relative path is taken from the
  call's `cwd`.
- A shell call is `Bash`, the command in `tool_input.command`.
- The end of a turn is `Stop`: the hook answers `{"decision": "block", "reason": "..."}`, which
  Codex takes as the next prompt, and only when `stop_hook_active` is false - so it asks once.
- Codex has no `PostToolUseFailure`. The hook script takes a command for failed when Codex's
  `tool_response` carries a non-zero `exit_code`; whether Codex sends PostToolUse for a command
  that failed, and in that shape, has not been seen live yet.

To let Codex edit generated files or use `-Pforce` anyway, start it with
`ELASTICORE_ALLOW_GENERATED_EDITS=1` or `ELASTICORE_ALLOW_FORCE=1` in its environment.

## Develop

```bash
bash tests/codex/test-codex.sh   # the agents against their Markdown, the manifest, the hooks file, install.sh
bash tests/hooks/test-hooks.sh   # the hook script, with the payloads Codex sends among the cases
```
