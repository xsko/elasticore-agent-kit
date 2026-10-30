---
name: elasticore
description: Work in a Spring Boot project that ElastiCORE generates from a YAML DSL in src/main/resources/blueprint, or start a new one. Use when the build applies the io.elasticore Gradle plugin, when files start with an //ecd: line, or when the user asks for an application built "with ElastiCORE" or mentions ElastiCORE, the blueprint DSL, entities, DTOs, enums or ports written in YAML, @access, @owner, states, @compute, @genid, or the elcore / elcore3 tasks.
user-invocable: false
---

# ElastiCORE

ElastiCORE reads a YAML DSL in `src/main/resources/blueprint/<domain>/` and generates a Spring Boot
application from it: JPA entities, DTOs, repositories, services, REST controllers, access checks,
state transitions and, on request, a TypeScript client.

**The DSL is the source of truth.** Change what the application *is* - its data, who may do what,
how a record moves along, how a value is decided - in YAML, regenerate, and write by hand only the
logic the DSL cannot express, in the files the generator hands over to you.

## Fast path - do this first

The `references/` pages named below are in this skill's folder, next to this file.

0. An existing project: check that `build.gradle` has an `elasticore { }` block with
   `architecture = 'hexagonal'` or `'ddd'` (section 3). The pages below are for that build.
1. A new project: `references/new-project.md`. Then copy the recipe that fits, rename and adjust:
   - `references/recipe-board.md` (posts and comments) - CRUD with validation, search and paging;
   - `references/recipe-library.md` (books, members, loans) - when a rule reads other rows (no copy
     left to lend), the server sets values, or the task has an operation besides create, read,
     update and delete (return a loan). It is for ElastiCORE 3.0.261021 or later; its last section
     says what to write instead on 3.0.261020;
   - `references/recipe-shop.md` (members, products, orders) - when users sign in and see only their
     own, an administrator does more, a record moves along (placed, shipped, cancelled), prices are
     kept and summed, or the application starts with data. ElastiCORE 3.0.261021 or later.
2. DSL syntax: `references/quick-reference.md`, one page. For what it does not have, find the one
   section of the project's guides through `blueprint/elasticore-guide-index.md` (section 1).
3. Change the YAML, run `./gradlew compileJava` (`./gradlew.bat` on Windows, from Git Bash too -
   `run-and-check.md` says why), fix every warning in the YAML.
4. Run and check the application: `references/run-and-check.md` - a jar in the background, stopped
   by its process id. Never `./gradlew bootRun` from a tool's shell; never stop processes by name.
5. Do not write controllers, DTOs, repositories, security, sign-in or error handlers by hand: they
   are generated. Extra rules go in `<Entity>Service.beforeSave`; an operation the CRUD does not
   have is a method there plus one small controller of your own, as in `recipe-library.md`.

## 0. Stay inside the project

Work on the project you were asked to work on and nothing else on the machine. Do not search other
projects or repositories for templates or examples, do not change them, and do not run git commands
that discard work (`checkout --`, `reset --hard`, `clean`) anywhere you did not create the changes.
ElastiCORE itself comes from Maven Central as a released version - never build it from its source
or publish it to the local Maven repository for a project.

**Starting a new project:** follow `references/new-project.md` - the coordinates, how to find the
newest version, a template that is built in CI every week, and how to try the result in a browser.

## 1. Read the project's own guides

`references/quick-reference.md` covers everyday modelling and is checked against the newest release.
For anything else, every generation copies the guides of the ElastiCORE version the project uses into
`src/main/resources/blueprint/` - in a multi-module build, the root project's. They are the full
reference; syntax differs between versions, so read them rather than relying on memory. They are
long (half a megabyte together) and written in Korean: never read a whole guide - one section at a
time, found through the index. Answer the user in their language.

**Finding a section.** From ElastiCORE 3.0.261023 every generation also writes
`src/main/resources/blueprint/elasticore-guide-index.md`, one line per section of the guides beside
it - the guide, the first and last line, the heading, and the words the section is about:

```text
elasticore-rule-dev-guide.md:1060-1097  ### `SourceCode` - ...  [ensureClassAnnotation, ..., addMethod, excludeMethod, dontMake]
```

1. Search the index for the word - an annotation (`@access`), a YAML key (`states:`), an API name
   (`excludeMethod`) or a Korean term: the Grep tool on that one file, or
   `grep -i -F -e 'excludeMethod' src/main/resources/blueprint/elasticore-guide-index.md`. It is
   about 570 lines; search it, do not read it.
