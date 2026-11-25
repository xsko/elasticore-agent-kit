// The ElastiCORE agent kit for opencode.
//
// Runs the kit's hook script - the one its Claude Code plugin uses - with the
// JSON Claude Code would send, and maps the answers back: a refusal becomes a
// tool error, a note is added to the tool's output, and a DSL change that no
// build has compiled sends the session back once when it goes idle.
//
// One file for both plugin APIs:
//   opencode 1.x  the default export's server(), the same function as the
//                 named export ElastiCore;
//   opencode 2.x  the default export's id and setup(ctx) - 2.x runs no 1.x plugin.
// opencode 1.19 calls setup() as well, with a context that has no tool hooks:
// setup() then registers nothing and server() does the work.
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

// opencode's tools, by the names the hook script knows. 1.x names them edit,
// write, apply_patch and bash; 2.x edit, write, patch and shell.
const EDIT_TOOLS = { edit: "Edit", write: "Write" }
const PATCH_TOOLS = new Set(["apply_patch", "patch"])
const SHELL_TOOLS = new Set(["bash", "shell"])

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

// The file an edit or write names: filePath in 1.x, path in 2.x.
function fileOf(args) {
  for (const file of [args.filePath, args.path]) if (typeof file === "string" && file) return file
  return null
}

function editInput(args, directory) {
  return {
    file_path: absolute(fileOf(args), directory),
    old_string: args.oldString,
    new_string: args.newString,
    replace_all: !!args.replaceAll,
    content: args.content,
  }
}

// The patch text: patchText in both, or the bare text a freeform call may pass.
function patchOf(args) {
  if (typeof args === "string") return args
  return args && typeof args.patchText === "string" ? args.patchText : ""
}

// The files a patch adds, changes, deletes or moves to, each with the tool the
// hook script takes it for: a file the patch adds or moves to gets the whole of
// its content from the patch, as from a Write; one it changes or deletes is
// edited. Neither is ever the one-block Edit the hook lets through.
function patchFiles(patchText, directory) {
  const files = []
  for (const line of String(patchText || "").split(/\r?\n/)) {
    const m = /^\*\*\* (Add File|Update File|Delete File|Move to): (.+)$/.exec(line)
    if (m) files.push({ file: absolute(m[2].trim(), directory), tool: m[1] === "Add File" || m[1] === "Move to" ? "Write" : "Edit" })
  }
  return files
}

function editHook(event, sessionID, tool, input) {
  return run(event, { session_id: sessionID, hook_event_name: event === "pre-edit" ? "PreToolUse" : "PostToolUse", tool_name: tool, tool_input: input })
}

// Before a tool runs: the hook's refusal, or null to let it go ahead.
function refusalFor(tool, sessionID, args, directory) {
  try {
    const answers = []
    if (EDIT_TOOLS[tool] && args && fileOf(args)) {
      answers.push(editHook("pre-edit", sessionID, EDIT_TOOLS[tool], editInput(args, directory)))
    } else if (PATCH_TOOLS.has(tool) && patchOf(args)) {
      // One file at a time.
      for (const { file, tool } of patchFiles(patchOf(args), directory)) answers.push(editHook("pre-edit", sessionID, tool, { file_path: file }))
    } else if (SHELL_TOOLS.has(tool) && args && args.command) {
      answers.push(run("pre-bash", { session_id: sessionID, hook_event_name: "PreToolUse", tool_name: "Bash", tool_input: { command: args.command } }))
    }
    const refusal = answers.find((a) => a && a.permissionDecision === "deny")
    return refusal ? refusal.permissionDecisionReason || "Refused by the ElastiCORE agent kit." : null
  } catch {
    return null
  }
}

// After a file tool ran: the hook's note, or "".
function editNote(tool, sessionID, args, directory) {
  try {
    if (EDIT_TOOLS[tool] && args && fileOf(args)) {
      const answer = editHook("post-edit", sessionID, EDIT_TOOLS[tool], editInput(args, directory))
      return (answer && answer.additionalContext) || ""
    }
    if (PATCH_TOOLS.has(tool) && patchOf(args)) {
      const notes = []
      for (const { file, tool } of patchFiles(patchOf(args), directory)) {
        const answer = editHook("post-edit", sessionID, tool, { file_path: file })
        if (answer && answer.additionalContext && !notes.includes(answer.additionalContext)) notes.push(answer.additionalContext)
      }
      return notes.join(" ")
    }
  } catch {}
  return ""
}

// After a shell command ran: the hook's note, or "". text is what the command
// printed as the model sees it, exit its exit code, saved the file opencode
// keeps the whole of a long output in.
function shellNote(sessionID, command, text, exit, saved) {
  try {
    const response = { stdout: text, stderr: "", interrupted: false, isImage: false }
    if (saved && existsSync(saved)) response.persistedOutputPath = saved
    const payload =
      exit === 0
        ? { session_id: sessionID, hook_event_name: "PostToolUse", tool_name: "Bash", tool_input: { command }, tool_response: response }
        : { session_id: sessionID, hook_event_name: "PostToolUseFailure", tool_name: "Bash", tool_input: { command }, error: "Exit code " + exit + "\n" + text, is_interrupt: false }
    const answer = run("post-bash", payload)
    return (answer && answer.additionalContext) || ""
  } catch {
    return ""
  }
}

// opencode cuts a long output and saves the whole of it to a file; the hook
// script reads that file, as it does Claude Code's. 1.x says "Full output saved
// to: <path>", 2.x "[... full output saved to <path>]".
// The last such line counts: opencode adds it after what the command printed.
function savedPath(text) {
  const all = [...String(text || "").matchAll(/full output saved to:? ([^\]\r\n]+)/gi)]
  return all.length ? all[all.length - 1][1].trim() : null
}

