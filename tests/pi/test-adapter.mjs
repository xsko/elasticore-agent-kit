// Drives the pi / oh-my-pi extension (plugins/elasticore/pi/elasticore.js) the way the
// two hosts do - event payloads recorded from pi 1.6.1 and omp 19.2.1 - against the
// kit's real hook script, and checks what reaches the host: a block, a note appended
// to the result (pi) or returned as additionalContext (omp), one continuation at the
// settle boundary (pi) or session_stop (omp). Then pi/install.sh, and the two
// package.json files against the plugin manifests.
//
// usage: node tests/pi/test-adapter.mjs      Node 18 or later, no packages
// The fixtures go to a fresh directory under the system temp directory, left for inspection.
import { spawnSync } from "node:child_process"
import { existsSync, mkdirSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import { dirname, join, resolve } from "node:path"
import { fileURLToPath, pathToFileURL } from "node:url"

const here = dirname(fileURLToPath(import.meta.url))
const repo = resolve(here, "..", "..")
const adapter = join(repo, "plugins", "elasticore", "pi", "elasticore.js")
const work = mkdtempSync(join(tmpdir(), "elasticore-pi-test-"))
delete process.env.ELASTICORE_ALLOW_GENERATED_EDITS
delete process.env.ELASTICORE_ALLOW_FORCE
delete process.env.ELASTICORE_ALLOW_HISTORY_EDITS
delete process.env.ELASTICORE_KIT_HOOK // the extension must find plugins/elasticore/hooks/ itself

let passed = 0
let failed = 0
function check(name, ok, detail) {
  if (ok) {
    passed++
    return
  }
  failed++
  console.log("FAIL " + name + (detail === undefined ? "" : "\n  " + String(detail).slice(0, 600)))
  if (process.env.GITHUB_ACTIONS === "true") console.log("::error title=pi adapter test failed::" + name)
}
function write(path, text) {
  mkdirSync(dirname(path), { recursive: true })
  writeFileSync(path, text)
}
const show = (x) => JSON.stringify(x)

// --- fixtures ----------------------------------------------------------------------
const project = join(work, "shop")
write(join(project, "build.gradle"), "plugins { id 'io.elasticore' version '3.0.0' }\n\nelasticore {\n    architecture = 'hexagonal'\n    language     = 'java'\n}\n")
const managedRel = "src/main/java/com/acme/shop/ProductDTO.java"
const managed = join(project, managedRel)
write(managed, "//ecd:-1375193215H20261020123214_V3.0\npackage com.acme.shop;\n\npublic class ProductDTO {\n}\n")
const ownRel = "src/main/java/com/acme/shop/ShopApplication.java"
write(join(project, ownRel), "package com.acme.shop;\n\npublic class ShopApplication {}\n")
const modelRel = "src/main/resources/blueprint/shop/model/entity.yml"
write(join(project, modelRel), "entity:\n  Product:\n    fields:\n      name: string(100)!\n")
const built = "> Task :elcore3\n=== elcore3: 1 written / 41 unchanged / 14 skipped / 0 failed ===\n> Task :compileJava\nBUILD SUCCESSFUL in 9s\n"
// A project on the merge: generated files have no //ecd: line and are named in the merge base.
const merging = join(work, "merging")
const mergedFile = join(merging, "src", "main", "java", "com", "acme", "rating", "GoldenRunController.java")
write(join(merging, "build.gradle"), "plugins { id 'io.elasticore' version '3.0.261127' }\n")
write(mergedFile, "package com.acme.rating;\n\npublic class GoldenRunController {}\n")
write(join(merging, ".elasticore", "generated-base.zip"), "PK\u0003\u0004....src/main/java/com/acme/rating/GoldenRunController.javapackage com.acme.rating;PK\u0001\u0002\n")

// --- a fake host -------------------------------------------------------------------
let loads = 0
async function host(kind, session, options = {}) {
  const handlers = {}
  const api = { on: (name, fn) => (handlers[name] ||= []).push(fn), sendMessage() {} }
  if (kind === "omp") api.logger = {}
  const mod = await import(pathToFileURL(options.file || adapter).href + "?" + kind + ++loads)
  mod.default(api)
  const ctx = (agent, cwd) => ({ cwd: cwd || options.cwd || project, sessionManager: { getSessionId: () => (agent && agent.id) || session }, agent })
  const main = kind === "omp" ? { kind: "main", id: "Main" } : undefined
  const emit = async (name, event, agent, cwd) => {
    let result
    const c = ctx(agent === undefined ? main : agent, cwd)
    if (agent === undefined && main) c.sessionManager = { getSessionId: () => session }
    for (const fn of handlers[name] || []) result = (await fn({ type: name, ...event }, c)) ?? result
    return result
  }
  return { emit, handlers }
}
let sessions = 0
const session = (kind) => kind + "-test-" + process.pid + "-" + ++sessions
const settle = (h) => h.emit("agent_before_settle", { outcome: "completed", entries: [], continue: false })
const edited = (rel, from, to, id) => ({ toolName: "edit", toolCallId: id || "e1", input: { path: rel, edits: [{ oldText: from, newText: to }] }, content: [{ type: "text", text: "Successfully replaced 1 block(s)." }], details: { diff: "" }, isError: false })
const shell = (command, output, exit, extra = {}) => ({
  toolName: "bash",
  toolCallId: extra.id || "b1",
  input: { command },
  content: [{ type: "text", text: output + (exit ? "\n\n\nCommand exited with code " + exit : "") }],
  structuredContent: extra.structured === false ? undefined : { output, truncated: false, exit_code: exit, wall_time_seconds: 1 },
  details: extra.details || {},
  isError: exit !== 0,
})
const lastText = (result) => result && Array.isArray(result.content) ? result.content[result.content.length - 1].text : ""

// --- pi ----------------------------------------------------------------------------
{
  const s = session("pi")
  const pi = await host("pi", s)
  check("pi: the extension registers tool_call, tool_result, agent_before_settle and session_stop", ["tool_call", "tool_result", "agent_before_settle", "session_stop"].every((n) => pi.handlers[n]), Object.keys(pi.handlers))

  let r = await pi.emit("tool_call", { toolName: "edit", toolCallId: "c1", input: { path: managedRel, edits: [{ oldText: "public class ProductDTO {\n}", newText: "public class ProductDTO {\n    int age;\n}" }] } })
  check("pi: an edit of a //ecd: file is blocked with the hook's reason", r && r.block === true && /^\[ElastiCORE agent kit\] ElastiCORE generates .*ProductDTO\.java from the DSL/.test(r.reason), show(r))
  r = await pi.emit("tool_call", { toolName: "edit", toolCallId: "c2", input: { path: managedRel, edits: [{ oldText: "public class ProductDTO {\n}", newText: "public class ProductDTO {\n    // !----------\n    int age;\n    // ------------!\n}" }] } })
  check("pi: the one preserved-block insertion goes through", r === undefined, show(r))
  r = await pi.emit("tool_call", { toolName: "edit", toolCallId: "c3", input: { path: managedRel, edits: [{ oldText: "public class ProductDTO {\n}", newText: "public class ProductDTO {\n    // !----------\n    int age;\n    // ------------!\n}" }, { oldText: "package com.acme.shop;", newText: "package com.acme.shop2;" }] } })
  check("pi: a block insertion with another replacement beside it is blocked", r && r.block === true, show(r))
  r = await pi.emit("tool_call", { toolName: "write", toolCallId: "c4", input: { path: managed, content: "class ProductDTO {}\n" } })
  check("pi: a write over a //ecd: file is blocked", r && r.block === true && /from the DSL/.test(r.reason), show(r))
  r = await pi.emit("tool_call", { toolName: "edit", toolCallId: "c5", input: { path: ownRel, edits: [{ oldText: "{}", newText: "{ }" }] } })
  check("pi: an edit of a hand-written file goes through", r === undefined, show(r))
  r = await pi.emit("tool_call", { toolName: "write", toolCallId: "c6", input: { path: mergedFile, content: "public class GoldenRunController {}\n" } })
  check("pi: a write over a merged generated file is blocked", r && r.block === true && /Write replaces all of it/.test(r.reason), show(r))
  r = await pi.emit("tool_call", { toolName: "edit", toolCallId: "c7", input: { path: mergedFile, edits: [{ oldText: "{}", newText: "{ }" }] } })
  check("pi: an edit of a merged generated file goes through", r === undefined, show(r))
  r = await pi.emit("tool_call", { toolName: "read", toolCallId: "c8", input: { path: managedRel } })
  check("pi: a read goes through", r === undefined, show(r))

  r = await pi.emit("tool_call", { toolName: "bash", toolCallId: "c9", input: { command: "./gradlew elcore3 -Pforce" } })
  check("pi: -Pforce is blocked", r && r.block === true && /-Pforce makes the ElastiCORE generator overwrite/.test(r.reason), show(r))
  r = await pi.emit("tool_call", { toolName: "bash", toolCallId: "c10", input: { command: "./gradlew compileJava" } })
  check("pi: ./gradlew compileJava goes through", r === undefined, show(r))
  r = await pi.emit("tool_call", { toolName: "powershell", toolCallId: "c11", input: { command: ".\\gradlew.bat elcore3 -Pforce" } })
  check("pi: and -Pforce through the powershell tool", r && r.block === true, show(r))

  // A post to xsko/ElastiCORE is stopped once a session, to show the user the draft.
  const post = "gh issue create --repo xsko/ElastiCORE --title 'x' --body 'y'"
  r = await pi.emit("tool_call", { toolName: "bash", toolCallId: "c12", input: { command: post } })
  check("pi: gh issue create to xsko/ElastiCORE is blocked the first time", r && r.block === true && /public repository/.test(r.reason) && /explicit yes/.test(r.reason), show(r))
  r = await pi.emit("tool_call", { toolName: "bash", toolCallId: "c13", input: { command: post } })
  check("pi: and goes through the second time", r === undefined, show(r))
  r = await pi.emit("tool_call", { toolName: "bash", toolCallId: "c14", input: { command: "gh issue list --repo xsko/ElastiCORE --search sort" } })
  check("pi: reading the issues goes through", r === undefined, show(r))

  // A DSL edit gets the note, appended after the tool's own content.
  r = await pi.emit("tool_result", edited(modelRel, "string(100)", "string(120)"))
  check("pi: a DSL edit gets the note, after the result's own text", r && r.content.length === 2 && r.content[0].text.startsWith("Successfully") && /\[ElastiCORE agent kit\] You changed the ElastiCORE model/.test(r.content[1].text), show(r))
  r = await pi.emit("tool_result", edited(modelRel, "string(120)", "string(130)"))
  check("pi: once per change", r === undefined, show(r))
  r = await pi.emit("tool_result", edited(ownRel, "{}", "{ }"))
  check("pi: an edit of a hand-written file gets no note", r === undefined, show(r))

  // Settling with the change not built: one continuation, then none.
  r = await settle(pi)
  check("pi: settling with the model not built continues once", r && r.continue === true && r.entries.length === 1 && r.entries[0].type === "custom_message" && /no successful Gradle build/.test(r.entries[0].content), show(r))
  r = await settle(pi)
  check("pi: and not a second time", r === undefined, show(r))
  r = await settle(pi)
  check("pi: nor after that", r === undefined, show(r))
}
{
  // A successful build ends the change: the whole output is in structuredContent.
  const pi = await host("pi", session("pi"))
  await pi.emit("tool_result", edited(modelRel, "a", "b"))
  let r = await pi.emit("tool_result", shell("./gradlew compileJava", built, 0))
  check("pi: a build that compiled the change gets no note", r === undefined, show(r))
  r = await settle(pi)
  check("pi: and leaves nothing to send back", r === undefined, show(r))
}
{
  const pi = await host("pi", session("pi"))
  await pi.emit("tool_result", edited(modelRel, "a", "b"))
  const legacy = "> Task :elcore\n[WARN] DSL Validation Warnings:\n  - x\nBUILD FAILED in 3s\n"
  const r = await pi.emit("tool_result", shell("./gradlew compileJava", legacy, 1))
  check("pi: a failed build reaches the hook as a failure, with its note", r && /2\.x generator \(elcore\) listed DSL validation warnings/.test(lastText(r)), show(r))
  check("pi: and keeps structuredContent", r && r.structuredContent && r.structuredContent.exit_code === 1, show(r && r.structuredContent))
  check("pi: a failed build does not end the change", (await settle(pi)) !== undefined)
}
{
  // pi keeps the last 2000 lines in content and saves the whole output to details.fullOutputPath.
  const pi = await host("pi", session("pi"))
  const saved = join(work, "pi-bash-1.log")
  write(saved, "> Task :elcore3\n=== elcore3: 1 written / 41 unchanged / 14 skipped / 0 failed ===\n" + "x\n".repeat(3000) + "> Task :compileJava\nBUILD SUCCESSFUL in 9s\n")
  await pi.emit("tool_result", edited(modelRel, "a", "b"))
  await pi.emit("tool_result", shell("./gradlew compileJava", "x\nx\n> Task :compileJava\nBUILD SUCCESSFUL in 9s\n", 0, { structured: false, details: { fullOutputPath: saved, truncation: { truncatedBy: "lines" } } }))
  check("pi: a cut output is read from the file pi saved it to", (await settle(pi)) === undefined)
}
{
  // A new prompt after a continuation: the next settle may send back again.
  const pi = await host("pi", session("pi"))
  await pi.emit("tool_result", edited(modelRel, "a", "b"))
  await settle(pi)
  await settle(pi)
  await pi.emit("before_agent_start", { messageType: "user", prompt: "go on" })
  await pi.emit("tool_result", edited(modelRel, "b", "c"))
  check("pi: after a new prompt and another DSL edit, settling continues again", (await settle(pi)) !== undefined)
}
{
  // ElastiCORE itself falling short: a compile error in a generated file.
  const pi = await host("pi", session("pi"))
  const failing = "> Task :elcore3\n=== elcore3: 1 written / 0 unchanged / 0 skipped / 0 failed ===\n> Task :compileJava FAILED\n" + managed.replace(/\\/g, "/") + ":4: error: cannot find symbol\nBUILD FAILED in 5s\n"
  const r = await pi.emit("tool_result", shell("./gradlew compileJava", failing, 1))
  check("pi: a compile error in a generated file suggests the report-issue skill", r && /files ElastiCORE generated/.test(lastText(r)) && /report-issue skill/.test(lastText(r)), show(r))
}

// --- a build whose output goes to a file: tool_use_id and cwd reach the hook --------
{
  const pi = await host("pi", session("pi"))
  const logs = join(project, "build", "logs")
  mkdirSync(logs, { recursive: true })
  await pi.emit("tool_result", edited(modelRel, "a", "b"))
  const command = "./gradlew compileJava > build/logs/build.log 2>&1"
  await pi.emit("tool_call", { toolName: "bash", toolCallId: "redir-1", input: { command } })
  write(join(logs, "build.log"), built)
  await pi.emit("tool_result", { ...shell(command, "", 0), toolCallId: "redir-1" })
  check("pi: a build whose output went to a file (> f, relative to the session's folder) is read from the file", (await settle(pi)) === undefined)
}

// --- contributor mode: a checkout of ElastiCORE itself ------------------------------
const checkout = join(work, "checkout")
write(join(checkout, "settings.gradle"), "rootProject.name = 'elasticore'\ninclude('elasticore-project:elasticore-base')\n")
write(join(checkout, "changes", "README.md"), "# Change fragments\n")
const coHistory = join(checkout, "elasticore-project", "elasticore-base", "src", "main", "resources", "elasticore-guide", "elasticore-history.md")
write(coHistory, "# History\n")
const coManaged = join(checkout, "elasticore-project", "elasticore-template", "src", "main", "java", "ProductDTO.java")
write(coManaged, "//ecd:-1375193215H20261020123214_V3.0\npublic class ProductDTO {}\n")
const git = (...args) => spawnSync("git", ["-C", checkout, "-c", "user.name=kit-test", "-c", "user.email=kit-test@example.invalid", "-c", "commit.gpgsign=false", ...args], { encoding: "utf8" })
let gitReady = git("init", "-q").status === 0
gitReady = gitReady && git("add", "-A").status === 0 && git("commit", "-q", "-m", "base").status === 0
gitReady = gitReady && git("update-ref", "refs/remotes/origin/main", "HEAD").status === 0 && git("checkout", "-q", "-b", "feature").status === 0
write(join(checkout, "elasticore-project", "elasticore-base", "src", "main", "resources", "x.txt"), "a change\n")
gitReady = gitReady && git("add", "-A").status === 0 && git("commit", "-q", "-m", "change").status === 0
{
  const pi = await host("pi", session("pi"), { cwd: checkout })
  let r = await pi.emit("tool_call", { toolName: "edit", toolCallId: "k1", input: { path: coManaged, edits: [{ oldText: "{}", newText: "{ }" }] } })
  check("a checkout: an edit of a sample's generated file goes through", r === undefined, show(r))
  r = await pi.emit("tool_call", { toolName: "write", toolCallId: "k2", input: { path: coHistory, content: "x" } })
  check("a checkout: a write of the history is blocked, naming the fragment", r && r.block === true && /changes\/<topic>\.md/.test(r.reason), show(r))
  r = await pi.emit("tool_call", { toolName: "bash", toolCallId: "k3", input: { command: "./gradlew elcore3 -Pforce" } })
  check("a checkout: -Pforce goes through", r === undefined, show(r))
  if (gitReady) {
    r = await pi.emit("tool_call", { toolName: "bash", toolCallId: "k4", input: { command: "git push -u origin feature" } })
    check("a checkout: a push without a fragment, from the session's folder, is blocked once", r && r.block === true && /changes\/<topic>\.md/.test(r.reason), show(r))
    r = await pi.emit("tool_call", { toolName: "bash", toolCallId: "k5", input: { command: "git push -u origin feature" } })
    check("a checkout: and goes through the second time", r === undefined, show(r))
    const user = await host("pi", session("pi"))
    r = await user.emit("tool_call", { toolName: "bash", toolCallId: "k6", input: { command: "git -C " + checkout + " push" } })
    check("a user project's session: the same push goes through (the checkout is told by the session's folder)", r === undefined, show(r))
  } else {
    check("git can make the checkout's commits", false, git("status").stderr)
  }
}

// --- omp ---------------------------------------------------------------------------
{
  const s = session("omp")
  const omp = await host("omp", s)
  let r = await omp.emit("tool_call", { toolName: "edit", toolCallId: "o1", input: { path: managedRel, old_string: "public class ProductDTO {\n}", new_string: "public class ProductDTO {\n    int age;\n}" } })
  check("omp: a replace-mode edit of a //ecd: file is blocked", r && r.block === true && /from the DSL/.test(r.reason), show(r))
  r = await omp.emit("tool_call", { toolName: "edit", toolCallId: "o2", input: { path: managedRel, old_string: "public class ProductDTO {\n}", new_string: "public class ProductDTO {\n    // !----------\n    int age;\n    // ------------!\n}" } })
  check("omp: a replace-mode preserved-block insertion goes through", r === undefined, show(r))
  const hashline = (rel, ops) => ({ input: "*** Begin Patch\n[" + rel + "#52DE]\n" + ops + "\n*** End Patch", path: rel, paths: [rel] })
  r = await omp.emit("tool_call", { toolName: "edit", toolCallId: "o3", input: hashline(managedRel, "PUT 4*:\n+public class ProductDTO {\n+    int age;\n+}") })
  check("omp: a hashline edit of a //ecd: file is blocked", r && r.block === true, show(r))
  r = await omp.emit("tool_call", { toolName: "edit", toolCallId: "o4", input: hashline(managedRel, "REM") })
  check("omp: a hashline REM (a delete) of a //ecd: file goes through", r === undefined, show(r))
  r = await omp.emit("tool_call", { toolName: "edit", toolCallId: "o5", input: hashline(ownRel, "PUT 3*:\n+public class ShopApplication { }") })
  check("omp: a hashline edit of a hand-written file goes through", r === undefined, show(r))
  r = await omp.emit("tool_call", { toolName: "edit", toolCallId: "o6", input: hashline(mergedFile, "PUT 3*:\n+public class GoldenRunController { }") })
  check("omp: a hashline edit of a merged generated file goes through", r === undefined, show(r))
  r = await omp.emit("tool_call", { toolName: "edit", toolCallId: "o7", input: hashline(ownRel, "MV " + mergedFile) })
  check("omp: a hashline MV onto a merged generated file is blocked", r && r.block === true && /Write replaces all of it/.test(r.reason), show(r))

  const applyPatch = (verb, rel) => ({ input: "*** Begin Patch\n*** " + verb + " File: " + rel + "\n@@\n-a\n+b\n*** End Patch" })
  r = await omp.emit("tool_call", { toolName: "edit", toolCallId: "o8", input: applyPatch("Update", managedRel) })
  check("omp: an apply_patch update of a //ecd: file is blocked", r && r.block === true, show(r))
  r = await omp.emit("tool_call", { toolName: "edit", toolCallId: "o9", input: applyPatch("Delete", managedRel) })
  check("omp: an apply_patch delete of a //ecd: file goes through (a delete is how one is restored)", r === undefined, show(r))
  r = await omp.emit("tool_call", { toolName: "edit", toolCallId: "o10", input: applyPatch("Add", mergedFile) })
  check("omp: an apply_patch that adds a merged generated file anew is blocked", r && r.block === true, show(r))

  r = await omp.emit("tool_call", { toolName: "edit", toolCallId: "o11", input: { path: managedRel, edits: [{ diff: "@@\n-}\n+  int age;\n}" }] } })
  check("omp: a patch-mode update of a //ecd: file is blocked", r && r.block === true, show(r))
  r = await omp.emit("tool_call", { toolName: "edit", toolCallId: "o12", input: { path: managedRel, edits: [{ op: "delete" }] } })
  check("omp: a patch-mode delete of a //ecd: file goes through", r === undefined, show(r))
  r = await omp.emit("tool_call", { toolName: "edit", toolCallId: "o13", input: { path: ownRel, edits: [{ rename: mergedFile }] } })
  check("omp: a patch-mode rename onto a merged generated file is blocked", r && r.block === true, show(r))
  r = await omp.emit("tool_call", { toolName: "edit", toolCallId: "o14", input: { input: "# " + managedRel + "\n- Add a field age." } })
  check("omp: a magic-mode change of a //ecd: file is blocked", r && r.block === true, show(r))

  r = await omp.emit("tool_result", { toolName: "edit", toolCallId: "o15", input: { path: modelRel, old_string: "string(100)", new_string: "string(120)" }, content: [{ type: "text", text: "[" + modelRel + "]" }], isError: false })
  check("omp: a DSL edit's note comes as additionalContext, the content left alone", r && /^\[ElastiCORE agent kit\] You changed the ElastiCORE model/.test(r.additionalContext) && r.content === undefined, show(r))
  r = await omp.emit("tool_result", { toolName: "bash", toolCallId: "o16", input: { command: "./gradlew compileJava" }, content: [{ type: "text", text: "BUILD FAILED\n\nCommand exited with code 1" }], details: { exitCode: 1 }, isError: true })
  check("omp: a failed build gets no note it does not need, and does not throw", r === undefined, show(r))
  r = await omp.emit("session_stop", { session_id: s, stop_hook_active: false, turn_id: 3, messages: [] })
  check("omp: session_stop with the model not built continues", r && r.continue === true && /^\[ElastiCORE agent kit\] .*no successful Gradle build/.test(r.additionalContext), show(r))
  r = await omp.emit("session_stop", { session_id: s, stop_hook_active: true, turn_id: 4, messages: [] })
  check("omp: no continuation while stop_hook_active", r === undefined, show(r))
}
{
  // A task subagent's DSL edit counts for the main session, as in Claude Code.
  const s = session("omp")
  const omp = await host("omp", s)
  await omp.emit("tool_call", { toolName: "read", toolCallId: "m0", input: { path: modelRel } })
  const sub = { kind: "sub", name: "elasticore-modeler", depth: 1, parentId: "Main", id: "sub-" + s }
  await omp.emit("tool_result", { toolName: "edit", toolCallId: "m1", input: { path: modelRel, old_string: "a", new_string: "b" }, content: [], isError: false }, sub)
  const r = await omp.emit("session_stop", { session_id: s, stop_hook_active: false, turn_id: 2, messages: [] })
  check("omp: a subagent's DSL edit makes the main session's stop continue", r && r.continue === true, show(r))
}

// --- a broken hook never blocks the work --------------------------------------------
{
  const broken = join(work, "broken-hook.sh")
  write(broken, "#!/usr/bin/env bash\necho 'not json'\nexit 2\n")
  for (const [name, path] of [["a missing hook script", join(work, "no-such-hook.sh")], ["a hook script that answers garbage", broken]]) {
    process.env.ELASTICORE_KIT_HOOK = path
    const pi = await host("pi", session("pi"))
    let r = await pi.emit("tool_call", { toolName: "edit", toolCallId: "x1", input: { path: managedRel, edits: [{ oldText: "a", newText: "b" }] } })
    check(name + ": an edit of a //ecd: file goes through", r === undefined, show(r))
    r = await pi.emit("tool_result", edited(modelRel, "a", "b"))
    check(name + ": no note", r === undefined, show(r))
    check(name + ": no continuation", (await settle(pi)) === undefined)
  }
  delete process.env.ELASTICORE_KIT_HOOK
  const pi = await host("pi", session("pi"))
  let threw = null
  try {
    await pi.emit("tool_call", { toolName: "edit", input: undefined })
    await pi.emit("tool_call", { toolName: "bash", input: { command: 42 } })
    await pi.emit("tool_result", { toolName: "bash", input: { command: "./gradlew build" }, content: "odd" })
    await pi.emit("tool_result", { toolName: "edit", input: { path: modelRel }, isError: true })
    await pi.emit("agent_before_settle", {})
    await pi.emit("session_stop", {})
  } catch (err) {
    threw = err
  }
  check("calls not shaped as recorded do not throw", threw === null, threw && threw.message)
}

// --- pi/install.sh -----------------------------------------------------------------
function findBash() {
  if (process.platform !== "win32") return "bash"
  for (const root of [process.env.ProgramFiles, process.env["ProgramFiles(x86)"], process.env.LOCALAPPDATA && join(process.env.LOCALAPPDATA, "Programs")]) {
    const bash = root && join(root, "Git", "bin", "bash.exe")
    if (bash && existsSync(bash)) return bash
  }
  return "bash"
}
const install = (args, cwd, env) => spawnSync(findBash(), [join(repo, "pi", "install.sh"), ...args], { cwd, env: { ...process.env, ...env }, encoding: "utf8" })
const skillFiles = ["skills/elasticore/SKILL.md", "skills/elasticore/references/quick-reference.md", "skills/report-issue/SKILL.md", "skills/contribute/SKILL.md"]
{
  const agentDir = join(work, "pi-agent")
  let r = install([], work, { PI_CODING_AGENT_DIR: agentDir })
  check("install.sh succeeds for pi", r.status === 0, r.stdout + r.stderr)
  r = install([], work, { PI_CODING_AGENT_DIR: agentDir })
  check("and again over its own copy", r.status === 0, r.stdout + r.stderr)
  const files = ["extensions/elasticore/index.js", "extensions/elasticore/elasticore-hook.sh", ...skillFiles]
  const missing = files.filter((f) => !existsSync(join(agentDir, f)))
  check("install.sh copies the extension, the hook script and the skills into $PI_CODING_AGENT_DIR", missing.length === 0, "missing: " + missing.join(", "))
  check("and no agents for pi, which has no subagents", !existsSync(join(agentDir, "agents")))
  if (process.platform === "win32") {
    const recorded = existsSync(join(agentDir, "extensions/elasticore/bash-path")) ? readFileSync(join(agentDir, "extensions/elasticore/bash-path"), "utf8").trim() : ""
    check("on Windows, install.sh records Git's launcher bin\\bash.exe, not usr\\bin\\bash.exe", /\\bin\\bash\.exe$/i.test(recorded) && !/\\usr\\bin\\/i.test(recorded) && existsSync(recorded), recorded)
  }
  const pi = await host("pi", session("pi"), { file: join(agentDir, "extensions", "elasticore", "index.js") })
  const blocked = await pi.emit("tool_call", { toolName: "edit", toolCallId: "i1", input: { path: managedRel, edits: [{ oldText: "a", newText: "b" }] } })
  check("the installed extension runs the hook script next to it", blocked && blocked.block === true && /from the DSL/.test(blocked.reason), show(blocked))

  const home = join(work, "home")
  r = install([], work, { PI_CODING_AGENT_DIR: "", HOME: home, USERPROFILE: home })
  check("without PI_CODING_AGENT_DIR: ~/.pi/agent", r.status === 0 && existsSync(join(home, ".pi", "agent", "extensions", "elasticore", "index.js")), r.stdout + r.stderr)
  r = install(["--omp"], work, { PI_CODING_AGENT_DIR: "", HOME: home, USERPROFILE: home })
  check("--omp without PI_CODING_AGENT_DIR: ~/.omp/agent", r.status === 0 && existsSync(join(home, ".omp", "agent", "extensions", "elasticore", "index.js")), r.stdout + r.stderr)
}
{
  const proj = join(work, "pi-project")
  mkdirSync(proj, { recursive: true })
  const r = install(["--project"], proj, {})
  check("install.sh --project: .pi/extensions/elasticore/ and .agents/skills/", r.status === 0 && existsSync(join(proj, ".pi", "extensions", "elasticore", "index.js")) && existsSync(join(proj, ".pi", "extensions", "elasticore", "elasticore-hook.sh")) && skillFiles.every((f) => existsSync(join(proj, ".agents", f))), r.stdout + r.stderr)
  check("and tells the user to trust the project", /trust/.test(r.stdout), r.stdout)
}
{
  const proj = join(work, "omp-project")
  mkdirSync(proj, { recursive: true })
  const r = install(["--omp", "--project"], proj, {})
  check("install.sh --omp --project: .omp/extensions/elasticore/, .omp/skills/, .omp/agents/", r.status === 0 && existsSync(join(proj, ".omp", "extensions", "elasticore", "index.js")) && skillFiles.every((f) => existsSync(join(proj, ".omp", f))), r.stdout + r.stderr)
  for (const [name, tools] of [["modeler", "read, grep, glob, edit, write, bash"], ["reviewer", "read, grep, glob, bash"]]) {
    const file = join(proj, ".omp", "agents", "elasticore-" + name + ".md")
    const text = existsSync(file) ? readFileSync(file, "utf8") : ""
    const source = readFileSync(join(repo, "plugins", "elasticore", "agents", name + ".md"), "utf8").replace(/\r\n/g, "\n")
    const body = (t) => t.slice(t.indexOf("\n---\n", 4))
    check("omp agent elasticore-" + name + ": its own name, so that omp's " + name + " stays (omp lets a same-named agent replace its own)", /^---\nname: elasticore-/.test(text) && text.includes("\nname: elasticore-" + name + "\n"), text.slice(0, 200))
    check("omp agent elasticore-" + name + ": omp's tool names", text.includes("\ntools: " + tools + "\n"), text.slice(0, 600))
    check("omp agent elasticore-" + name + ": the description and the instructions of " + name + ".md", text.includes(source.match(/\ndescription: .*\n/)[0]) && body(text) === body(source), "")
  }
}
{
  const r = install(["--unknown"], work, {})
  check("install.sh refuses an unknown option", r.status === 2, r.stdout + r.stderr)
}

// --- the package manifests ---------------------------------------------------------
{
  const json = (rel) => JSON.parse(readFileSync(join(repo, rel), "utf8"))
  const version = json("plugins/elasticore/.claude-plugin/plugin.json").version
  check("plugin.json (Codex) and .codex-plugin/plugin.json have the Claude Code plugin's version", json("plugins/elasticore/plugin.json").version === version && json("plugins/elasticore/.codex-plugin/plugin.json").version === version)
  for (const [rel, base] of [["package.json", ""], ["plugins/elasticore/package.json", "plugins/elasticore"]]) {
    const pkg = json(rel)
    check(rel + " has the plugin's version " + version, pkg.version === version, pkg.version)
    check(rel + " is private, a pi package, with no dependencies", pkg.private === true && (pkg.keywords || []).includes("pi-package") && !pkg.dependencies && !pkg.peerDependencies, show(pkg))
    const paths = [...((pkg.pi && pkg.pi.extensions) || []), ...((pkg.pi && pkg.pi.skills) || []), ...((pkg.omp && pkg.omp.extensions) || [])]
    check(rel + " names the extension and the skills", pkg.pi && pkg.pi.extensions.length > 0 && pkg.pi.skills.length > 0, show(pkg.pi))
    const absent = paths.filter((p) => !existsSync(join(repo, base, p)))
    check(rel + ": every path it names exists", absent.length === 0, "missing: " + absent.join(", "))
    for (const p of (pkg.pi && pkg.pi.skills) || []) check(rel + ": " + p + " is a skill", existsSync(join(repo, base, p, "SKILL.md")))
  }
  check("plugins/elasticore/package.json names the extension for omp", show(json("plugins/elasticore/package.json").omp) === show({ extensions: ["./pi/elasticore.js"] }))
}

console.log(passed + " passed, " + failed + " failed (node " + process.version + "; fixtures in " + work + ")")
process.exit(failed === 0 ? 0 : 1)
