---
description: Review a change in an ElastiCORE project with the elasticore-reviewer agent - hand edits to generated files, DSL checked against the project's guides and the generator the build runs, and the business impact. Arguments - a git range or branch (default - the changes not yet committed), and "full" to also build.
agent: elasticore-reviewer
subtask: true
---

Review this change in the ElastiCORE project: `$ARGUMENTS`.

Read those arguments as a git range or branch, and the word `full`. With no range, review the changes
not yet committed. Build - `./gradlew compileJava`, which regenerates and writes files - only when
the arguments contain `full`; otherwise do not build, and say what the user would run.

Report as your instructions say: findings first, then what changes for the business, then what you
checked. Do not fix anything.