// When the session is about to go idle: what to send it back with, or "".
function stopNote(sessionID) {
  try {
    const answer = run("stop", { session_id: sessionID, hook_event_name: "Stop", stop_hook_active: false })
    return (answer && answer.additionalContext) || ""
  } catch {
    return ""
  }
}

const TAG = "[ElastiCORE agent kit] "

function note(output, text) {
  if (text) output.output = (output.output || "") + "\n\n" + TAG + text
}

// --- opencode 1.x ------------------------------------------------------------------

export const ElastiCore = async ({ client, directory }) => {
  const base = directory || process.cwd()

  return {
    "tool.execute.before": async (input, output) => {
      let refusal = null
      try {
        refusal = refusalFor(input.tool, input.sessionID, output.args || {}, base)
      } catch {}
      // The only way out of this hook that stops the tool.
      if (refusal) throw new Error(refusal)
    },

    "tool.execute.after": async (input, output) => {
      try {
        const args = input.args || {}
        if (SHELL_TOOLS.has(input.tool)) {
          if (!args.command) return
          const meta = output.metadata || {}
          const exit = typeof meta.exit === "number" ? meta.exit : 0
          const text = [output.output, meta.output].filter((t) => typeof t === "string" && t).join("\n")
          note(output, shellNote(input.sessionID, args.command, text, exit, savedPath(text)))
        } else {
          note(output, editNote(input.tool, input.sessionID, args, base))
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
        const text = stopNote(id)
        if (!text) return
        await client.session.prompt({ path: { id }, body: { parts: [{ type: "text", text: TAG + text }] } })
      } catch {}
    },
  }
}

// --- opencode 2.x ------------------------------------------------------------------

// The text a 2.x tool result shows the model: its content, else its output.
function resultText(result) {
  if (!result) return ""
  const { content, output } = result
  if (typeof content === "string") return content
  if (Array.isArray(content)) return content.filter((c) => c && c.type === "text" && typeof c.text === "string").map((c) => c.text).join("\n")
  if (typeof output === "string") return output
  return output && typeof output.output === "string" ? output.output : ""
}

// Adds a note to a 2.x tool result: to its content, and to its output when that is
// text. A result with neither gets content of its output's text and the note, so
// the model still sees what the tool returned. opencode 2.4 reads the result back
// from the event (seen live: the note reached the model).
function noteResult(event, text) {
  if (!text) return
  const result = event.result || {}
  const tagged = TAG + text
  const next = { ...result }
  if (typeof result.content === "string") next.content = result.content + "\n\n" + tagged
  else if (Array.isArray(result.content)) next.content = [...result.content, { type: "text", text: tagged }]
  else if (typeof result.output !== "string") {
    const out = result.output
    const shown = out === undefined || out === null ? "" : typeof out.output === "string" ? out.output : JSON.stringify(out)
    next.content = shown ? [{ type: "text", text: shown }, { type: "text", text: tagged }] : [{ type: "text", text: tagged }]
  }
  if (typeof result.output === "string") next.output = result.output + "\n\n" + tagged
  event.result = next
}

async function setup(ctx) {
  // opencode 1.19 calls setup() with a context that has no tool hooks; server() serves it.
  if (!ctx || !ctx.tool || typeof ctx.tool.hook !== "function") return
  const base = (ctx.location && ctx.location.directory) || process.cwd()
  const registrations = []
  const register = async (domain, name, callback) => {
    try {
      if (domain && typeof domain.hook === "function") registrations.push(await domain.hook(name, callback))
    } catch {}
  }

  await register(ctx.tool, "execute.before", (event) => {
    let refusal = null
    try {
      refusal = refusalFor(event.tool, event.sessionID, event.input, base)
    } catch {}
    // Throwing is how a 2.x hook stops the call.
    if (refusal) throw new Error(refusal)
  })

  await register(ctx.tool, "execute.after", (event) => {
    try {
      const args = event.input || {}
      if (SHELL_TOOLS.has(event.tool)) {
        if (!args.command) return
        if (event.status === "completed") {
          const result = event.result || {}
          const out = result.output && typeof result.output === "object" ? result.output : {}
          const meta = result.metadata || {}
          const exit = typeof meta.exit === "number" ? meta.exit : typeof out.exitCode === "number" ? out.exitCode : 0
          const text = resultText(result)
          const saved = typeof out.outputPath === "string" ? out.outputPath : savedPath(text)
          noteResult(event, shellNote(event.sessionID, args.command, text, exit, saved))
        } else {
          // A call that failed outright - a command that ran comes back completed, with
          // its exit code in metadata.exit: the hook still learns of it, but an error
          // has no output to take a note.
          const error = event.error
          const message = typeof error === "string" ? error : (error && error.message) || "failed"
          shellNote(event.sessionID, args.command, message, 1, null)
        }
      } else if (event.status === "completed") {
        noteResult(event, editNote(event.tool, event.sessionID, args, base))
      }
    } catch {}
  })

  // Just before a session goes idle. A message admitted here runs instead of the
  // session going idle - in `opencode run` too.
  if (ctx.session && typeof ctx.session.synthetic === "function") {
    await register(ctx.session, "experimental.idle", async (event) => {
      try {
        const id = event && event.sessionID
        if (!id) return
        const text = stopNote(id)
        if (!text) return
        await ctx.session.synthetic({ sessionID: id, text: TAG + text, description: "ElastiCORE agent kit" })
      } catch {}
    })
  }

  return async () => {
    for (const registration of registrations.splice(0)) {
      try {
        await registration.dispose()
      } catch {}
    }
  }
}

export default { id: "elasticore-agent-kit", setup, server: ElastiCore }
