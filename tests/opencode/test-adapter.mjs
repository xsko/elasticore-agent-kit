// Drives the opencode adapter (opencode/plugins/elasticore.js) the way opencode
// does - the hook inputs recorded from opencode 1.18 and 2.4 - against the kit's
// real hook script, and checks what reaches opencode: a thrown refusal, a note on
// the tool's output, a message to the session when it goes idle.
//
// usage: node tests/opencode/test-adapter.mjs      Node 18 or later, no packages
// The fixtures go to a fresh directory under the system temp directory, left for inspection.

import { spawnSync } from "node:child_process"
import { copyFileSync, existsSync, mkdirSync, mkdtempSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import { dirname, join, resolve } from "node:path"
import { fileURLToPath, pathToFileURL } from "node:url"

const here = dirname(fileURLToPath(import.meta.url))
const repo = resolve(here, "..", "..")
const adapter = join(repo, "opencode", "plugins", "elasticore.js")
const hook = join(repo, "plugins", "elasticore", "hooks", "elasticore-hook.sh")
const work = mkdtempSync(join(tmpdir(), "elasticore-opencode-test-"))
delete process.env.ELASTICORE_ALLOW_GENERATED_EDITS
delete process.env.ELASTICORE_ALLOW_FORCE
process.env.ELASTICORE_KIT_HOOK = hook

let passed = 0
let failed = 0
function check(name, ok, detail) {
  if (ok) {
    passed++
    return
  }
  failed++
  console.log("FAIL " + name + (detail === undefined ? "" : "\n  " + String(detail).slice(0, 600)))
  if (process.env.GITHUB_ACTIONS === "true") console.log("::error title=opencode adapter test failed::" + name)
}

// --- fixtures: a project on the rule engine ---------------------------------------
function write(path, text) {
  mkdirSync(dirname(path), { recursive: true })
  writeFileSync(path, text)
}
const project = join(work, "shop")
const src = join(project, "src", "main", "java", "com", "acme", "shop")
const blueprint = join(project, "src", "main", "resources", "blueprint")
write(join(project, "build.gradle"), "plugins { id 'io.elasticore' version '3.0.0' }\n\nelasticore {\n    architecture = 'hexagonal'\n    language     = 'java'\n}\n")
const managed = join(src, "ProductDTO.java")
write(managed, "//ecd:-1375193215H20261020123214_V3.0\npackage com.acme.shop;\n\npublic class ProductDTO {\n}\n")
const own = join(src, "ShopApplication.java")
write(own, "package com.acme.shop;\n\npublic class ShopApplication {}\n")
const model = join(blueprint, "shop", "model", "entity.yml")
write(model, "entity:\n  Product:\n    fields:\n      name: string(100)!\n")
const built = "> Task :elcore3\n=== elcore3: 1 written / 41 unchanged / 14 skipped / 0 failed ===\n> Task :compileJava\nBUILD SUCCESSFUL in 9s\n"

// --- helpers -----------------------------------------------------------------------
const prompts = []
const client = { session: { prompt: async (request) => prompts.push(request) } }
let sessions = 0
const session = () => "oc-test-" + process.pid + "-" + ++sessions

async function load(file, ctx) {
  const mod = await import(pathToFileURL(file).href + "?" + Math.random())
  return mod.ElastiCore({ client, directory: project, worktree: project, ...ctx })
}

// Calls tool.execute.before; returns the error it threw, or null.
async function before(plugin, sessionID, tool, args) {
  try {
    await plugin["tool.execute.before"]({ tool, sessionID, callID: "c1" }, { args })
    return null
  } catch (e) {
    return e
  }
}

// Calls tool.execute.after; returns the output opencode would show.
async function after(plugin, sessionID, tool, args, output, metadata) {
  const out = { title: "", output, metadata: metadata || {} }
  await plugin["tool.execute.after"]({ tool, sessionID, callID: "c1", args }, out)
  return out.output
}

async function idle(plugin, sessionID) {
  const count = prompts.length
  await plugin.event({ event: { type: "session.idle", properties: { sessionID } } })
  return prompts.slice(count)
}

const NOTE = "[ElastiCORE agent kit] "
const plugin = await load(adapter)

// --- refusals ----------------------------------------------------------------------
let s = session()
let e = await before(plugin, s, "edit", { filePath: managed, oldString: "ProductDTO {", newString: "ProductDTO { int x;", replaceAll: false })
check("an edit of a //ecd: file throws", e instanceof Error)
check("with the hook's refusal", e && /ElastiCORE generates .*ProductDTO\.java from the DSL/.test(e.message), e && e.message)

e = await before(plugin, s, "edit", { filePath: "src/main/java/com/acme/shop/ProductDTO.java", oldString: "ProductDTO {", newString: "ProductDTO { int x;" })
check("a path relative to the project counts too", e && /from the DSL/.test(e.message), e && e.message)

e = await before(plugin, s, "write", { filePath: managed, content: "class ProductDTO {}\n" })
check("a write over a //ecd: file throws", e && /from the DSL/.test(e.message), e && e.message)

e = await before(plugin, s, "edit", { filePath: managed, oldString: "}", newString: "// !----------\n    // a custom query\n// ------------!\n}", replaceAll: false })
check("an edit that adds one preserved block goes through", e === null, e && e.message)

e = await before(plugin, s, "edit", { filePath: own, oldString: "{}", newString: "{ }" })
check("an edit of a hand-written file goes through", e === null, e && e.message)

e = await before(plugin, s, "bash", { command: "./gradlew elcore3 -Pforce" })
check("./gradlew elcore3 -Pforce throws", e && /-Pforce makes the ElastiCORE generator overwrite/.test(e.message), e && e.message)

e = await before(plugin, s, "bash", { command: "./gradlew compileJava" })
check("./gradlew compileJava goes through", e === null, e && e.message)

process.env.ELASTICORE_ALLOW_FORCE = "1"
e = await before(plugin, s, "bash", { command: "./gradlew elcore3 -Pforce" })
check("ELASTICORE_ALLOW_FORCE=1 lets -Pforce through", e === null, e && e.message)
delete process.env.ELASTICORE_ALLOW_FORCE

const patch = (verb, file) => "*** Begin Patch\n*** " + verb + " File: " + file + "\n@@\n-a\n+b\n*** End Patch"
e = await before(plugin, s, "apply_patch", { patchText: patch("Update", "src/main/java/com/acme/shop/ProductDTO.java") })
check("an apply_patch of a //ecd: file throws", e && /ProductDTO\.java from the DSL/.test(e.message), e && e.message)
e = await before(plugin, s, "apply_patch", { patchText: patch("Update", "src/main/java/com/acme/shop/ShopApplication.java") })
check("an apply_patch of a hand-written file goes through", e === null, e && e.message)

// --- notes -------------------------------------------------------------------------
s = session()
let out = await after(plugin, s, "edit", { filePath: model, oldString: "string(100)!", newString: "string(200)!" }, "Edit applied successfully.")
check("a DSL edit gets the note", out.startsWith("Edit applied successfully.\n\n" + NOTE + "You changed the ElastiCORE model"), out)
out = await after(plugin, s, "edit", { filePath: model, oldString: "string(200)!", newString: "string(100)!" }, "Edit applied successfully.")
check("once per change", out === "Edit applied successfully.", out)

let sent = await idle(plugin, s)
check("idle with the change not compiled prompts the session", sent.length === 1 && sent[0].path.id === s && /Run \.\/gradlew compileJava/.test(sent[0].body.parts[0].text), JSON.stringify(sent))
sent = await idle(plugin, s)
check("once", sent.length === 0, JSON.stringify(sent))

out = await after(plugin, s, "edit", { filePath: own, oldString: "{}", newString: "{ }" }, "Edit applied successfully.")
check("an edit of a hand-written file gets no note", out === "Edit applied successfully.", out)

s = session()
out = await after(plugin, s, "edit", { filePath: "src/main/resources/blueprint/shop/model/entity.yml", oldString: "a", newString: "b" }, "ok")
check("a DSL edit by a relative path gets the note", out.includes(NOTE + "You changed the ElastiCORE model"), out)
await idle(plugin, s)

s = session()
const warned = "> Task :elcore3\n[elcore3] DSL validation warnings:\n  - Product.name: unknown type 'strin'\n=== elcore3: 1 written / 0 unchanged / 0 skipped / 0 failed ===\nBUILD SUCCESSFUL in 4s\n"
out = await after(plugin, s, "bash", { command: "./gradlew compileJava" }, warned, { output: warned, exit: 0 })
check("a build with DSL validation warnings gets the note", out.includes(NOTE + "The 3.0 rule engine (elcore3) listed DSL validation warnings"), out)

const legacyWarned = "> Task :elcore\n[WARN] DSL Validation Warnings:\n  - x\nBUILD FAILED in 3s\n"
out = await after(plugin, s, "bash", { command: "./gradlew compileJava" }, legacyWarned, { output: legacyWarned, exit: 1 })
check("a failed build gets the note too", out.includes(NOTE + "The 2.x generator (elcore) listed DSL validation warnings"), out)

out = await after(plugin, s, "bash", { command: "grep -r 'DSL validation warnings:' build.log" }, warned, { output: warned, exit: 0 })
check("a command that is not a Gradle build gets no note", out === warned, out)

s = session()
await after(plugin, s, "edit", { filePath: model, oldString: "a", newString: "b" }, "ok")
await after(plugin, s, "bash", { command: "./gradlew compileJava" }, built, { output: built, exit: 0 })
check("a build that compiled the change ends it", (await idle(plugin, s)).length === 0)

s = session()
await after(plugin, s, "edit", { filePath: model, oldString: "a", newString: "b" }, "ok")
await after(plugin, s, "bash", { command: "./gradlew compileJava" }, built, { output: built, exit: 1 })
check("a build that failed does not", (await idle(plugin, s)).length === 1)

// opencode cuts a long output and saves the whole of it
s = session()
const saved = join(work, "tool-output", "bash-1.txt")
write(saved, "> Task :elcore3\n" + "x\n".repeat(3000) + built)
const cut = "> Task :elcore3\nx\nx\n\n...\n\nThe tool call succeeded but the output was truncated. Full output saved to: " + saved + "\nUse grep or read with an offset to see the rest."
await after(plugin, s, "edit", { filePath: model, oldString: "a", newString: "b" }, "ok")
await after(plugin, s, "bash", { command: "./gradlew compileJava" }, cut, { output: cut.slice(0, 40), exit: 0 })
check("the saved whole output of a long build is read", (await idle(plugin, s)).length === 0)

s = session()
const lost = cut.replace(saved, join(work, "tool-output", "no-such-file.txt"))
await after(plugin, s, "edit", { filePath: model, oldString: "a", newString: "b" }, "ok")
await after(plugin, s, "bash", { command: "./gradlew compileJava" }, lost, { output: lost, exit: 0 })
check("a cut output without its file proves nothing", (await idle(plugin, s)).length === 1)

s = session()
out = await after(plugin, s, "apply_patch", { patchText: "*** Begin Patch\n*** Add File: src/main/resources/blueprint/shop/model/order.yml\n+entity: {}\n*** End Patch" }, "Success.")
check("an apply_patch that adds a DSL file gets the note", out.includes(NOTE + "You changed the ElastiCORE model"), out)
await idle(plugin, s)

// --- a broken hook never blocks the work --------------------------------------------
const broken = join(work, "broken-hook.sh")
write(broken, "#!/usr/bin/env bash\necho 'not json'\nexit 2\n")
for (const [name, path] of [["a missing hook script", join(work, "no-such-hook.sh")], ["a hook script that answers garbage", broken]]) {
  process.env.ELASTICORE_KIT_HOOK = path
  s = session()
  e = await before(plugin, s, "edit", { filePath: managed, oldString: "a", newString: "b" })
  check(name + ": an edit of a //ecd: file goes through", e === null, e && e.message)
  e = await before(plugin, s, "bash", { command: "./gradlew elcore3 -Pforce" })
  check(name + ": -Pforce goes through", e === null, e && e.message)
  out = await after(plugin, s, "edit", { filePath: model, oldString: "a", newString: "b" }, "ok")
  check(name + ": no note", out === "ok", out)
  check(name + ": no prompt", (await idle(plugin, s)).length === 0)
}
process.env.ELASTICORE_KIT_HOOK = hook

s = session()
const failing = { session: { prompt: async () => { throw new Error("no such session") } } }
const quiet = await load(adapter, { client: failing })
await after(quiet, s, "edit", { filePath: model, oldString: "a", newString: "b" }, "ok")
let threw = null
try {
  await quiet.event({ event: { type: "session.idle", properties: { sessionID: s } } })
  await quiet.event({ event: { type: "message.updated", properties: {} } })
  await quiet.event({})
} catch (err) {
  threw = err
}
check("a prompt that fails and odd events do not throw", threw === null, threw && threw.message)
threw = null
try {
  await plugin["tool.execute.before"]({ tool: "edit", sessionID: s }, undefined)
  await plugin["tool.execute.after"]({ tool: "bash", sessionID: s, args: { command: "./gradlew build" } }, undefined)
} catch (err) {
  threw = err
}
check("a call opencode did not shape as recorded does not throw", threw === null, threw && threw.message)

// --- opencode 2.x: the default export's setup(ctx) ---------------------------------
// The events as opencode 2.4 hands them to a plugin, recorded live: edit {path,
// oldString, newString}, write {path, content}, patch {patchText}, shell {command};
// a result is { output, content: [{ type: "text", text }], metadata }.
const mod = await import(pathToFileURL(adapter).href + "?" + Math.random())
check("the default export has an id and setup()", mod.default && mod.default.id === "elasticore-agent-kit" && typeof mod.default.setup === "function")
check("and server(), the 1.x plugin", mod.default.server === mod.ElastiCore)

const synthetic = []
async function setup2(file, options) {
  const hooks = {}
  let disposed = 0
  const domain = { hook: async (name, callback) => ((hooks[name] = callback), { dispose: async () => disposed++ }) }
  const session = { ...domain, synthetic: (options && options.synthetic) || (async (input) => synthetic.push(input)) }
  const m = await import(pathToFileURL(file).href + "?" + Math.random())
  const cleanup = await m.default.setup({ location: { directory: project }, tool: domain, session })
  return { hooks, cleanup, disposed: () => disposed }
}
const v2 = await setup2(adapter)
check("setup() hooks execute.before, execute.after and experimental.idle", ["execute.before", "execute.after", "experimental.idle"].every((n) => typeof v2.hooks[n] === "function"), Object.keys(v2.hooks))

// Calls the execute.before hook; returns the error it threw, or null.
async function before2(sessionID, tool, input) {
  try {
    await v2.hooks["execute.before"]({ tool, sessionID, agent: "build", messageID: "msg_1", id: "call_1", codemode: false, input })
    return null
  } catch (err) {
    return err
  }
}
// Calls the execute.after hook on a completed call; returns the result opencode would use.
async function after2(sessionID, tool, input, result) {
  const event = { tool, sessionID, agent: "build", messageID: "msg_1", id: "call_1", codemode: false, input, status: "completed", result }
  await v2.hooks["execute.after"](event)
  return event.result
}
const edited = (file) => ({ output: "Edited " + file + " (1 replacement)", content: [{ type: "text", text: "Edited " + file + " (1 replacement)" }], metadata: { files: [] } })
const shelled = (text, exit, outputPath) => ({ output: { exitCode: exit, wallTimeSeconds: 1, output: text, ...(outputPath ? { outputPath } : {}) }, content: [{ type: "text", text }], metadata: { status: "completed", truncated: !!outputPath, exit } })
const shown = (result) => result.content.map((c) => c.text).join("\n")
async function idle2(sessionID) {
  const count = synthetic.length
  await v2.hooks["experimental.idle"]({ sessionID, background: [] })
  return synthetic.slice(count)
}

s = session()
e = await before2(s, "edit", { path: "src/main/java/com/acme/shop/ProductDTO.java", oldString: "ProductDTO {", newString: "ProductDTO { int x;" })
check("2.x: an edit of a //ecd: file throws", e && /ElastiCORE generates .*ProductDTO\.java from the DSL/.test(e.message), e && e.message)
e = await before2(s, "write", { path: managed, content: "class ProductDTO {}\n" })
check("2.x: a write over a //ecd: file throws", e && /from the DSL/.test(e.message), e && e.message)
e = await before2(s, "patch", { patchText: patch("Update", "src/main/java/com/acme/shop/ProductDTO.java") })
check("2.x: a patch of a //ecd: file throws", e && /ProductDTO\.java from the DSL/.test(e.message), e && e.message)
e = await before2(s, "patch", patch("Update", "src/main/java/com/acme/shop/ProductDTO.java"))
check("2.x: and a patch passed as bare text", e && /from the DSL/.test(e.message), e && e.message)
e = await before2(s, "shell", { command: "./gradlew elcore3 -Pforce" })
check("2.x: ./gradlew elcore3 -Pforce throws", e && /-Pforce makes the ElastiCORE generator overwrite/.test(e.message), e && e.message)
e = await before2(s, "shell", { command: "./gradlew compileJava" })
check("2.x: ./gradlew compileJava goes through", e === null, e && e.message)
e = await before2(s, "edit", { path: own, oldString: "{}", newString: "{ }" })
check("2.x: an edit of a hand-written file goes through", e === null, e && e.message)
e = await before2(s, "read", { path: managed })
check("2.x: a read goes through", e === null, e && e.message)

s = session()
let res = await after2(s, "edit", { path: "src/main/resources/blueprint/shop/model/entity.yml", oldString: "string(100)!", newString: "string(200)!" }, edited("entity.yml"))
check("2.x: a DSL edit gets the note in the content", shown(res).includes(NOTE + "You changed the ElastiCORE model"), JSON.stringify(res))
check("and in the output", typeof res.output === "string" && res.output.startsWith("Edited entity.yml (1 replacement)\n\n" + NOTE + "You changed the ElastiCORE model"), res.output)
res = await after2(s, "edit", { path: model, oldString: "string(200)!", newString: "string(100)!" }, edited("entity.yml"))
check("2.x: once per change", shown(res) === "Edited entity.yml (1 replacement)", shown(res))
sent = await idle2(s)
check("2.x: idle with the change not compiled admits a synthetic message", sent.length === 1 && sent[0].sessionID === s && sent[0].text.startsWith(NOTE) && /Run \.\/gradlew compileJava/.test(sent[0].text), JSON.stringify(sent))
sent = await idle2(s)
check("2.x: once", sent.length === 0, JSON.stringify(sent))

s = session()
res = await after2(s, "patch", { patchText: "*** Begin Patch\n*** Add File: src/main/resources/blueprint/shop/model/order.yml\n+entity: {}\n*** End Patch" }, { output: { files: [] }, content: [{ type: "text", text: "Success." }] })
check("2.x: a patch that adds a DSL file gets the note", shown(res).includes(NOTE + "You changed the ElastiCORE model"), JSON.stringify(res))
await idle2(s)

s = session()
res = await after2(s, "shell", { command: "./gradlew compileJava" }, shelled(warned, 0))
check("2.x: a build with DSL validation warnings gets the note", shown(res).includes(NOTE + "The 3.0 rule engine (elcore3) listed DSL validation warnings"), JSON.stringify(res))
check("and keeps the structured output", res.output && res.output.exitCode === 0 && res.output.output === warned, JSON.stringify(res.output))
res = await after2(s, "shell", { command: "./gradlew compileJava" }, shelled(legacyWarned, 1))
check("2.x: a failed build gets the note too", shown(res).includes(NOTE + "The 2.x generator (elcore) listed DSL validation warnings"), JSON.stringify(res))

s = session()
await after2(s, "edit", { path: model, oldString: "a", newString: "b" }, edited("entity.yml"))
await after2(s, "shell", { command: "./gradlew compileJava" }, shelled(built, 0))
check("2.x: a build that compiled the change ends it", (await idle2(s)).length === 0)

s = session()
await after2(s, "edit", { path: model, oldString: "a", newString: "b" }, edited("entity.yml"))
await after2(s, "shell", { command: "./gradlew compileJava" }, shelled(built, 1))
check("2.x: a build that failed does not", (await idle2(s)).length === 1)

// opencode 2.x keeps the tail of a long output and names the file with the whole of it
// (the tail holds no BUILD SUCCESSFUL: only the saved file proves the build)
s = session()
const tail = "x\nx\n\n[showing lines 2900-3004 of 3004; full output saved to " + saved + "]"
await after2(s, "edit", { path: model, oldString: "a", newString: "b" }, edited("entity.yml"))
await after2(s, "shell", { command: "./gradlew compileJava" }, shelled(tail, 0, saved))
check("2.x: the saved whole output of a long build is read", (await idle2(s)).length === 0)
s = session()
await after2(s, "edit", { path: model, oldString: "a", newString: "b" }, edited("entity.yml"))
await after2(s, "shell", { command: "./gradlew compileJava" }, { content: [{ type: "text", text: tail }], metadata: { exit: 0, truncated: true } })
check("2.x: found by the line that names it, when the output has no path", (await idle2(s)).length === 0)
s = session()
await after2(s, "edit", { path: model, oldString: "a", newString: "b" }, edited("entity.yml"))
await after2(s, "shell", { command: "./gradlew compileJava" }, { content: [{ type: "text", text: tail.replace(saved, join(work, "tool-output", "no-such-file.txt")) }], metadata: { exit: 0, truncated: true } })
check("2.x: a cut output without its file proves nothing", (await idle2(s)).length === 1)

s = session()
res = await after2(s, "shell", { command: "./gradlew compileJava" }, { output: { exitCode: 0, output: warned }, metadata: { exit: 0 } })
check("2.x: a result without content keeps its output's text before the note", Array.isArray(res.content) && res.content[0].text === warned && res.content[1].text.startsWith(NOTE + "The 3.0 rule engine"), JSON.stringify(res))
s = session()
e = await before2(s, "edit", { filePath: "", path: managed, oldString: "a", newString: "b" })
check("2.x: an empty filePath does not hide the path", e && /from the DSL/.test(e.message), e && e.message)

threw = null
try {
  s = session()
  await v2.hooks["execute.after"]({ tool: "shell", sessionID: s, input: { command: "./gradlew build" }, status: "error", error: { message: "interrupted" } })
  await v2.hooks["execute.after"]({ tool: "edit", sessionID: s, input: { path: model }, status: "error", error: { message: "Could not find oldString" } })
  await v2.hooks["execute.after"]({ tool: "shell", sessionID: s, input: undefined, status: "completed", result: undefined })
  await v2.hooks["execute.before"]({ tool: "edit", sessionID: s, input: undefined })
  await v2.hooks["experimental.idle"]({})
  await v2.hooks["experimental.idle"](undefined)
} catch (err) {
  threw = err
}
check("2.x: failed calls and odd events do not throw", threw === null, threw && threw.message)

s = session()
const v2failing = await setup2(adapter, { synthetic: async () => { throw new Error("no such session") } })
await v2failing.hooks["execute.after"]({ tool: "edit", sessionID: s, input: { path: model, oldString: "a", newString: "b" }, status: "completed", result: edited("entity.yml") })
threw = null
try {
  await v2failing.hooks["experimental.idle"]({ sessionID: s, background: [] })
} catch (err) {
  threw = err
}
check("2.x: a synthetic message that fails does not throw", threw === null, threw && threw.message)

process.env.ELASTICORE_KIT_HOOK = broken
s = session()
e = await before2(s, "edit", { path: managed, oldString: "a", newString: "b" })
check("2.x: a hook script that answers garbage lets the edit through", e === null, e && e.message)
res = await after2(s, "edit", { path: model, oldString: "a", newString: "b" }, edited("entity.yml"))
check("2.x: and adds no note", shown(res) === "Edited entity.yml (1 replacement)", shown(res))
check("2.x: and sends nothing", (await idle2(s)).length === 0)
process.env.ELASTICORE_KIT_HOOK = hook

check("2.x: the cleanup setup() returns disposes its hooks", typeof v2.cleanup === "function" && (await v2.cleanup(), v2.disposed() === 3), v2.disposed())

// opencode 1.19 calls setup() too, with a context without tool hooks: nothing is registered there.
threw = null
let cleanup19 = "unset"
try {
  cleanup19 = await mod.default.setup({ options: {}, agent: {}, skill: {} })
  await mod.default.setup(undefined)
} catch (err) {
  threw = err
}
check("a 1.19 context without tool hooks: setup() registers nothing and does not throw", threw === null && cleanup19 === undefined, threw ? threw.message : cleanup19)

const noSynthetic = {}
await mod.default.setup({ location: { directory: project }, tool: { hook: async (name, cb) => ((noSynthetic[name] = cb), { dispose: async () => {} }) }, session: { hook: async (name, cb) => ((noSynthetic[name] = cb), { dispose: async () => {} }) } })
check("a session without synthetic(): the tool hooks, and no idle hook", typeof noSynthetic["execute.before"] === "function" && !noSynthetic["experimental.idle"], Object.keys(noSynthetic))

// --- installed by install.sh: the plugin finds the hook script next to it ------------
function findBash() {
  if (process.platform !== "win32") return "bash"
  for (const root of [process.env.ProgramFiles, process.env["ProgramFiles(x86)"], process.env.LOCALAPPDATA && join(process.env.LOCALAPPDATA, "Programs")]) {
    const bash = root && join(root, "Git", "bin", "bash.exe")
    if (bash && existsSync(bash)) return bash
  }
  return "bash"
}
const config = join(work, "xdg")
const env = { ...process.env, XDG_CONFIG_HOME: config }
let r = spawnSync(findBash(), [join(repo, "opencode", "install.sh")], { cwd: work, env, encoding: "utf8" })
check("install.sh succeeds", r.status === 0, r.stdout + r.stderr)
r = spawnSync(findBash(), [join(repo, "opencode", "install.sh")], { cwd: work, env, encoding: "utf8" })
check("and again over its own copy", r.status === 0, r.stdout + r.stderr)
const installed = join(config, "opencode")
const files = [
  "plugins/elasticore.js",
  "elasticore-kit/elasticore-hook.sh",
  "skills/elasticore/SKILL.md",
  "skills/elasticore/references/change-report.md",
  "agents/elasticore-modeler.md",
  "agents/elasticore-reviewer.md",
  "commands/elasticore-generate.md",
  "commands/elasticore-review.md",
  "commands/elasticore-change-report.md",
  "commands/elasticore-migrate.md",
  "skills/elasticore/references/migrate.md",
]
const missing = files.filter((f) => !existsSync(join(installed, f)))
check("install.sh copies every file", missing.length === 0, "missing: " + missing.join(", "))
check("and says what it copied", files.every((f) => r.stdout.includes(f)), r.stdout)

delete process.env.ELASTICORE_KIT_HOOK
const fromInstall = await load(join(installed, "plugins", "elasticore.js"))
e = await before(fromInstall, session(), "edit", { filePath: managed, oldString: "a", newString: "b" })
check("the installed plugin runs the installed hook script", e && /from the DSL/.test(e.message), e && e.message)
const installed2 = await setup2(join(installed, "plugins", "elasticore.js"))
let refusedBy2 = null
try {
  await installed2.hooks["execute.before"]({ tool: "edit", sessionID: session(), input: { path: managed, oldString: "a", newString: "b" } })
} catch (err) {
  refusedBy2 = err
}
check("and so does its 2.x entry", refusedBy2 && /from the DSL/.test(refusedBy2.message), refusedBy2 && refusedBy2.message)

// Without XDG_CONFIG_HOME: the home directory - on Windows the user profile, not an MSYS2 /home.
const home = join(work, "home")
r = spawnSync(findBash(), [join(repo, "opencode", "install.sh")], { cwd: work, env: { ...process.env, XDG_CONFIG_HOME: "", HOME: home, USERPROFILE: home }, encoding: "utf8" })
check("install.sh installs into ~/.config/opencode", r.status === 0 && existsSync(join(home, ".config", "opencode", "plugins", "elasticore.js")), r.stdout + r.stderr)

r = spawnSync(findBash(), [join(repo, "opencode", "install.sh"), "--project"], { cwd: project, env, encoding: "utf8" })
check("install.sh --project installs into ./.opencode", r.status === 0 && existsSync(join(project, ".opencode", "plugins", "elasticore.js")) && existsSync(join(project, ".opencode", "elasticore-kit", "elasticore-hook.sh")), r.stdout + r.stderr)
r = spawnSync(findBash(), [join(repo, "opencode", "install.sh"), "--unknown"], { cwd: work, env, encoding: "utf8" })
check("install.sh refuses an unknown option", r.status === 2, r.stdout + r.stderr)

// The plugin copied on its own, without the hook script: nothing to run, nothing refused.
copyFileSync(adapter, join(work, "elasticore-alone.js"))
const alone = await load(join(work, "elasticore-alone.js"))
e = await before(alone, session(), "edit", { filePath: managed, oldString: "a", newString: "b" })
check("a plugin with no hook script next to it lets the edit through", e === null, e && e.message)

console.log(passed + " passed, " + failed + " failed (node " + process.version + "; fixtures in " + work + ")")
process.exit(failed === 0 ? 0 : 1)
