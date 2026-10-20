// The ElastiCORE agent kit for opencode.
//
// Runs the kit's hook script - the one its Claude Code plugin uses - with the
// JSON Claude Code would send, and maps the answers back: a refusal becomes a
// tool error, a note is added to the tool's output, and a DSL change that no
// build has compiled sends the session back once when it goes idle.
//
// The installers put this file and the hook script side by side, in
// ~/.config/opencode/ or a project's .opencode/:
//   plugins/elasticore.js
//   elasticore-kit/elasticore-hook.sh
// ELASTICORE_KIT_HOOK names another hook script. ELASTICORE_ALLOW_GENERATED_EDITS
// and ELASTICORE_ALLOW_FORCE reach the hook script as they do in Claude Code.
//
// Anything unexpected - no bash, no hook script, an answer that is not JSON -
// lets the tool call go ahead: a broken hook never blocks the work.
import { spawnSync } from "node:child_process"
import { existsSync, mkdirSync } from "node:fs"
import { homedir, tmpdir, userInfo } from "node:os"
import { dirname, isAbsolute, join, resolve } from "node:path"
import { fileURLToPath } from "node:url"

const INSTALLED_HOOK = join(dirname(fileURLToPath(import.meta.url)), "..", "elasticore-kit", "elasticore-hook.sh")

// Where the hook script keeps what a session has done: a directory of this
// user's own, as the Claude Code plugin's data directory is.
function dataDir() {
  let base = tmpdir()
  // Started without TEMP and TMP, tmpdir() on Windows is C:\Windows\Temp, which every user shares.
  if (process.platform === "win32" && !process.env.TEMP && !process.env.TMP) {
    base = join(process.env.LOCALAPPDATA || join(homedir(), "AppData", "Local"), "Temp")
  }
  let user = ""
  try {
    user = userInfo().username.replace(/[^A-Za-z0-9_-]/g, "")
  } catch {}
  return join(base, "elasticore-agent-kit-opencode" + (user ? "-" + user : ""))
}
const DATA = dataDir()

// Git Bash on Windows: the "bash" on the PATH there may be WSL's, which cannot
// read a Windows path to the script.
function findBash() {
  if (process.platform !== "win32") return "bash"
  const roots = [process.env.ProgramFiles, process.env["ProgramFiles(x86)"], process.env.LOCALAPPDATA && join(process.env.LOCALAPPDATA, "Programs")]
  for (const root of roots) {
    const bash = root && join(root, "Git", "bin", "bash.exe")
    if (bash && existsSync(bash)) return bash
  }
  return "bash"
}
const BASH = findBash()

// opencode's file tools, by the names the hook script knows.
const EDIT_TOOLS = { edit: "Edit", write: "Write" }

function run(event, payload) {
  try {
    const hook = process.env.ELASTICORE_KIT_HOOK || INSTALLED_HOOK
    if (!existsSync(hook)) return null
    mkdirSync(DATA, { recursive: true })
    const r = spawnSync(BASH, [hook, event], {
      input: JSON.stringify(payload),
      encoding: "utf8",
      timeout: 15000,
      windowsHide: true,
      env: { ...process.env, CLAUDE_PLUGIN_DATA: DATA },
    })
    const line = (r.stdout || "").trim().split("\n").pop()
    return line ? JSON.parse(line).hookSpecificOutput || null : null
  } catch {
    return null
  }
}

// A path a tool was given, made absolute against the project directory as
// opencode does: a model may pass src/main/... and the hook script matches
// */src/main/....
function absolute(path, directory) {
  return isAbsolute(path) ? path : resolve(directory, path)
}

function editInput(args, directory) {
  return {
    file_path: absolute(args.filePath, directory),
    old_string: args.oldString,
    new_string: args.newString,
    replace_all: !!args.replaceAll,
    content: args.content,
  }
}

// The files an apply_patch call adds, changes, deletes or moves to.
function patchFiles(patchText, directory) {
  const files = []
  for (const line of String(patchText || "").split(/\r?\n/)) {
    const m = /^\*\*\* (?:(?:Add|Update|Delete) File|Move to): (.+)$/.exec(line)
    if (m) files.push(absolute(m[1].trim(), directory))
  }
  return files
}

