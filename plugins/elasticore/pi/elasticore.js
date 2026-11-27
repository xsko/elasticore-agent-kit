// The ElastiCORE agent kit for pi (@earendil-works/pi-coding-agent) and
// oh-my-pi (omp, @oh-my-pi/pi-coding-agent).
//
// Runs the kit's hook script - the one its Claude Code plugin uses - with the
// JSON Claude Code would send, and maps the answers back: a refusal blocks the
// tool call, a note reaches the model after the tool's result, and a DSL change
// that no build has compiled sends the run back once before it ends.
//
// One file for both hosts, Node built-ins only: pi loads it with jiti, omp with
// bun. It finds the hook script next to itself (pi/install.sh copies both into
// one folder) or in the plugin tree, plugins/elasticore/pi/ ->
// plugins/elasticore/hooks/ (a pi package, an omp marketplace install).
// ELASTICORE_KIT_HOOK names another hook script. ELASTICORE_ALLOW_GENERATED_EDITS,
// ELASTICORE_ALLOW_FORCE and ELASTICORE_ALLOW_HISTORY_EDITS reach the hook script
// as they do in Claude Code.
//
// Anything unexpected - no bash, no hook script, an answer that is not JSON -
// lets the tool call go ahead: a broken hook never blocks the work.
import { spawnSync } from "node:child_process"
import { existsSync, mkdirSync, readFileSync } from "node:fs"
import { homedir, tmpdir, userInfo } from "node:os"
import { delimiter, dirname, isAbsolute, join, resolve } from "node:path"
import { fileURLToPath } from "node:url"

const HERE = dirname(fileURLToPath(import.meta.url))
const HOOKS = [join(HERE, "elasticore-hook.sh"), join(HERE, "..", "hooks", "elasticore-hook.sh")]

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
  return join(base, "elasticore-agent-kit-pi" + (user ? "-" + user : ""))
}
const DATA = dataDir()

// Git Bash on Windows, its launcher bin\bash.exe: the "bash" on the PATH there may
// be WSL's, which cannot read a Windows path to the script, and Git's
// usr\bin\bash.exe does not put Git's tools on the PATH. First the one
// pi/install.ps1 found (the file bash-path next to this one), then the places
// codex/install.ps1 looks in.
function findBash() {
  if (process.platform !== "win32") return "bash"
  const candidates = []
  try {
    candidates.push(readFileSync(join(HERE, "bash-path"), "utf8").trim())
  } catch {}
  const env = process.env
  for (const root of [env.ProgramFiles, env["ProgramFiles(x86)"], env.LOCALAPPDATA && join(env.LOCALAPPDATA, "Programs")]) {
    if (root) candidates.push(join(root, "Git", "bin", "bash.exe"))
  }
  if (env.USERPROFILE) candidates.push(join(env.USERPROFILE, "scoop", "apps", "git", "current", "bin", "bash.exe"))
  // Next to git.exe on the PATH: Git\cmd\git.exe or Git\mingw64\bin\git.exe.
  for (const dir of String(env.PATH || env.Path || "").split(delimiter)) {
    if (!dir || !existsSync(join(dir, "git.exe"))) continue
    const folder = dirname(dir)
    candidates.push(join(folder, "bin", "bash.exe"), join(dirname(folder), "bin", "bash.exe"))
  }
  return candidates.find((bash) => bash && existsSync(bash)) || "bash"
}
const BASH = findBash()

