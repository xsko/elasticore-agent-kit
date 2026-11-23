---
description: Regenerate an ElastiCORE project from its DSL, compile it, and report what the generator said - written, skipped and failed files, DSL validation warnings, hand-edited generated files - with the DSL fix for each problem. Argument - a Gradle task, default compileJava.
---

# Generate and compile

The Gradle task to run: `$ARGUMENTS` - when that is empty, `compileJava`.

1. In the project root, run `./gradlew <task>` (`./gradlew.bat` on Windows, from Git Bash too: the
   Unix script does not return when it starts the Gradle daemon).
   `compileJava` generates first, unless the build sets `generateBeforeCompile = false`. Keep the
   whole output - no `head`, no `grep`. Never add `-Pforce`: it overwrites hand edits in generated files.
2. Say which generator ran: the 3.0 rule engine prints `=== elcore3: ... ===`, the 2.x generator
   prints `ModelExtractor execution mode`.
3. Report, in this order:
   - the summary line, such as `=== elcore3: 20 written / 0 unchanged / 2 skipped / 0 failed ===`;
   - every line under `[elcore3] DSL validation warnings:` (the build succeeds with them) or
     `[WARN] DSL Validation Warnings:` (the 2.x generator fails the build) - for each, the YAML file
     and line to change, and the change;
   - every generated file edited by hand - `SKIP(user-modified; -Pforce to overwrite)`, or the list
     under `[WARN] Externally Modified Files Detected:` - with the DSL change or developer-owned file
     the edit belongs in. Restoring one means deleting it and generating again: ask the user first
     unless you made that edit in this session;
   - every `SKIP(no ElastiCORE header - yours)` file: the generated one is missing there - unless the
     summary says `... that .elasticore/generated-base.zip does not hold were left as they are`
     (`.elasticore/cache` while the project still has the old name): then the merge base is missing or
     replaced, and it is taken from git, not the files deleted;
   - with a merge base, `.elasticore/generated-base.zip` or the older `.elasticore/cache` (the 3.0
     code): every `CONFLICT` file - the
     places marked `<<<<<<< yours` / `>>>>>>> elasticore` and how each should be resolved (the build
     fails until they are); every `KEPT(yours ...)` file with what the `[elcore3]` lines say to carry
     over by hand; every `SKIP(not in the cache)` file. `MERGED(your edits kept)` needs no action;
     a line saying `.elasticore/cache was renamed to .elasticore/generated-base.zip` means: commit the
     delete and the new file together; `... was written, but .elasticore/cache could not be removed (...)`:
     delete `.elasticore/cache`, then commit that delete and the new file together;
     `.elasticore/cache is no longer read`: delete it and commit that.
     The base is committed with the generated files - never deleted or ignored;
   - every `ERROR` line and every compile error. When a compile error is in a generated file, trace
     it back to the DSL line that caused it - for example a DTO named in `@dtype(...)` that no `dto:`
     section defines.
4. If everything is clean, say so in one line.

With `elcoreValidate` as the task (`-Pstrict` fails on a DSL warning too) nothing is written but `build/elasticore/validate.md`: report `PASSED` or `FAILED`, each
reason, and each `stale:`, `no longer produced:` and `conflict or error:` file, with the fix - generate
(`compileJava`) and keep what it writes, or the DSL change. Read the report for the files it lists
as edited by hand or not checked.

The project's guides in `src/main/resources/blueprint/elasticore-*.md` explain each construct; the
`elasticore` skill - load it with the skill tool - explains which files are whose.
