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
// lets the tool call go ahead: a broken hook never blocks the work. It is said
// once, though, so that the hooks are never off without a word.
import { spawnSync } from "node:child_process"
import { existsSync, mkdirSync, readFileSync, statSync } from "node:fs"
import { homedir, tmpdir, userInfo } from "node:os"
import { delimiter, dirname, isAbsolute, join, resolve } from "node:path"
import { fileURLToPath } from "node:url"

const HERE = dirname(fileURLToPath(import.meta.url))
const HOOKS = [join(HERE, "elasticore-hook.sh"), join(HERE, "..", "hooks", "elasticore-hook.sh")]
const TAG = "[ElastiCORE agent kit] "

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

// The hooks are off - no hook script, a bash that does not run it, an answer that
// is not JSON - or one run took too long: each said once a process, in the host's
// UI when it has one.
const warned = new Set()
function warn(ctx, text, kind = "off") {
  if (warned.has(kind)) return
  warned.add(kind)
  const message = TAG + text + (kind === "off" ? " The kit's refusals and notes are off until this is fixed (pi/README.md)." : "")
  try {
    if (ctx && ctx.ui && typeof ctx.ui.notify === "function") {
      ctx.ui.notify(message, "warning")
      return
    }
  } catch {}
  try {
    console.error(message)
  } catch {}
}

function run(event, payload, ctx) {
  try {
    const hook = process.env.ELASTICORE_KIT_HOOK || HOOKS.find((p) => existsSync(p))
    if (!hook || !existsSync(hook)) {
      warn(ctx, "The hook script elasticore-hook.sh was not found" + (process.env.ELASTICORE_KIT_HOOK ? " at ELASTICORE_KIT_HOOK (" + process.env.ELASTICORE_KIT_HOOK + ")." : " next to the extension (" + HERE + ") or in ../hooks/."))
      return null
    }
    mkdirSync(DATA, { recursive: true })
    const r = spawnSync(BASH, [hook, event], {
      input: JSON.stringify(payload),
      encoding: "utf8",
      timeout: 15000,
      windowsHide: true,
      env: { ...process.env, CLAUDE_PLUGIN_DATA: DATA },
    })
    const stdout = (r.stdout || "").trim()
    if (r.error && r.error.code === "ETIMEDOUT") {
      warn(ctx, "The hook script took more than 15 s for " + event + " (a very long command output?) and was stopped: what it had to say about that call is lost.", "slow")
      return null
    }
    if (r.error) {
      warn(ctx, "Could not run the hook script with " + BASH + " (" + (r.error.code || r.error.message) + ")." + (process.platform === "win32" ? " It needs Git for Windows' Git Bash." : ""))
      return null
    }
    if (r.signal) {
      warn(ctx, "The hook script was stopped (" + r.signal + ") running " + event + " with " + BASH + ".")
      return null
    }
    if (r.status !== 0 && !stdout) {
      const why = String(r.stderr || "").trim().split(/\r?\n/)[0] || "no output"
      warn(ctx, "The hook script failed with exit code " + r.status + " running " + event + " with " + BASH + ": " + why.slice(0, 200))
      return null
    }
    const line = stdout.split("\n").pop()
    if (!line) return null
    try {
      return JSON.parse(line).hookSpecificOutput || null
    } catch {
      warn(ctx, "The hook script answered something that is not JSON running " + event + " with " + BASH + ".")
      return null
    }
  } catch {
    return null
  }
}

const UNICODE_SPACES = /[\u00A0\u2000-\u200A\u202F\u205F\u3000]/g

