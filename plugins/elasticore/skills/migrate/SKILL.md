---
name: migrate
description: Move an ElastiCORE project that 2.x generated (or that keeps output = 'v2') to the 3.0 code, one checked step at a time - the migration check first, the DSL fixes it asks for, the move, then the compile and test failures matched to their causes.
disable-model-invocation: true
argument-hint: "[check | move - default: check, then report]"
---

# Move a project from the 2.x code to the 3.0 code

Read `${CLAUDE_PLUGIN_ROOT}/skills/elasticore/references/migrate.md` first; it has the steps, the version each needs
and the table of failures and fixes. Then:

1. **Where the project stands.** `build.gradle`: the ElastiCORE version in `plugins { }` and `elasticore { output }`.
   A project already on the 3.0 code (`output = 'v3'`, or no `output` and a `.elasticore/cache`) has nothing to move:
   say so and stop. Run the build as it is (`./gradlew build`, `./gradlew.bat` on Windows) and record the result -
   every later step is compared with it. If it does not compile now, stop and report that first.
2. **The check** (ElastiCORE 3.0.261113 or later - `./gradlew tasks --group=elasticore` lists `elcoreMigrationCheck`):
   `./gradlew elcoreMigrationCheck`, then read `build/elasticore/migration-check.md` whole. It writes nothing else.
   On an older version, say that the check needs the newer one and work from `migrate.md`'s table instead.
3. **Fix in the DSL what the check's first section lists** - generated files the move removes or no longer writes
   that code of the user's uses. For an entity their code reads and writes through `helper.getXxx()`, propose
   `@repository` on its entity line; `@service` or `@expose` only when the user wants a service or an API. Show
   the user the list and the DSL lines before changing anything, then run the check again until that section is
   empty.
4. **Report what remains** - conflicts, files kept as the user's, files left as the 2.x code, imports a merge takes
   out - as a short list per file with what each will need, and ask before the move.
5. **The move** (only with `move`, or when the user says so): `elasticore { output = 'v3' }`, then
   `./gradlew compileJava`. The statuses it prints should be the check's; say where they differ. Resolve each
   `CONFLICT` with the user, carry over what each `KEPT` line names, and fix the compile errors with the table in
   `migrate.md` - in the DSL where the table says so, never by editing a generated file.
6. **Test and report.** `./gradlew build`, then the behaviour changes the table lists (validation before a save, a
   delete row by row, `like` ignoring case) in business terms. Tell the user to commit `.elasticore/cache` with the
   sources.

Never run `-Pforce`, never delete a file the user edited, and never set `output = 'v3'` without the user's yes.
