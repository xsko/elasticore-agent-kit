---
name: generate
description: Regenerate an ElastiCORE project from its DSL, compile it, and report what the generator said - written, skipped and failed files, DSL validation warnings, hand-edited generated files - with the DSL fix for each problem.
disable-model-invocation: true
argument-hint: "[gradle task - default compileJava]"
---

# Generate and compile

1. In the project root, run `./gradlew $ARGUMENTS`, or `./gradlew compileJava` when no task was
   given (`./gradlew.bat` on Windows, from Git Bash too: the Unix script does not return when it
   starts the Gradle daemon). `compileJava` generates first, unless the
   build sets `generateBeforeCompile = false`. Keep the whole output - no `head`, no `grep`. Never add
   `-Pforce`: it overwrites hand edits in generated files.
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
   - every `SKIP(no ElastiCORE header - yours)` file: the generated one is missing there;
   - every `ERROR` line and every compile error. When a compile error is in a generated file, trace
     it back to the DSL line that caused it - for example a DTO named in `@dtype(...)` that no `dto:`
     section defines.
4. If everything is clean, say so in one line.

The project's guides in `src/main/resources/blueprint/elasticore-*.md` explain each construct; the
`elasticore` skill explains which files are whose.