2. Read only the range of the line that fits: the Read tool with `offset` = first line and
   `limit` = last - first + 1, or `sed -n '1060,1097p' <guide>`. Ranges of a hundred lines or less
   are the norm; for a longer one, search the index for a narrower word first.
3. No line fits: try another word (the Korean term, the YAML key) before you search the guides
   themselves.

No index (ElastiCORE before 3.0.261023): `grep -n '^#' <guide>` lists a guide's headings with their
line numbers; read from the heading you need to the next one.

| Guide | For |
|---|---|
| `elasticore-dsl-guide.md` | Entities, fields and types, relations, DTOs, enums, search conditions |
| `elasticore-annotation-guide.md` | Every `@annotation` and what it generates |
| `elasticore-env-guide.md` | `env.yml`: packages, naming, generation settings |
| `elasticore-dsl-port-guide.md` | Ports: HTTP calls to other systems, SQL through DBMS ports |
| `elasticore-dev-guide.md` | Which files you may edit, preserved blocks, the build |
| `elasticore-rule-guide.md` | The 3.0 rule engine: architectures, bundles, `publisher.rules` |
| `elasticore-rule-dev-guide.md`, `elasticore-ddd-customize-guide.md` | A team's own rule set: annotations on generated code, its own DSL words, checks that fail the build, new files; chapter 10 of the rule dev guide lists the API |
| `elasticore-migration-guide.md` | Moving a 2.x project to 3.0 |

No guides yet means generation has never run in this project: run it once (section 4).

## 2. Who owns a file - read its first lines before you edit it

| Top of the file | Owner | What to do |
|---|---|---|
| `//ecd:...` and nothing else of ElastiCORE's | The generator | Do not edit. After a hand edit the 3.0 rule engine skips the file - `SKIP(user-modified; -Pforce to overwrite)` - and it no longer follows the DSL. Change the DSL instead. |
| `//ecd:...` and a block `// !----------` ... `// ------------!` | The generator, except the block | Code inside the block survives regeneration; the end line must hold `//`. |
| `//ecd:...`, then a line starting `// Initially generated by ElastiCORE;` | You | Write here - this is where business logic goes. Its Javadoc says what belongs in it. Never delete that line. |
| No ElastiCORE header | You | Ordinary hand-written code - with the exceptions below. |

**A project with `.elasticore/cache`** (the 3.0 code from ElastiCORE 3.0.261030-rc5 on) is generated
without `//ecd:` lines, and every generated file is named in that cache. There an edit of a generated
file is kept: the next build merges the DSL's changes into it (`MERGED(your edits kept)`). Where the
DSL changes the same lines, the build writes `<<<<<<< yours` / `>>>>>>> elasticore` into the file and
fails until they are resolved (`CONFLICT`). A file whose first line starts
`// Initially generated by ElastiCORE;` is yours as above; it follows the DSL until you edit it, and
then takes only the DSL's changes that merge cleanly - when one does not, the build leaves the file
as it is and says what to carry over (`KEPT(yours ...)`). Still put in the DSL whatever it can say; a
hand edit is for what it cannot. A file there that still has an `//ecd:` line has not been taken
over yet: build once, then edit. `.elasticore/cache` is committed with the generated files - never
delete it, and never edit it.

Generated without an `//ecd:` line and rewritten on every generation, so never edit them:
`blueprint/schema.yml`, `blueprint/semantic_model.yml`, `blueprint/context-map.md`, the copied
`blueprint/elasticore-*.md` guides and their index - and, in a project without `.elasticore/cache`,
`src/main/resources/i18n/<domain>-messages.properties` (a translation goes in a copy with a locale
suffix, such as `<domain>-messages_ko.properties`) and an `orm.xml` that says `Generated by ElastiCORE`.
With the cache those two are merged like any other generated file.

A preserved block exists only where someone added one. When code has to live in a generated file -
a custom query in a repository - add one whole block right before the class's closing brace: one
Edit whose old text ends with that last `}` line and whose new text is the same with the block
inserted before the `}`. The start line, the code and the end line `// ------------!` each go on
lines of their own; use fully qualified type names inside. The generator puts a block's code back
before the last line of the file on every regeneration, so a block anywhere else would move.
Nothing else in that file changes by hand.

The model files are yours even when they say otherwise: the ElastiCORE wizard writes
`# Generated by ElastiCORE Framework` at the top of the `env.yml` and `model.yml` it creates.