function run(event, payload) {
  try {
    const hook = process.env.ELASTICORE_KIT_HOOK || HOOKS.find((p) => existsSync(p))
    if (!hook || !existsSync(hook)) return null
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

// A path a tool was given, made absolute against the session's directory: a
// model may pass src/main/... and the hook script matches */src/main/....
function absolute(path, cwd) {
  return isAbsolute(path) ? path : resolve(cwd, path)
}

// The files a text payload of omp's edit tool names, each with the tool the hook
// script takes it for:
//   apply_patch  "*** Add File: P" and "*** Move to: P" give P a whole new content
//                (Write), "*** Update File: P" changes it (Patch), "*** Delete File: P"
//                deletes it (Delete) - as Codex's apply_patch;
//   hashline     a "[P#TAG]" section changes P (Patch), or deletes it with a REM line
//                (Delete); its "MV DEST" moves it onto DEST (Write);
//   magic        a "# P" section describes a change to P (Patch).
// A Patch is never the one-block Edit the hook lets into a generated file.
function textFiles(text, cwd) {
  const lines = String(text || "").split(/\r?\n/)
  const files = []
  let section = null
  for (const line of lines) {
    let m = /^\*\*\* (Add File|Update File|Delete File|Move to): (.+?)\s*$/.exec(line)
    if (m) {
      section = null
      files.push({ tool: m[1] === "Delete File" ? "Delete" : m[1] === "Update File" ? "Patch" : "Write", file: absolute(m[2], cwd) })
      continue
    }
    m = /^\[([^\]#]+)(?:#[^\]]*)?\]\s*$/.exec(line)
    if (m) {
      section = { tool: "Patch", file: absolute(m[1].trim(), cwd) }
      files.push(section)
      continue
    }
    // Whatever the section did before, the file is gone.
    if (section && /^REM\s*$/.test(line)) section.tool = "Delete"
    m = section && /^MV\s+(\S.*?)\s*$/.exec(line)
    if (m) files.push({ tool: "Write", file: absolute(m[1], cwd) })
  }
  if (files.length) return files
  for (const line of lines) {
    const m = /^# +(\S.*?)\s*$/.exec(line)
    if (m) files.push({ tool: "Patch", file: absolute(m[1], cwd) })
  }
  return files
}

// The edits a file tool call makes, as the tool calls Claude Code's hooks know:
// [{ tool, input }] with tool Edit (one old_string / new_string), Write (a whole
// content), Patch (a change the hook cannot see the text of) or Delete.
//   pi    write { path, content }; edit { path, edits: [{ oldText, newText }] } - one
//         Edit per entry: the hook lets a lone preserved-block insertion through, so
//         it must see each replacement alone;
//   omp   write { path, content }; edit by its edit mode: replace { path, old_string,
//         new_string, replace_all }, patch { path, edits: [{ op, rename, diff }] },
//         hashline / apply_patch / magic { input } (textFiles).
export function hookEdits(toolName, input, cwd) {
  input = input && typeof input === "object" ? input : {}
  const path = typeof input.path === "string" && input.path ? input.path : typeof input.file_path === "string" && input.file_path ? input.file_path : null
  const file = path && absolute(path, cwd)
  if (toolName === "write") return file ? [{ tool: "Write", input: { file_path: file, content: input.content } }] : []
  if (file && Array.isArray(input.edits) && input.edits.length && input.edits.every((e) => e && typeof e.oldText === "string")) {
    return input.edits.map((e) => ({ tool: "Edit", input: { file_path: file, old_string: e.oldText, new_string: e.newText, replace_all: false } }))
  }
  if (file && typeof input.old_string === "string") {
    return [{ tool: "Edit", input: { file_path: file, old_string: input.old_string, new_string: input.new_string, replace_all: !!input.replace_all } }]
  }
  const edits = []
  if (file && Array.isArray(input.edits)) {
    for (const e of input.edits) {
      if (!e || typeof e !== "object") continue
      edits.push({ tool: e.op === "delete" ? "Delete" : e.op === "create" ? "Write" : "Patch", file })
      if (typeof e.rename === "string" && e.rename) edits.push({ tool: "Write", file: absolute(e.rename, cwd) })
    }
  }
  if (typeof input.input === "string") edits.push(...textFiles(input.input, cwd))
  const named = new Set(edits.map((e) => e.file))
  if (file && !named.has(file)) edits.push({ tool: "Patch", file })
  if (Array.isArray(input.paths)) {
    for (const p of input.paths) if (typeof p === "string" && p && !named.has(absolute(p, cwd))) edits.push({ tool: "Patch", file: absolute(p, cwd) })
  }
  return edits.map((e) => ({ tool: e.tool, input: { file_path: e.file } }))
}

function textOf(content) {
  if (typeof content === "string") return content
  if (!Array.isArray(content)) return ""
  return content.filter((c) => c && c.type === "text" && typeof c.text === "string").map((c) => c.text).join("\n")
}

const EDIT_TOOLS = new Set(["edit", "write"])
const SHELL_TOOLS = { bash: "Bash", powershell: "PowerShell" }
const TAG = "[ElastiCORE agent kit] "

export default function elasticore(pi) {
  // omp loads pi extensions unchanged but differs where it matters: tool_result
  // may return additionalContext (delivered outside the tool output), and its stop
  // boundary is session_stop, which carries stop_hook_active itself. omp's
  // ExtensionAPI has zod and logger; pi's has neither.
  const omp = !!(pi && (pi.zod || pi.logger))
  // Claude Code's stop_hook_active on pi: set while the run is the continuation
  // this extension asked for, so the hook never sends it back twice in a row.
  const continuing = new Set()

  // omp runs task subagents as sessions of their own, with this factory bound to
  // each. Claude Code reports a subagent's tool calls under the main session,
  // where the kit's Stop reminder looks: use the main session's id.
  const sid = (ctx, fallback) => {
    let id = null
    try {
      id = ctx.sessionManager.getSessionId() || null
    } catch {}
    id = id || fallback || "pi"
    const kind = ctx && ctx.agent && ctx.agent.kind
    if (kind === "main") globalThis.__elasticoreMainSession = id
    if (kind === "sub" && globalThis.__elasticoreMainSession) return globalThis.__elasticoreMainSession
    return id
  }
  const cwdOf = (ctx) => (ctx && typeof ctx.cwd === "string" && ctx.cwd) || process.cwd()

  pi.on("before_agent_start", async (event, ctx) => {
    // A new prompt from the user ends the continuation.
    try {
      if (event && event.messageType === "user") continuing.delete(sid(ctx))
    } catch {}
  })

  pi.on("tool_call", async (event, ctx) => {
    let refusal = null
    try {
      const session = sid(ctx)
      const cwd = cwdOf(ctx)
      const input = (event && event.input) || {}
      const answers = []
      if (EDIT_TOOLS.has(event.toolName)) {
        for (const e of hookEdits(event.toolName, input, cwd)) {
          answers.push(run("pre-edit", { session_id: session, cwd, hook_event_name: "PreToolUse", tool_name: e.tool, tool_input: e.input }))
          if (answers[answers.length - 1] && answers[answers.length - 1].permissionDecision === "deny") break
        }
      } else if (SHELL_TOOLS[event.toolName] && typeof input.command === "string") {
        answers.push(run("pre-bash", { session_id: session, cwd, tool_use_id: event.toolCallId, hook_event_name: "PreToolUse", tool_name: SHELL_TOOLS[event.toolName], tool_input: { command: input.command } }))
      }
      refusal = answers.find((a) => a && a.permissionDecision === "deny")
    } catch {}
    if (refusal) return { block: true, reason: TAG + (refusal.permissionDecisionReason || "Refused.") }
    return undefined
  })

  pi.on("tool_result", async (event, ctx) => {
    try {
      const session = sid(ctx)
      const cwd = cwdOf(ctx)
      const input = (event && event.input) || {}
      const notes = []
      const add = (answer) => {
        if (answer && answer.additionalContext && !notes.includes(answer.additionalContext)) notes.push(answer.additionalContext)
      }
      if (EDIT_TOOLS.has(event.toolName) && !event.isError) {
        const seen = new Set()
        for (const e of hookEdits(event.toolName, input, cwd)) {
          if (seen.has(e.input.file_path)) continue
          seen.add(e.input.file_path)
          add(run("post-edit", { session_id: session, cwd, hook_event_name: "PostToolUse", tool_name: e.tool, tool_input: e.input }))
        }
      } else if (SHELL_TOOLS[event.toolName] && typeof input.command === "string") {
        // pi: structuredContent.output is the whole output (content keeps only the
        // last 2000 lines / 50 KB) and exit_code the status; a cut output is also
        // saved to details.fullOutputPath. omp: details.exitCode, and a long output
        // cut in the middle (its whole text is an artifact, not a file).
        const structured = event.structuredContent && typeof event.structuredContent === "object" ? event.structuredContent : {}
        const details = event.details && typeof event.details === "object" ? event.details : {}
        const text = typeof structured.output === "string" ? structured.output : textOf(event.content)
        let code = typeof structured.exit_code === "number" ? structured.exit_code : typeof details.exitCode === "number" ? details.exitCode : null
        if (code === null) {
          const m = /exited with code (-?\d+)/i.exec(textOf(event.content))
          if (m) code = Number(m[1])
        }
        const failed = !!event.isError || (code !== null && code !== 0)
        const common = { session_id: session, cwd, tool_use_id: event.toolCallId, tool_name: SHELL_TOOLS[event.toolName], tool_input: { command: input.command } }
        const response = { stdout: text, stderr: "", interrupted: false, isImage: false }
        if (typeof details.fullOutputPath === "string" && existsSync(details.fullOutputPath)) response.persistedOutputPath = details.fullOutputPath
        add(
          run(
            "post-bash",
            failed
              ? { ...common, hook_event_name: "PostToolUseFailure", error: (code !== null ? "Exit code " + code + "\n" : "") + text, is_interrupt: false }
              : { ...common, hook_event_name: "PostToolUse", tool_response: response },
          ),
        )
      }
      if (!notes.length) return undefined
      const note = TAG + notes.join(" ")
      if (omp) return { additionalContext: note }
      const patch = { content: [...(Array.isArray(event.content) ? event.content : []), { type: "text", text: "\n\n" + note }] }
      // Replacing content without structuredContent would drop it.
      if (event.structuredContent !== undefined) patch.structuredContent = event.structuredContent
      return patch
    } catch {
      return undefined
    }
  })

  // pi: the last boundary before the run settles; one continuation at most.
  pi.on("agent_before_settle", async (event, ctx) => {
    try {
      const session = sid(ctx)
      const answer = run("stop", { session_id: session, cwd: cwdOf(ctx), hook_event_name: "Stop", stop_hook_active: continuing.has(session) })
      if (!answer || !answer.additionalContext) {
        continuing.delete(session)
        return undefined
      }
      continuing.add(session)
      const entry = { type: "custom_message", customType: "elasticore-kit", content: TAG + answer.additionalContext, display: true }
      return { entries: [...((event && event.entries) || []), entry], continue: true }
    } catch {
      return undefined
    }
  })

  // omp: the main session's stop hook - Claude Code's Stop in all but name.
  pi.on("session_stop", async (event, ctx) => {
    try {
      const session = sid(ctx, event && event.session_id)
      const answer = run("stop", { session_id: session, cwd: cwdOf(ctx), hook_event_name: "Stop", stop_hook_active: !!(event && event.stop_hook_active) })
      if (!answer || !answer.additionalContext) return undefined
      return { continue: true, additionalContext: TAG + answer.additionalContext }
    } catch {
      return undefined
    }
  })
}
