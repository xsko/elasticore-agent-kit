---
name: generate
description: Regenerate an ElastiCORE project from its DSL, compile it, and report what the generator said - written, skipped and failed files, DSL validation warnings, hand-edited generated files - with the DSL fix for each problem.
disable-model-invocation: true
argument-hint: "[gradle task - default compileJava]"
---

# Generate and compile

1. In the project root, run `./gradlew $ARGUMENTS`, or `./gradlew compileJava` when no task was
   given (`gradlew.bat` on Windows without a Unix shell). `compileJava` generates first.
   Never add `-Pforce`: it overwrites hand edits in generated files.
2. Report, in this order:
   - the generator's summary line, such as `=== elcore3: 20 written / 0 unchanged / 2 skipped / 0 failed ===`;
   - every line under `DSL validation warnings:` - for each, the YAML file and line to change and
     the change;
   - every `SKIP(user-modified; -Pforce to overwrite)` file - a generated file edited by hand: say
     which DSL change or developer-owned file the edit belongs in, and that the file is restored by
     deleting it and generating again;
   - every `ERROR` line and every compile error. When a compile error is in a generated file, trace
     it back to the DSL line that caused it - for example a DTO named in `@dtype(...)` that no
     `dto:` section defines.
3. If everything is clean, say so in one line.

The project's guides in `src/main/resources/blueprint/elasticore-*.md` explain each construct; the
`elasticore` skill explains which files are whose.