Which files a project gets depends on its architecture, so look at the headers rather than guessing
from names. In `ddd` and `hexagonal` projects a root entity (`@root`) without `@editable` is split: a
generated base (`PurchaseOrderBase`) holds the fields, and the class of yours (`PurchaseOrder`) is
where its operations go. `@behavior` splits an entity that is not a root the same way.

## 3. Which generator, and where a change belongs

Check `build.gradle` first. Which generator runs depends on the ElastiCORE version in its
`plugins { }` line:

- **From 3.0.261028-rc3** the build runs the **3.0 rule engine** (`elcore3`) unless it says
  `elasticore { output = 'v2' }` (or a run passes `-Pv2`). No `elasticore { }` block means layered
  Java on the rule engine.
- **Before 3.0.261028-rc3** an `elasticore { }` block that sets `architecture`, `language` or
  `rules` means the rule engine; without one the build runs the 2.x generator.

The **2.x generator** (`elcore`) ignores `@access`, `@owner`, `@password`, `@login`, `states:`,
`@compute` and `@snapshot` **without a warning**, and writes `money` and `quantity` fields without the
converters the rule engine adds. Do not use those in a project on the 2.x path - tell the user what
they would need, and that moving to the rule engine is their decision. The 2.x path is for 2.x
projects being upgraded; on Spring Boot 4 its generated services do not compile, so a new project
never uses it.

On the rule engine the architecture decides what is enforced:

- `ddd` and `hexagonal` enforce everything above.
- `layered` in Java, from 3.0.261028-rc3 (the 3.0 code): `@access`, `@owner` and `@password` are
  enforced and `money` compiles; `states:`, `@compute` and `@snapshot` are not - they need `ddd` or
  `hexagonal`, and the generator warns `... which the selected rules do not enforce`. Before rc3
  layered Java was the 2.x-compatible output: `@access`, `@owner` and `@password` were not enforced
  either (with the same warning) and a `money` field did not compile (`package Money does not exist`).
- `layered` in Kotlin enforces `@access`, `@owner` and `@password`, not `states:`, `@compute` or
  `@snapshot`.

A new project uses `hexagonal` or `ddd` when it needs lifecycles or derived values.

The generator warns when the selected rules do not enforce what the model declares - read those
warnings as missing behaviour, not as noise.

| The request | Change |
|---|---|
| Store something new; change a type, length or constraint | `fields:` in `blueprint/<domain>/model/*.yml` |
| Who may read, create, change or delete | `@access(...)` and `@owner(...)` on the entity's `meta` line (rule engine; not layered Java) |
| How a record moves along (place, ship, cancel) | `states:` (rule engine, ddd or hexagonal) |
| A value derived from others; a value kept as it was | `@compute(...)`; `@snapshot(...)` (rule engine, ddd or hexagonal) |
| Which API exists | `@expose(...)` on the entity |
| A call to another system, or hand-written SQL | a port - `references/quick-reference.md` "ports" (up to 3.0.261022-rc1 it needs `@EnableElastiCore`), then `elasticore-dsl-port-guide.md` |
| Anything the DSL cannot say | a file you own (section 2) |

A worked example that generates and compiles: `references/example-order.md`.

## 4. The loop

1. Read the guide section for what you are about to change.
2. Edit the DSL in `src/main/resources/blueprint/<domain>/` (`env.yml`, `model/*.yml`).
3. Regenerate and compile: `./gradlew compileJava` (`./gradlew.bat` on Windows, from Git Bash too:
   the Unix script does not return when it starts the Gradle daemon - `references/run-and-check.md`).
   The plugin generates before every compile, unless the `elasticore { }` block sets
   `generateBeforeCompile = false` - then run the generation task first. To regenerate alone:
   `./gradlew elcore3` on the rule engine, `./gradlew elcore` on the 2.x path. The TypeScript
   client: `./gradlew elcore3ts`.
4. Read the whole output (section 5) - do not cut it with `head` or filter it with `grep` - and fix
   every DSL validation warning before anything else.
5. **Compile even when generation succeeded.** On the rule engine generation succeeds with DSL
   warnings, and the code then may not compile - a DTO named in `@dtype(...)` that no `dto:` section
   defines warns `unresolved type` and breaks `compileJava`.
6. Write the remaining logic in files you own. `./gradlew build` runs the tests. To start and call
   the application, follow `references/run-and-check.md` - `./gradlew bootRun` does not return in a
   tool's shell.
7. Report the change in business terms (section 7).

## 5. Reading the generator's output

The rule engine prints a line per file, then a summary:
`=== elcore3: 20 written / 0 unchanged / 2 skipped / 0 failed ===`.