function note(output, text) {
  if (text) output.output = (output.output || "") + "\n\n[ElastiCORE agent kit] " + text
}

export const ElastiCore = async ({ client, directory }) => {
  const base = directory || process.cwd()
  const edit = (event, sessionID, tool, input) =>
    run(event, { session_id: sessionID, hook_event_name: event === "pre-edit" ? "PreToolUse" : "PostToolUse", tool_name: tool, tool_input: input })

  return {
    "tool.execute.before": async (input, output) => {
      let refusal = null
      try {
        const args = output.args || {}
        const answers = []
        if (EDIT_TOOLS[input.tool] && args.filePath) {
          answers.push(edit("pre-edit", input.sessionID, EDIT_TOOLS[input.tool], editInput(args, base)))
        } else if (input.tool === "apply_patch" && args.patchText) {
          // One file at a time, as a Write: a patch is never the one-block Edit the hook lets through.
          for (const file of patchFiles(args.patchText, base)) answers.push(edit("pre-edit", input.sessionID, "Write", { file_path: file }))
        } else if (input.tool === "bash" && args.command) {
          answers.push(run("pre-bash", { session_id: input.sessionID, hook_event_name: "PreToolUse", tool_name: "Bash", tool_input: { command: args.command } }))
        }
        refusal = answers.find((a) => a && a.permissionDecision === "deny")
      } catch {}
      // The only way out of this hook that stops the tool.
      if (refusal) throw new Error(refusal.permissionDecisionReason || "Refused by the ElastiCORE agent kit.")
    },

    "tool.execute.after": async (input, output) => {
      try {
        const args = input.args || {}
        if (EDIT_TOOLS[input.tool] && args.filePath) {
          const answer = edit("post-edit", input.sessionID, EDIT_TOOLS[input.tool], editInput(args, base))
          note(output, answer && answer.additionalContext)
        } else if (input.tool === "apply_patch" && args.patchText) {
          const notes = []
          for (const file of patchFiles(args.patchText, base)) {
            const answer = edit("post-edit", input.sessionID, "Write", { file_path: file })
            if (answer && answer.additionalContext && !notes.includes(answer.additionalContext)) notes.push(answer.additionalContext)
          }
          note(output, notes.join(" "))
        } else if (input.tool === "bash" && args.command) {
          const meta = output.metadata || {}
          const exit = typeof meta.exit === "number" ? meta.exit : 0
          const text = [output.output, meta.output].filter((t) => typeof t === "string" && t).join("\n")
          // opencode cuts a long output and saves the whole of it to a file; the
          // hook script reads that file, as it does Claude Code's.
          const saved = /Full output saved to: ([^\r\n]+)/.exec(text)
          const response = { stdout: text, stderr: "", interrupted: false, isImage: false }
          if (saved && existsSync(saved[1].trim())) response.persistedOutputPath = saved[1].trim()
          const payload =
            exit === 0
              ? { session_id: input.sessionID, hook_event_name: "PostToolUse", tool_name: "Bash", tool_input: { command: args.command }, tool_response: response }
              : { session_id: input.sessionID, hook_event_name: "PostToolUseFailure", tool_name: "Bash", tool_input: { command: args.command }, error: "Exit code " + exit + "\n" + text, is_interrupt: false }
          const answer = run("post-bash", payload)
          note(output, answer && answer.additionalContext)
        }
      } catch {}
    },

    // Only an interactive session (the TUI, opencode serve) takes the prompt
    // and goes on; `opencode run` has ended by the time it goes idle.
    event: async ({ event }) => {
      try {
        if (!event || event.type !== "session.idle") return
        const id = event.properties && event.properties.sessionID
        if (!id) return
        const answer = run("stop", { session_id: id, hook_event_name: "Stop", stop_hook_active: false })
        if (!answer || !answer.additionalContext) return
        await client.session.prompt({ path: { id }, body: { parts: [{ type: "text", text: "[ElastiCORE agent kit] " + answer.additionalContext }] } })
      } catch {}
    },
  }
}
