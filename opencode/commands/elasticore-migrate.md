---
description: Move an ElastiCORE project that 2.x generated (or that keeps output = 'v2') to the 3.0 code - the migration check first (it writes nothing), the DSL fixes it asks for, then, on "move" and the user's yes, the move and its failures matched to their causes. Arguments - "check" (default) or "move".
---

Move this ElastiCORE project from the 2.x code to the 3.0 code: `$ARGUMENTS`.

Follow the migrate skill of the ElastiCORE plugin: read `skills/elasticore/references/migrate.md` of the agent kit
first. Build the project as it is and record the result; run `./gradlew elcoreMigrationCheck` (ElastiCORE 3.0.261113
or later) and read `build/elasticore/migration-check.md` whole; fix in the DSL what its first section lists - propose
`@repository` for an entity the user's code reads through `helper.getXxx()` - and run the check again until that
section is empty. Report what remains per file. Only with `move` in the arguments, and after the user agrees, set
`elasticore { output = 'v3' }`, run `./gradlew compileJava`, resolve conflicts with the user and fix the compile
errors with the table in `migrate.md`, then `./gradlew build`.

Never run `-Pforce`, never delete a file the user edited, and never set `output = 'v3'` without the user's yes.