| Status | Meaning |
|---|---|
| `WROTE`, `UNCHANGED` | Generated from the DSL as it is now |
| `REGENERATED(owned, never edited)` | A file of yours you had not edited yet, brought up to date |
| `SKIP(user-owned)` | Yours; left alone |
| `SKIP(user-modified; -Pforce to overwrite)` | A generated file edited by hand. If you made that edit in this session, move it into the DSL or a file you own, then restore the file by deleting it and generating again. If you did not, it is someone's deliberate edit: tell the user and ask before restoring it. |
| `SKIP(no ElastiCORE header - yours)` | A file at that path that ElastiCORE did not write; the generated one is missing |
| `MERGED(your edits kept)`, `UNCHANGED(your edits kept)` | With `.elasticore/cache`: a generated file edited by hand, with the DSL's changes merged in (or none to merge) |
| `CONFLICT` | With the cache: the edit and the DSL change the same lines. The file now holds `<<<<<<< yours` / `=======` / `>>>>>>> elasticore` and the build fails until they are gone. Resolve each place as a git conflict - usually the DSL's new code together with what the edit was for. Ask the user if you did not make the edit. Never delete the file or the cache to get past it. `CONFLICT(unresolved)`: marks are still there from an earlier build |
| `KEPT(yours - the DSL's changes to it do not merge)` | A file of yours the DSL changes where it was edited: left as it is. The `[elcore3]` lines after the list name what to carry over by hand when they can (an endpoint, a constructor argument, an annotation); do that and build again |
| `SKIP(not in the cache)` | With the cache: a file the cache has no record of (edited before merging, or not written by ElastiCORE); it no longer follows the DSL. Delete it to have it generated - ask first unless you created it |
| `SKIP(dontMake)` | Not needed for this model |
| `REMOVED(the DSL no longer produces it)` | A generated file nobody had edited, deleted because the model no longer has what it was for. One that was edited is kept, with a warning `... the DSL no longer produces it, and it has been edited` - move what was written in it, then delete it. With `.elasticore/cache`, one that code which stays still uses is kept too: `... is no longer generated, but <file> still uses it - kept`; it goes on the build after nothing uses it |
| `ERROR ...` | Generation of that file failed - read the message |

Problems in the model are listed one line each, for example
`[shop] Product.weight: unresolved type 'kilogramz' - no matching Entity, DTO, or Enum found in any domain`:

- the rule engine lists them under `[elcore3] DSL validation warnings:` and **the build still succeeds**;
- the 2.x generator lists them under `[WARN] DSL Validation Warnings:`, prints
  `[ERROR] DSL Validation: N warning(s) found` and **fails the build**. It reports hand-edited
  generated files under `[WARN] Externally Modified Files Detected:`.

Either way the model is wrong until they are gone.

A YAML file that does not parse is not a warning. The model loader prints `* LOAD ERROR: <path>`
and the parser's exception (`MarkedYAMLException: while parsing ...`) and leaves that file out. From
3.0.261021 the rule engine then stops the build: `[elcore3] the model check failed (1) - fix these
and build again:` names the file and the parser's message (`mapping values are not allowed here ...
line 41, column 40`). Before 3.0.261021 generation and the build succeeded without what the file
declares, and the compile errors that followed pointed elsewhere. Look for `LOAD ERROR` after every
DSL change and fix the YAML at the line the message names.

## 6. Ask the user before you

- run anything with `-Pforce` - it overwrites hand edits in generated files (the plugin refuses it
  unless the user allows it);
- delete a file you own, or a hand-edited generated file you did not edit yourself - the code in it
  is lost;
- change `@access`, `@owner`, `@login` or `@password`, or relax them for a demo - say who gains or
  loses access;
- remove or rename a field - a column and an API field disappear, and stored data may go with them;
- change `architecture` or `language`, or move a project from the 2.x generator to the rule engine.

## 7. Reporting a change

Report what changed for the business before what changed in the code. A reviewer should be able to
approve it without reading Java. Use `references/change-report.md`.

## 8. IDs

On a string key, `@genid` alone generates `IdUtils.newId(<field length>)`: a 3-letter prefix and
(length - 3) random letters and digits; on a `string` key without a length it generates a UUID. A
generator named in `env.yml` (`@env:genid`) or in the annotation (`@genid(...IdUtils.newId)`) gets
`newId()`: a 3-letter prefix and 9 random letters and digits, whatever the field length. For tables
that will hold many millions of rows use `@genid` alone on `string(15)` or longer, or a
`long @id @sequence` key.