// A path a tool was given, as the host reads it before it touches the file, made
// absolute against the session's directory - a model may pass src/main/... and
// the hook script matches */src/main/.... pi (normalizePath) and omp (expandPath)
// drop a leading "@" and a stray ":", read a file:// URL, expand "~", and on
// Windows take /c/..., /mnt/c/... and /cygdrive/c/... for C:\.... A literal
// "@name" that exists is kept, as omp keeps it.
export function absolute(path, cwd) {
  let p = String(path).replace(UNICODE_SPACES, " ")
  if (/^:(?=[/\\~]|\.\.?[/\\]|[A-Za-z]:)/.test(p)) p = p.slice(1)
  if (p.startsWith("@") && p.length > 1 && !existsSync(isAbsolute(p) ? p : resolve(cwd, p))) p = p.slice(1)
  if (/^file:\/\//i.test(p)) {
    try {
      p = fileURLToPath(p)
    } catch {}
  }
  if (process.platform === "win32") {
    if (p.startsWith("\\\\?\\")) p = p.slice(4)
    if (p.startsWith("/") && !p.startsWith("//") && !p.includes("\\")) {
      const m = /^\/(?:mnt\/|cygdrive\/)?([a-z])(?:\/(.*))?$/i.exec(p)
      if (m) p = m[1].toUpperCase() + ":\\" + (m[2] || "").replace(/\//g, "\\")
    }
  }
  if (p === "~") p = homedir()
  else if (p.startsWith("~/") || (process.platform === "win32" && p.startsWith("~\\"))) p = join(homedir(), p.slice(2))
  return isAbsolute(p) ? resolve(p) : resolve(cwd, p)
}

// A hashline section header's path: "[P]" or "[P#TAG]" (TAG four hex digits; a "#"
// inside P stays), P maybe quoted; omp's older "¶P#TAG" too.
function hashlinePath(line) {
  let body = null
  let m = /^\[(.+)\]\s*$/.exec(line)
  if (m) body = m[1]
  else if ((m = /^\s*\u00B6+(.+?)\s*$/.exec(line))) body = m[1]
  if (body === null) return null
  const tagged = /#[0-9a-fA-F]{4}$/.test(body.trim())
  let p = body.trim().replace(/#[0-9a-fA-F]{4}$/, "")
  if (p.length >= 2 && (p[0] === '"' || p[0] === "'") && p[0] === p[p.length - 1]) p = p.slice(1, -1)
  return p ? { path: p, tagged } : null
}

// The files a text payload of omp's edit tool names, each with the tool the hook
// script takes it for:
//   apply_patch  "*** Add File: P" and "*** Move to: P" give P a whole new content
//                (Write), "*** Update File: P" changes it (Patch), "*** Delete File: P"
//                deletes it (Delete) - as Codex's apply_patch;
//   sloppy       "*** Edit File: P" and "*** Update File: P all" change P (Patch);
//   hashline     a "[P#TAG]" section changes P (Patch), or deletes it with a REM line
//                (Delete); its "MV DEST" moves it onto DEST (Write);
//   magic        a "# P" section describes a change to P (Patch).
// A Patch is never the one-block Edit the hook lets into a generated file.
export function textFiles(text, cwd) {
  const lines = String(text || "").split(/\r?\n/)
  // "[word]" alone is a hashline header only in a hashline payload: one with a
  // tagged header or a hashline op.
  const hashline = lines.some((l) => /^(PUT|CUT|REM|MV)\b/.test(l)) || lines.some((l) => (hashlinePath(l) || {}).tagged)
  const files = []
  let section = null
  for (const line of lines) {
    let m = /^\*\*\* (Add|Update|Edit|Delete) File: (.+?)(?: all)?\s*$/.exec(line)
    if (m) {
      section = null
      files.push({ tool: m[1] === "Delete" ? "Delete" : m[1] === "Add" ? "Write" : "Patch", file: absolute(m[2], cwd) })
      continue
    }
    m = /^\*\*\* Move to: (.+?)\s*$/.exec(line)
    if (m) {
      files.push({ tool: "Write", file: absolute(m[1], cwd) })
      continue
    }
    const header = hashline && hashlinePath(line)
    if (header) {
      section = { tool: "Patch", file: absolute(header.path, cwd) }
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

// The patch text of a Codex-style apply_patch shell command, which omp's bash tool
// hands to its apply_patch tool: apply_patch <<'EOF' ... EOF, or the patch quoted.
export function shellPatch(command) {
  const c = String(command || "")
  if (!/^\s*apply_patch(?:\s|$)/.test(c)) return null
  let m = /^\s*apply_patch\s*<<-?\s*(['"]?)([A-Za-z_][\w-]*)\1[ \t]*\n([\s\S]*?)\n[ \t]*\2[ \t]*\s*$/.exec(c)
  if (m) return m[3]
  m = /^\s*apply_patch\s+'([^']*)'\s*$/.exec(c)
  if (m) return m[1]
  m = /^\s*apply_patch\s+"((?:[^"\\]|\\[\s\S])*)"\s*$/.exec(c)
  if (m) return m[1].replace(/\\([\\"$`\n])/g, (_, e) => (e === "\n" ? "" : e))
  return c
}

// The edits a file tool call makes, as the tool calls Claude Code's hooks know:
// [{ tool, input }] with tool Edit (one old_string / new_string), MultiEdit,
// Write (a whole content), Patch (a change the hook cannot see the text of) or
// Delete.
//   pi    write { path, content }; edit { path, edits: [{ oldText, newText }] } - one
//         entry an Edit, which lets a lone preserved-block insertion through; several
//         one MultiEdit, as Claude Code sends them;
//   omp   write { path, content }; edit by its edit mode: replace { path, old_string,
//         new_string, replace_all }, patch { path, edits: [{ op, rename, diff }] },
//         hashline / apply_patch / sloppy / magic { input } (textFiles).
export function hookEdits(toolName, input, cwd) {
  input = input && typeof input === "object" ? input : {}
  const path = typeof input.path === "string" && input.path ? input.path : typeof input.file_path === "string" && input.file_path ? input.file_path : null
  const file = path && absolute(path, cwd)
  if (toolName === "write") return file ? [{ tool: "Write", input: { file_path: file, content: input.content } }] : []
  if (file && Array.isArray(input.edits) && input.edits.length && input.edits.every((e) => e && typeof e.oldText === "string")) {
    if (input.edits.length === 1) {
      const e = input.edits[0]
      return [{ tool: "Edit", input: { file_path: file, old_string: e.oldText, new_string: e.newText, replace_all: false } }]
    }
    return [{ tool: "MultiEdit", input: { file_path: file, edits: input.edits.map((e) => ({ old_string: e.oldText, new_string: e.newText, replace_all: false })) } }]
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
  const text = typeof input.input === "string" ? input.input : typeof input._input === "string" ? input._input : null
  if (text !== null) edits.push(...textFiles(text, cwd))
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

function isFile(path) {
  try {
    return statSync(path).isFile()
  } catch {
    return false
  }
}

const EDIT_TOOLS = new Set(["edit", "write"])
const SHELL_TOOLS = { bash: "Bash", powershell: "PowerShell" }
// omp's staged-preview commands, as a tool of their own or the first word of a bash command.
const STAGED = /^\s*(resolve|reject)(?:\s|$)/

export default function elasticore(pi) {
  // omp loads pi extensions unchanged but differs where it matters: tool_result
  // may return additionalContext (delivered outside the tool output), and its stop
  // boundary is session_stop, which carries stop_hook_active itself. omp's
  // ExtensionAPI has arktype (its own schema library), zod and logger; pi's none.
  const omp = !!(pi && (pi.arktype || (pi.zod && pi.logger)))
  // Claude Code's stop_hook_active on pi: set while the run is the continuation
  // this extension asked for, so the hook never sends it back twice in a row.
  const continuing = new Set()
  // omp's ast_edit previews a rewrite, and the resolve command applies the newest
  // pending preview (reject discards it): per session, the pending ast_edit
  // previews, newest last - the files each would change, and its refusal if one
  // of them is a file the generator owns.
  const previews = new Map()
  const pending = (session) => {
    if (!previews.has(session)) previews.set(session, [])
    return previews.get(session)
  }

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
  // The folder a shell command runs in: omp's bash takes a cwd of its own.
  const shellCwd = (input, cwd) => (typeof input.cwd === "string" && input.cwd ? absolute(input.cwd, cwd) : cwd)

  const preEdits = (session, cwd, edits, ctx) => {
    for (const e of edits) {
      const answer = run("pre-edit", { session_id: session, cwd, hook_event_name: "PreToolUse", tool_name: e.tool, tool_input: e.input }, ctx)
      if (answer && answer.permissionDecision === "deny") return answer
    }
    return null
  }
  const postEdits = (session, cwd, edits, ctx, notes) => {
    const seen = new Set()
    for (const e of edits) {
      if (seen.has(e.input.file_path)) continue
      seen.add(e.input.file_path)
      const answer = run("post-edit", { session_id: session, cwd, hook_event_name: "PostToolUse", tool_name: e.tool, tool_input: e.input }, ctx)
      if (answer && answer.additionalContext && !notes.includes(answer.additionalContext)) notes.push(answer.additionalContext)
    }
  }
  const patches = (files) => files.map((f) => ({ tool: "Patch", input: { file_path: f } }))
  const stagedCommand = (event) => {
    if (!omp) return null
    if (event.toolName === "resolve" || event.toolName === "reject") return event.toolName
    const command = SHELL_TOOLS[event.toolName] && event.input && event.input.command
    const m = typeof command === "string" && STAGED.exec(command)
    return m ? m[1] : null
  }

  pi.on("session_start", async (event, ctx) => {
    // A cheap run of the hook script: a bash that cannot run it is said at once.
    try {
      run("stop", { session_id: "elasticore-self-test", hook_event_name: "Stop", stop_hook_active: true }, ctx)
    } catch {}
  })

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
      const staged = stagedCommand(event)
      if (staged) {
        const top = pending(session).at(-1)
        if (staged === "resolve" && top && top.refusal) refusal = top.refusal
      } else if (EDIT_TOOLS.has(event.toolName)) {
        refusal = preEdits(session, cwd, hookEdits(event.toolName, input, cwd), ctx)
      } else if (event.toolName === "ast_edit" && Array.isArray(input.paths)) {
        // The files it names; a folder or glob waits for the preview's list.
        const files = input.paths.filter((p) => typeof p === "string" && p).map((p) => absolute(p, cwd)).filter(isFile)
        refusal = preEdits(session, cwd, patches(files), ctx)
      } else if (SHELL_TOOLS[event.toolName] && typeof input.command === "string") {
        const dir = shellCwd(input, cwd)
        const patch = shellPatch(input.command)
        if (patch !== null) {
          refusal = preEdits(session, dir, textFiles(patch, dir).map((e) => ({ tool: e.tool, input: { file_path: e.file } })), ctx)
        } else {
          refusal = run("pre-bash", { session_id: session, cwd: dir, tool_use_id: event.toolCallId, hook_event_name: "PreToolUse", tool_name: SHELL_TOOLS[event.toolName], tool_input: { command: input.command } }, ctx)
        }
      }
    } catch {}
    if (refusal && refusal.permissionDecision === "deny") return { block: true, reason: TAG + (refusal.permissionDecisionReason || "Refused.") }
    return undefined
  })

  pi.on("tool_result", async (event, ctx) => {
    try {
      const session = sid(ctx)
      const cwd = cwdOf(ctx)
      const input = (event && event.input) || {}
      const notes = []
      const staged = stagedCommand(event)
      if (staged) {
        // The newest preview applied or discarded: an applied one's files get their notes.
        const top = !event.isError && pending(session).pop()
        if (top && staged === "resolve") postEdits(session, cwd, patches(top.files), ctx, notes)
      } else if (EDIT_TOOLS.has(event.toolName) && !event.isError) {
        postEdits(session, cwd, hookEdits(event.toolName, input, cwd), ctx, notes)
      } else if (event.toolName === "ast_edit" && !event.isError) {
        // The preview lists the files the rewrite would change: details.files,
        // relative to the session's folder, and a [P#TAG] header each.
        const details = event.details && typeof event.details === "object" ? event.details : {}
        const base = typeof details.cwd === "string" && details.cwd ? details.cwd : cwd
        const files = new Set()
        for (const f of Array.isArray(details.files) ? details.files : []) if (typeof f === "string" && f && !/^[a-z][a-z0-9+.-]*:\/\//i.test(f)) files.add(absolute(f, base))
        for (const line of textOf(event.content).split(/\r?\n/)) {
          const header = hashlinePath(line)
          if (header && header.tagged) files.add(absolute(header.path, base))
        }
        if (files.size && details.applied !== true) {
          const refusal = preEdits(session, cwd, patches([...files]), ctx)
          pending(session).push({ files: [...files], refusal })
          if (refusal) notes.push("This preview changes a file the ElastiCORE generator owns, so resolve will be refused - reject it and make the change in the DSL. " + (refusal.permissionDecisionReason || ""))
        }
      } else if (SHELL_TOOLS[event.toolName] && typeof input.command === "string" && !input.async) {
        const dir = shellCwd(input, cwd)
        const patch = shellPatch(input.command)
        if (patch !== null) {
          if (!event.isError) postEdits(session, dir, textFiles(patch, dir).map((e) => ({ tool: e.tool, input: { file_path: e.file } })), ctx, notes)
        } else {
          // pi: structuredContent.output is the whole output (content keeps only the
          // last 2000 lines / 50 KB) and exit_code the status; a cut output is also
          // saved to details.fullOutputPath. omp: details.exitCode, and a long output
          // cut in the middle (its whole text is an artifact, not a file). An async
          // omp command comes back before it ran: nothing to read.
          const structured = event.structuredContent && typeof event.structuredContent === "object" ? event.structuredContent : {}
          const details = event.details && typeof event.details === "object" ? event.details : {}
          const text = typeof structured.output === "string" ? structured.output : textOf(event.content)
          let code = typeof structured.exit_code === "number" ? structured.exit_code : typeof details.exitCode === "number" ? details.exitCode : null
          if (code === null) {
            const m = /exited with code (-?\d+)/i.exec(textOf(event.content))
            if (m) code = Number(m[1])
          }
          const failed = !!event.isError || (code !== null && code !== 0)
          const common = { session_id: session, cwd: dir, tool_use_id: event.toolCallId, tool_name: SHELL_TOOLS[event.toolName], tool_input: { command: input.command } }
          const response = { stdout: text, stderr: "", interrupted: false, isImage: false }
          if (typeof details.fullOutputPath === "string" && existsSync(details.fullOutputPath)) response.persistedOutputPath = details.fullOutputPath
          const answer = run(
            "post-bash",
            failed
              ? { ...common, hook_event_name: "PostToolUseFailure", error: (code !== null ? "Exit code " + code + "\n" : "") + text, is_interrupt: false }
              : { ...common, hook_event_name: "PostToolUse", tool_response: response },
            ctx,
          )
          if (answer && answer.additionalContext) notes.push(answer.additionalContext)
        }
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

  if (!omp) {
    // pi: the last boundary before the run settles; one continuation at most. A run
    // that ended in an error or was aborted is not sent back - Claude Code sends no
    // Stop then either.
    pi.on("agent_before_settle", async (event, ctx) => {
      try {
        if (event && typeof event.outcome === "string" && event.outcome !== "completed") return undefined
        const session = sid(ctx)
        const answer = run("stop", { session_id: session, cwd: cwdOf(ctx), hook_event_name: "Stop", stop_hook_active: continuing.has(session) }, ctx)
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
  } else {
    // omp: the main session's stop hook - Claude Code's Stop in all but name.
    pi.on("session_stop", async (event, ctx) => {
      try {
        const session = sid(ctx, event && event.session_id)
        const answer = run("stop", { session_id: session, cwd: cwdOf(ctx), hook_event_name: "Stop", stop_hook_active: !!(event && event.stop_hook_active) }, ctx)
        if (!answer || !answer.additionalContext) return undefined
        return { continue: true, additionalContext: TAG + answer.additionalContext }
      } catch {
        return undefined
      }
    })
  }
}
