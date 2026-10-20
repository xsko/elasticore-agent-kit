# Changelog

The plugin's `version` in `plugins/elasticore/.claude-plugin/plugin.json` pins what users get:
raise it with every release, or `claude plugin update` finds nothing new.

## 0.1.0

First release, for ElastiCORE 3.0 (checked with 3.0.261015-alpha1).

- Skill `elasticore`: which files the generator owns, where a change belongs, the loop (DSL,
  `./gradlew compileJava`, the generator's warnings), what to ask first, how to report. Syntax comes
  from the guides ElastiCORE copies into the project. A worked example that generates and compiles,
  and a change-report template.
- Hooks: refuse edits to generated files; after a DSL edit, say what to run; pass on
  `DSL validation warnings:` and hand-edited generated files from Gradle's output; send Claude back
  once to build when it would finish with a DSL change no build has seen.
- Agents `elasticore:modeler` and `elasticore:reviewer`.
- `/elasticore:generate`, `/elasticore:change-report`, `/elasticore:review`.
- Tests: the hook script on Linux, macOS and Windows; the ElastiCORE behaviour the kit relies on,
  against the newest release on Maven Central, on every change and every week.
