# Changelog

The plugin's `version` in `plugins/elasticore/.claude-plugin/plugin.json` pins what users get:
raise it with every release, or `claude plugin update` finds nothing new. Each version's section
here becomes the notes of its GitHub release when its tag is pushed ([RELEASING.md](RELEASING.md)).

## 1.3.0

For ElastiCORE 3.0.261119 and later, like 1.2.0. What you get: the kit's hooks and agents in Codex
CLI, a skill that turns an ElastiCORE defect into a reproducible issue, and a mode for working on
ElastiCORE itself.

**Update.** Claude Code: `claude plugin marketplace update elasticore-agent-kit`, then
`claude plugin update elasticore@elasticore-agent-kit`, and a new session. opencode: `git pull` in
your clone of this repository and run `opencode/install.sh` (or `install.ps1`) again. Codex CLI: new
in this version - `codex/install.sh` (or `install.ps1`), or the plugin with
`codex plugin marketplace add xsko/elasticore-agent-kit` and
`codex plugin add elasticore@elasticore-agent-kit`; then trust the hooks in `/hooks`
([codex/README.md](codex/README.md)).

- **Codex CLI gets the hooks and the agents.** Until now Codex had only the skill. Now an
  `apply_patch` that changes a generated file is refused with where the change belongs, `-Pforce` is
  refused, a DSL change gets the note to build, and a turn that ends with a DSL change no build has
  compiled is sent back once - the same hook script as in Claude Code and opencode, reading Codex's
  own payloads (each file of a patch; a Stop answered with `decision: "block"`). The modeler and
  the reviewer come as Codex agents (`.codex/agents/elasticore-*.toml`). The installer puts the
  skills in `.agents/skills/`, the agents and hooks in `.codex/` (with `--project` for one project),
  and leaves a `hooks.json` of yours as it is, printing what to add. Checked live with Codex CLI
  0.172.0 on Windows, with the plugin installed: the patch of a generated file was refused, the DSL
  edit got the note, the end of the turn was sent back once. Codex runs hooks with PowerShell on
  Windows, so they call Git Bash by its full path (`commandWindows`); a failed shell command comes
  without an exit code, so a failed build is told by Gradle's own `BUILD FAILED`.
- **report-issue: when ElastiCORE itself falls short.** Generated code that does not compile or is
  wrong while the DSL is right, a generator exception, a requirement the DSL cannot say, a guide
  the build contradicts: ask for the `report-issue` skill (Claude Code, opencode, Codex). It
  reproduces the problem in a minimal project on your ElastiCORE version and settings, searches the
  open and closed issues of xsko/ElastiCORE (a match gets a comment instead of a new issue), fills
  the repository's issue template - a gap as a need, never as new DSL syntax - and takes out
  package and business names, hosts, paths and credentials. It shows you the whole draft and posts
  with `gh issue create` only when you say yes; without `gh` you get the text to paste. The hooks
  suggest it once a session: after a compile error in a generated file, after a generator
  exception, and when a shell command changes a generated file whose edit was refused - which they
  also call out as working around the refusal.
- **Contributor mode, for work on ElastiCORE itself.** In a checkout of ElastiCORE
  (`elasticore-project/elasticore-base` and a `settings.gradle` that includes it) the user-project
  hooks no longer get in the way of editing the samples and templates. Instead the hooks check the
  checkout's own rules: an edit of `elasticore-history.md` is refused in favour of a
  `changes/<topic>.md` fragment (not in a checkout without `changes/`, not on a `version/*` branch,
  not with `ELASTICORE_ALLOW_HISTORY_EDITS=1`); non-ASCII in `elasticore-base/src/main/java` gets a
  note with the lines; a guide changed without its `ko/` twin sends the agent back once; and a
  `git push` or `gh pr create` without a fragment for a `src/main` change, or with Java changed
  since `formatCheck diffErrorprone` (or `prCheck`) passed, is refused once, naming what is
  missing. The new `contribute` skill (`contribute <issue> [plan | build]`) reads the checkout's
  `CONTRIBUTING.md` and `changes/README.md` and plans before it codes: where the change goes, every
  JPA / MyBatis / MongoDB x Java / Kotlin / TypeScript x layered / ddd / hexagonal combination it
  reaches, the tests on the real output, the 2.x checks, both guide languages, the fragment, the
  branch. The reviewer reviews a checkout's diff by those rules.
- **The `elasticore` skill loads in strict loaders.** Its front matter held `an //ecd: line`,
  which strict YAML refuses; Claude Code read it anyway, but a strict loader dropped the skill
  without a word (pi did). The description is now a folded scalar, and a test parses the front
  matter of every skill, agent and command with PyYAML.
- **Every version is a GitHub release.** Pushing a tag `vX.Y.Z` now publishes the release with this
  file's section of that version ([RELEASING.md](RELEASING.md)); 1.1.0, 1.1.1 and 1.2.0 were added
  afterwards.

## 1.2.0

For ElastiCORE 3.0.261119 and later, like 1.1.x; what it adds about `nestedRows: readers` and the
sort refusal is for the releases that have them (3.0.261127, 3.0.261124). The hooks get three
fixes and one new check; the skill gets three pages.

- **A Write over a merged generated file is refused before it runs** (#23). In a project on the
  merge (`.elasticore/generated-base.zip`, or `.elasticore/cache`), a generated file has no `//ecd:`
  line, and the hook let every tool through on it; an agent that wrote a controller of its own under
  the name of the generated `GoldenRunController.java` learnt only afterwards that it had replaced
  the entity's whole CRUD API - and the next build would have merged the DSL's changes into a class
  that no longer had anything to do with them. Now a `Write` of a file the merge base names is
  refused, with the file, the base and what to do instead: edit the file to change it, give a class
  of your own another name. An `Edit` or `MultiEdit` of it is allowed as before, so is a `Write` of
  a file of the developer's (`// Initially generated by ElastiCORE;`) or a new one, and
  `ELASTICORE_ALLOW_GENERATED_EDITS=1` lets it through. In opencode the same for `write` (1.x and
  2.x) and for a patch (`apply_patch`, `patch`) that adds the file anew or moves another onto it; a
  patch that changes or deletes it is an edit.
- **Known DSL warnings no longer hold every turn** (#19). A build counted only without any `[elcore3]
  DSL validation warnings:`, so a project with warnings the DSL cannot fix - an ElastiCORE defect,
  such as nine `... is left out` warnings until xsko/ElastiCORE#321 was fixed - was sent back to
  build after every turn, with "no successful Gradle build", which was not true. Now:
  - a project can accept such warnings in `.elasticore/accepted-warnings.txt` (beside the merge
    base, committed and reviewed like code): one line each, a warning's text or a part of it,
    compared as plain text, not as a pattern; `#` starts a comment, at the start of a line or after
    a space - for the issue the warning waits for. The hook reads it in the project folders the
    session changed the model in and in the folder the command ran in and those above it;
  - a successful build whose every DSL warning is accepted counts; one with a warning no line
    accepts still keeps the change open, and its note says how many of them are accepted;
  - when the last build compiled the change and warnings are left, the reminder at the end says
    `built; N DSL warning(s) left: ...` (the first five), that building again changes nothing, and
    how to accept one that the DSL cannot fix - with the user's agreement - instead of "no
    successful Gradle build"; a warning accepted after the build is accepted then too;
  - `references/run-and-check.md` has the file, SKILL.md section 5 points to it. ElastiCORE does
    not read it: the build prints every warning, `elcoreValidate -Pstrict` fails on one.
- **A build whose output goes to a file counts** (#20). An agent that keeps a 50 KB build out of its
  context runs `.\gradlew.bat build *> $env:TEMP\build.log; "exit=$LASTEXITCODE"` and reads the
  summary from the file; the hook read only the tool's answer (`exit=0`), so the change stayed open
  and the agent built again with the whole output in the conversation. Now `post-bash` also reads
  the file a Gradle command names - `>`, `>>`, `1>`, `2>`, `*>`, `&>`, `2>&1 > f`, `| tee [-a] f`,
  `| Tee-Object [-FilePath] f`, `| Out-File`, `| Set-Content`, `| Add-Content`, quoted, relative
  to the folder the command ran in (a `cd` inside the command is not followed), or with `~`,
  `$HOME`, `$env:NAME`, `${env:NAME}`, `%NAME%` or `$PWD` in it:
  - only a file written after the command started: `pre-bash` notes the start (per tool call), and
    a file not newer than that proves nothing; of a file appended to, only what the command added;
    without the start noted, a file written whole is read and one appended to is not, nor one
    appended to that the start did not note;
  - UTF-16 (what Windows PowerShell 5.1 writes with `*>` and `Out-File`) is read as text; a file over
    4 MB is not read; a file another statement of the line writes does not count;
  - the output Claude Code saves to a file (`persistedOutputPath`) is read as before. The opencode
    plugin passes the call's id and the project folder, so the same works there.
- **A DSL change in a project with a TypeScript client is done when the client is regenerated and
  the screens type-check** (#26). A plain `compileJava` leaves the client in `src/main/ts` as it
  was, and no Gradle build of the server type-checks the screens, so an agent could rename a field,
  see the Java build pass and stop, with every screen that used the old name broken. In the same
  once-per-change way as the build check, with no new refusal:
  - a project has a generated client when `src/main/ts` holds a file the merge base names (or, before
    the merge, a `.ts` file whose first line is `//ecd:`) - what ElastiCORE itself takes for one; it
    has screens on it when the project folder, `src/main/ts` or a folder up to two levels below the
    project holds a `tsconfig.json` that includes `src/main/ts`, or a `package.json` with a `check`
    (`typecheck`, `type-check`) script - the pet store's `web/`;
  - a DSL change there also needs a run that regenerated the client - `elcore3ts` in the task list
    or as a task in the output, or a successful build of a project that sets `typescriptClient =
    true` - and then a type check that passed: `tsc` or `vue-tsc` (through `npx`, `pnpm`, `yarn`)
    or the `check` script run by `npm`, `pnpm`, `yarn` or `bun` - in each screen folder: a check
    counts for the folder it ran in (the command's folder, its `cd`, or `npm --prefix`, `pnpm -C`,
    `yarn --cwd`, `tsc -p`), and the other screen folders are still to check;
  - the note after the DSL edit says so, naming the screen folders; the reminder at the end names
    what is missing - "The TypeScript client was not regenerated", "The screens were not
    type-checked" - once. A type check that failed (`error TS...`, also with exit 0 from
    PowerShell) does not count, nor one run before the client was regenerated, which the hook
    says; the build's own `... holds a generated TypeScript client made from an older model` is
    passed on;
  - a project without a generated client is unchanged.
- **Screens on the generated TypeScript client: `references/screens.md`** (#25). The skill said only
  how to generate the client, so an agent asked for a screen had no reason not to write its own
  `fetch` calls, form rules and labels, which drift from the server with the next model change. The
  new page, read when a task touches a screen (SKILL.md fast path, sections 3 and 4), says - from
  ElastiCORE's TypeScript rules and a client generated by 3.0.261127, and the pet store's `web/`:
  where the client is and how it stays current (`elcore3ts`, `typescriptClient = true`); calls only
  through `<Entity>Api` (which endpoints each file has, `configureApi`, a controller of your own
  through `request` of `apiSupport`, never a bare `fetch`); forms with `validate<Entity>(value,
  partial)` and `validate<Entity>Codes`, `<Entity>Fields` (labels, limits, `readOnly`),
  `<Entity>Meta` (the type's label), `<Entity>Invariants` and the enums' `...Label` maps; buttons
  from `can<Command>` / `canDelete`, with the server still refusing; `ApiError` and what each status
  and `code` of the generated error handler means for a screen; the search DTO, `Page` and sorting
  only by what the answer shows (400 `no-such-property` since 3.0.261124); answers after a write
  and `nestedRows: readers`; the loop - regenerate, then `tsc --noEmit`. Framework-neutral. A
  screen written by it type-checked against the client of the shop recipe; renaming a field in the
  model then failed the check, as it should.
- **Building a project against a locally published ElastiCORE: `references/local-elasticore.md`**
  (#22), for a team that tries an ElastiCORE fix before it is released, and only when the user asks
  (SKILL.md section 0 and `new-project.md` point to it). Publishing under a `-local` version
  (`3.0.261127-local`, set in ElastiCORE's `gradle.properties`, which its plugin build reads
  directly); one `elasticoreVersion` in the project's `gradle.properties`, and `mavenLocal()`
  limited to `io\.elasticore.*` in both `pluginManagement` and the project's repositories,
  switched on by the `-local` suffix; `--refresh-dependencies`; why an unchanged generated file
  does not show a fix (delete it to regenerate); and that such a build exists on one machine only.
  The `settings.gradle` and `build.gradle` on the page built the shop recipe against
  `3.0.261127-local` from `~/.m2`, and with `-PelasticoreVersion=3.0.261127` resolved the release
  from Maven Central.
- **The generated contract tests on the project's real database:
  `references/contract-tests-on-a-database.md`** (#21). The generated `<Domain>ContractSupport`
  names H2 in its `@SpringBootTest` and says to change it there, so an agent edited every support
  class, once per domain. The page has the way that touches none of them: a
  `ContextCustomizerFactory` registered in `src/test/resources/META-INF/spring.factories` that
  starts an embedded PostgreSQL from the test classpath (`io.zonky.test:embedded-postgres`), gives
  each Spring context a database of its own and puts `spring.datasource.*` first among the property
  sources; why `equals` / `hashCode` matter for the context cache; Flyway's folder per database
  (`classpath:db/migration/{vendor}`). Run on the shop recipe on MyBatis (hexagonal, project DDL with
  Flyway, ElastiCORE 3.0.261127): the 67 generated contract tests passed on H2 as generated and on
  the embedded PostgreSQL 18.7 with the factory - one context, one database; without `equals` /
  `hashCode`, three contexts and three databases. SKILL.md section 3 points to it.

The opencode plugin works on opencode 2.x. opencode 2.x runs no 1.x plugin, and the kit's plugin
was one: on 2.x it did not load (`failed to load plugin ... Plugin must export a default
definition`), so the refusal of hand edits to generated files, the refusal of `-Pforce`, the notes
and the reminder at the end were all off, with nothing to show it but that log line. Run the
installer again to update.

- **One plugin file for both lines.** `opencode/plugins/elasticore.js` keeps its 1.x plugin (the
  named export `ElastiCore`, now also the default export's `server`) and adds the 2.x entry, the
  default export's `id` and `setup`, on the same hook script: a refusal is thrown from the tool's
  `execute.before`, the note is added to the result in `execute.after`, and the reminder is admitted
  in `experimental.idle`, just before the session goes idle. It knows the tools of both: 2.x names
  them `edit`, `write`, `patch` and `shell` and puts the file in `path`, 1.x `edit`, `write`,
  `apply_patch` and `bash` with `filePath`; and 2.x's line `[... full output saved to <path>]` for a
  long output it cut. opencode 1.19 calls `setup` as well, with no tool hooks; it then registers
  nothing.
- **Installers:** unchanged - both versions load a plugin file from `plugins/` in
  `~/.config/opencode/` and in a project's `.opencode/`.
- **The reminder in `opencode run`.** On 2.x the session takes the reminder up and goes on, in
  `opencode run` too; on 1.x it still reaches only a session that keeps running (TUI, `opencode
  serve`).
- Seen live with opencode 1.19.4 and 2.4.1 (opencode/README.md has what): an edit or write of a
  `//ecd:` file and `./gradlew ... -Pforce` are refused with the kit's reason, an edit of the DSL
  gets the note; on 2.4.1 the plugin loads without a warning and the reminder came once.
- **Tests:** `tests/opencode/test-adapter.mjs` drives the 2.x entry with the events 2.4.1 sends
  (refusals, notes, the reminder once, long outputs, a broken hook, the 1.19 context) beside the 1.x
  tests: 80 of 80.

## 1.1.0

For ElastiCORE 3.0.261124, which renames the merge base; it still works with ElastiCORE 3.0.261119
and later. Update the kit before ElastiCORE: a kit older than this one knows the base only as
`.elasticore/cache`, so after the rename it no longer takes the project as one on the merge.

- **The merge base under its new name.** A newer ElastiCORE names the file it merges hand edits
  against `.elasticore/generated-base.zip` instead of `.elasticore/cache` (the same stored zip): a
  project that has only the old file is still read from it, the first build that writes renames it
  and writes `.elasticore/.gitattributes` and `.elasticore/.gitignore` (`!generated-base.zip`) beside
  it, and with both files there the new one is read. The kit works with either name, so with
  ElastiCORE before and after the rename:
  - the hook takes a project with either file as one on the merge - before, a project whose base had
    been renamed no longer was, and edits of its merged files were refused or not explained; with both
    files it reads the new one, as ElastiCORE does;
  - the hook's messages name `.elasticore/generated-base.zip`, and `.elasticore/cache` where the
    project may still have it - after an edit of a merged file, the one the project has; they still
    match the build's unchanged words `the cache is missing` and `SKIP(not in the cache)`;
  - after a build that renamed the base, the hook says to commit the delete and the new files
    together; when the old file could not be removed, or is back beside the new one, to delete it
    and commit that;
  - the skill, `references/migrate.md`, `references/run-and-check.md`, `/elasticore:generate`,
    `/elasticore:migrate`, the modeler and the reviewer (Claude Code and opencode) and the READMEs
    (en and ko) say the base is committed with the generated files and never deleted or ignored,
    what the rename lines in the build mean, and the reviewer treats a deleted or ignored base as a
    blocker and the rename committed in one piece as no finding.
- **Tests:** the hook tests run the merging project under both names and with both files; the
  contract test's `kind()` reads either name and checks the build writes a base (and, under the new
  name, the `.gitignore` beside it).

## 1.0.0

The first stable release of the kit, for the first stable ElastiCORE: **it requires ElastiCORE
3.0.261119 or later**. A project on ElastiCORE 2.x, or one that keeps `output = 'v2'`, still gets the
hooks and the advice for the 2.x generator, and `/elasticore:migrate` to move it to the 3.0 code.

What the kit does: a skill that knows which files the generator owns and where a change belongs,
with a one-page DSL reference, three recipes (board, library, shop - the shop also on MyBatis) and
how to run and check the application; hooks that refuse hand edits to generated files and `-Pforce`,
pass on the generator's warnings and keep the agent from finishing before a successful build has
generated and compiled its DSL change; a modeler and a reviewer agent; `/elasticore:generate`,
`/elasticore:change-report`, `/elasticore:review` and `/elasticore:migrate`. The same skill, hook
script, agents and commands for opencode, and the skill for Codex CLI. What the reference and the
recipes show is generated, built, started and called by the contract test against ElastiCORE from
Maven Central.

What changed from 0.11.0:

- No pre-release language left: the READMEs (en and ko) name ElastiCORE 3.0.261119, the stable
  release, as the requirement; the skill, its references, the agents and the commands (Claude Code
  and opencode) state what ElastiCORE 3.0 does instead of "from 3.0.26xxxx-rcN" - `elcoreValidate`,
  the merge against `.elasticore/cache`, the guide index, hexagonal and ddd on MyBatis, `@deleted`,
  `@count`, `@onDelete`, `@search(words:...)` and the rest without a version gate.
- `recipe-library.md` loses its section for ElastiCORE 3.0.261020, and the recipes no longer
  mention the `SKIP(user-owned)` status of builds before the merge.
- `quick-reference.md`: `@access`, `@owner` and `@password` on layered Java are enforced (the skill's
  table still said "not layered Java"); the ports table for older releases is one paragraph.
- `references/migrate.md` and `/elasticore:migrate`: a project on an ElastiCORE older than 3.0.261119
  upgrades first, keeping `output = 'v2'`, then runs the migration check.
- The hook's messages and comments no longer name release candidates; it still recognises a 2.x
  build, or an early 3.0 build, that runs the 2.x generator.
- The contract test refuses an ElastiCORE older than 3.0.261119 and drops the branches for older
  versions (3.0 files with an `//ecd:` line from before the merge, the preserved-block regeneration
  on them, layered Java without `@access`, MyBatis's `already-exists`, skips for missing features).

## 0.11.0

What the first stable ElastiCORE 3.0, 3.0.261119, added, so the agent writes the DSL or a setting
instead of the code they now make:

- `quick-reference.md` "Rich text, GraphQL, MongoDB": an `html` field (`@safe(basic | relaxed)`,
  `@plain(field)`, the jsoup dependency the application adds), `graphql: enable: true` (the
  controllers and the schema the build writes; an operation of your own as `extend type Query`), and
  `mode: mongo` with what it does not do yet. "Who may do what": `@signin(refresh=request)` and a
  `SpringSecurityCurrentUser` bean for an application that signs in with Spring Security.
- The skill's table of requests sends rich text, a GraphQL API, MongoDB, sessions that follow their
  row and Spring Security sign-in there; the modeler checks them first, and the reviewer reports hand
  code that does what they do.
- The PreToolUse hook refuses an edit of a GraphQL schema the build writes
  (`src/main/resources/graphql/*.graphqls` starting with `# Generated by ElastiCORE`) and sends the
  agent to a `.graphqls` of its own; one without that header stays the developer's.
- The contract test checks, on 3.0.261119 and later, that an html field generates `cleanHtml()` with
  `Safelist.basic()`, that `graphql: enable: true` generates `<Entity>GraphQlController` beside the
  REST controller, and that the hook refuses an edit of the generated schema.

## 0.10.0

What ElastiCORE 3.0.261118-rc18 added, so the agent writes the DSL instead of the code it now makes,
and checks its work as the project's CI does:

- `elcoreValidate` (3.0.261118-rc18 and later; it writes nothing but `build/elasticore/validate.md`):
  `run-and-check.md` explains it and what to do with each failure; the skill's loop, the modeler and
  `/elasticore:generate elcoreValidate` finish with it; the reviewer runs it for the check it used to
  build for.
- The PostToolUse hook reads a failed `elcoreValidate` (`stale:`, `no longer produced:`, a migration
  not written yet) and sends the agent to generating and keeping what the build writes - never to
  editing a generated file until the check passes.
- `quick-reference.md`: `@count(Comment.post[, status == VISIBLE])` (a count of the rows that point to
  a row), `@onDelete(cascade | restrict | setNull)`, `@search(words:...)` (one search box; a declared
  search DTO replaces the derived one), `>=`, `<=`, `==`, `!=` in `@invariant` and `@specification`,
  and `@expose(pageSize=20, methods="...")`. The skill's table of requests sends counts, deletes that
  reach other rows and a search box there; the modeler checks them first, and the reviewer reports
  hand code that does what they do.
- The contract test checks that `elcoreValidate -Pstrict` passes on a project just built, fails on a
  DSL change not generated yet - naming the stale file, writing no source - and that the hook reads
  that output.

## 0.9.0

Moving a project from the 2.x code to the 3.0 code, with ElastiCORE's migration check:

- `/elasticore:migrate [check | move]` (and `elasticore-migrate` for opencode): build as it is, run
  `elcoreMigrationCheck` (ElastiCORE 3.0.261113-rc13 or later - the first 3.0 build with nothing written), fix in the DSL what
  its first section lists (`@repository` for an entity hand code reads through `helper.getXxx()`), report the rest, and
  only on `move` and the user's yes set `output = 'v3'`, fix what the build says and test.
- `references/migrate.md`: the steps and a table of the failures a move gives - with their causes and fixes.
- The PostToolUse hook: a build stopped because a project holds 2.x code and chose no `output` sends the agent to the
  user's decision and the check, never to a choice of its own.

## 0.8.0

What ElastiCORE 3.0.261106-rc11 and 3.0.261112-rc12 added, where the agent looks first - so it writes
the DSL instead of the code the DSL now makes:

- `quick-reference.md`: `@deleted` (a delete that keeps the row) and `@stamp(STATE)` (when a state was
  entered), `@template(Entity[a, b])` (a DTO of a few fields), a fraction in `@min`/`@max` on a
  `double`, the metric filter's `in`, `not in`, `or`, parentheses and `count(distinct ...)`, a
  `Pageable` parameter and nested conditional blocks in a DBMS port, and the names and composite keys
  the build now refuses or warns about. Each says the release it needs.
- The skill's table of requests (section 3) sends a kept delete, a state's time and a DTO of a few
  fields to those annotations.
- The modeler checks for them before writing code of its own; the reviewer reports hand code that
  does what they do, and the names rc12 warns about (Claude Code and opencode).
- The PostToolUse hook reports a build the rule engine stopped with `the model check failed`, and
  sends the agent to the DSL lines it names rather than to Java.
- `recipe-board.md`: `Comment`'s table is `post_comment`. rc12 warns that `comment` is a word Oracle
  reserves, and the board recipe must build without a warning (the one contract rc12 broke, of 139).
- The contract test passes on ElastiCORE 3.0.261112-rc12.

## 0.7.3

ElastiCORE's guides are in English after 3.0.261031-rc7 (Korean with `elasticore { guides = 'ko' }`,
ElastiCORE pull request 69). The skill and the READMEs no longer say they are in Korean: the version
decides, and the index is searched for a term in the guides' language.

## 0.7.2

The code and models the agent writes are in English, as ElastiCORE's generated code is: comments,
Javadoc, names and messages in hand-written code, and the `-- label`s of the DSL. Another language
only when the user asks for it or the project is already written in it - not because the user
writes to the agent in it, or because the guides are in Korean. Asked in Korean for a board, an
agent had written its own use case port with Korean Javadoc. In the skill's fast path and the
modeler agent (Claude Code and opencode).

## 0.7.1

ElastiCORE 3.0.261031-rc7 answers a taken unique value on MyBatis with 409 `unique`, as on JPA.
`recipe-shop.md` names that release; the contract test, run against it, expects `unique` there
(`already-exists` on rc6).

## 0.7.0

ElastiCORE 3.0.261030-rc6 generates hexagonal and ddd over MyBatis. The kit says how, and checks it.

- **`references/mybatis.md` (new):** the three changes that put the new-project template on MyBatis
  (the MyBatis starter and Spring Data's paging types instead of `spring-boot-starter-data-jpa`,
  `mode: mybatis`, the generated schema run at start-up), which versions and languages it needs, where
  the refusals are listed, and what replaces `EntityManager` - a mapper of your own, or a database port.
- **`recipe-shop.md`, "On MyBatis":** the same shop on MyBatis; its report becomes a `dbms` port whose
  SQL is in the model and whose mapper and adapter ElastiCORE generates.
- **Skill, modeler agent (Claude Code and opencode), quick reference:** where MyBatis fits; on MyBatis
  the audit times are set without `@EnableJpaAuditing`.
- **Contract test:** the shop recipe is built, started and called twice, on JPA and on MyBatis
  hexagonal, with every request of its API table. On rc6 a taken login on MyBatis answers
  `already-exists`; the release after it `unique`, as on JPA (ElastiCORE pull request 63).

## 0.6.0

ElastiCORE 3.0.261030-rc5 merges hand edits into generated code instead of skipping the file, and from
3.0.261028-rc3 a build without an `elasticore { }` block runs the 3.0 rule engine. The kit follows both.

- **Hook, edits:** a generated file named in `.elasticore/cache` - written without an `//ecd:` line from
  rc5 - may be edited: ElastiCORE keeps the edit and merges the DSL's later changes into it. That covers
  the default messages file and a generated `orm.xml` too. The first edit in a session gets one note:
  the DSL comes first, and an edit on lines the DSL also changes stops the build with conflict marks.
  A file that still carries `//ecd:` is refused as before, and the refusal says to build once first on
  rc5, so that the build takes the file over. `schema.yml` and the copied guides are still refused.
- **Hook, build output:** `CONFLICT` and `CONFLICT(unresolved)` are explained. The explanation says to
  resolve the marks as a git conflict and not to delete the file or the cache. It also covers
  `KEPT(yours ...)` (what to carry over by hand) and `SKIP(not in the cache)`.
- **Hook, which generator:** the 2.x-generator note now fires in three cases:
  - `output = 'v2'` or `output.set("v2")` (comment lines are skipped);
  - a build that never applies the `io.elasticore` plugin, such as the 2.2 line's hand-written
    `ModelExtractor` task;
  - a build without the block on an ElastiCORE older than rc3.

  It reads the version from `plugins { }` (Groovy or Kotlin), a `buildscript` classpath or
  `gradle/libs.versions.toml`. Before, it fired on every build without the block, which is wrong
  from rc3.
- **Hook, a lost cache:** when the build says sources were left because `.elasticore/cache` does not
  hold them, the hook says to take the cache from git rather than delete the files.
- **Skill, agents, `generate` and `change-report`** (Claude Code and opencode): who owns a file in a
  project with `.elasticore/cache`. Section 2 of the skill and the status table add the merge statuses.
  Section 3 explains which generator runs, per version. On rc3 and later, layered Java enforces
  `@access`, `@owner` and `@password`, and `money` compiles there. The reviewer agent treats a hand edit
  to a merged file as a finding only when the DSL could say it; a leftover conflict mark is a blocker.
- **Recipes and quick reference:** an edited service reports `UNCHANGED(your edits kept)` from rc5. The
  ownership line is the file's first line from rc5, its second before.
- **Contract test:** `kind()` reads `.elasticore/cache`. From 3.0.261030 the test checks:
  - a merged DTO the hook allows;
  - `UNCHANGED(your edits kept)` for an edit;
  - `MERGED(your edits kept)` for a DSL change elsewhere in the file;
  - `CONFLICT` with marks and a failed generation for the same line, then `CONFLICT(unresolved)`;
  - the hook's explanation of the conflict in real output;
  - a DTO the DSL dropped but a kept file still uses: kept, with the file that uses it named.

  From 3.0.261028 the layered contracts expect access enforced and `money` compiling, and the 2.x project
  declares `output = 'v2'`. These four contracts had failed on rc3 and rc4.

## 0.5.0

Read less of the guides, and ports.

ElastiCORE copies about half a megabyte of Korean guides into every project's `blueprint/`. From
3.0.261023 it also writes `blueprint/elasticore-guide-index.md` beside them: one line per section with
its line range and the words it is about. The skill and both agents now search that index and read
only the range it names, never a whole guide.

- **`SKILL.md`:** the fast path points to the index. A new "Finding a section" explains how: grep the
  index for a word (`grep -i -F -e 'excludeMethod' blueprint/elasticore-guide-index.md`), read that
  range with `Read` offset/limit or `sed -n`, and try other words when nothing matches. With an
  ElastiCORE older than 3.0.261023, which has no index, it says to use `grep -n '^#'` on the guide.
  The team rule set row names the rule guide's chapter 10, the rule API reference (new in 3.0.261023).
  The list of regenerated files includes the index.
- **Agents `modeler` and `reviewer`** (Claude Code and opencode): look things up through the index; do
  not read a whole guide.
- **`references/quick-reference.md`:** a section on ports - a DBMS port and an HTTP port with their
  DTOs, as built and called on 3.0.261022-rc1 (with `@EnableElastiCore`) and on 3.0.261023 (without).
  It says what the ElastiCORE version decides: up to rc1 the application class needs
  `@EnableElastiCore` or the start fails with `No qualifying bean`, and a DBMS method that returns one
  value or takes one `long` does not work (take and return DTOs); from 3.0.261023 the runtime's
  auto-configuration registers the ports and both work.
- **Contract test:** for 3.0.261023 and later, checks that the guide index is there and that its rows
  open on their headings, and that `@access`, `states:` and `excludeMethod` lead to a section.
- **README:** ElastiCORE 3.0 is a release candidate on Maven Central (was "alpha"); the 3.0.261021
  additions the measured runs used are on Central since 3.0.261022-rc1.

## 0.4.0

A third recipe - a shop with members who sign in - and the quick reference filled in with what
three agents looked up in the long guides or in the runtime jar.

Claude Code built the pet store three times with the kit (Java hexagonal, Java ddd, Kotlin
hexagonal). Each time it searched the guides in its first two minutes for value objects, `@login`
and `@access`, `states:` and `@snapshot`/`@compute`, ran `javap` on `CurrentUser`,
`SessionCurrentUser` and `Money`, and wrote by hand a sign-in controller, an existence check for
every referenced row, a role check for an administrator's report and a start-up loader. ElastiCORE
3.0.261021 now generates the sign-in and the existence check; the kit shows the rest.

- **`references/recipe-shop.md`:** members, products and orders as a complete project - sign-up and
  the generated sign-in (`@signin` on the entity line), `@access`/`@owner` with a role only an administrator sets, an address and a
  card as values (`@embeddable`, `@writeonly`, `@pattern`), an order's lifecycle (`states:`, 409 for a
  refused step), prices kept with `@snapshot` and summed with `@compute`, a reference that must exist
  (404), `@minsize`, `CreatedDate`, an `@event` listener, start-up data in `CurrentUser.runAsSystem`,
  and an administrator's report behind `ACCESS.require(currentUser, "report")` - with every request
  and answer. The contract test builds, starts and calls it (S1-S12).
- **`references/quick-reference.md`:** `@past`/`@future`, `@writeonly`, `@password`, `@minsize`,
  values with `@Embedded`; a section on who may do what and the generated sign-in; a lifecycle and
  derived values; the runtime classes a file of yours uses (`ACCESS.require`, `CurrentUser`,
  `runAsSystem`, `SessionCurrentUser`, `Money`, the exceptions and their statuses); the 404 for a key
  that names no row.
- **`references/recipe-library.md`:** the generated existence check replaces the recipe's own lookups
  of the member and the book (404 `Member 999999 does not exist`); its 3.0.261020 section keeps them.
- **`references/run-and-check.md`:** the bash start detaches stdin (`< /dev/null`); start the server
  and call it in separate tool calls (a Kotlin run lost close to seven minutes doing both in one);
  scratch files under `build/`, not `/tmp`.
- **A time set when the row is made** is `@readonly @default(now)` - on the quick reference, in the
  shop recipe (no `@EnableJpaAuditing`) and in the library recipe, whose `MemberService` method is
  gone. `Money` on the quick reference says what `times(BigDecimal)` and `rounded` do.
- **`SKILL.md`, the quick reference and the contract test:** from 3.0.261021 a model file that does
  not parse stops the build, naming it. The contract test reads `tasklist` with `errors="replace"`
  (a Korean Windows answered in CP949 and the run crashed).
- **A change request on a finished project** (stock, reviews, a courier API, BI measures, Korean
  messages; `benchmarks/petstore/`): every arm searched the long guides for `metrics:` and wrote
  `ValidationMessages.properties` or `spring.web.locale` by hand. The quick reference now has the
  measures (`metrics.yml`, `ossie-export`), the message language and translation files, the 502 of a
  failed port call, `PUT /batch`, `POST /delete` and `GET /schema/info`, `beforeSave` as the place for
  rules about writes, `@updatable(false)` on a reference, `typescriptClient = true`, and the sign-in
  rules of 3.0.261021 (only the member or the administrator may change the row; a unique login).
  `@search(like)` ignores case from 3.0.261021.
- **`references/example-order.md`:** the login is `@unique` - 3.0.261021 warns about a login two rows
  could share.
- **`benchmarks/petstore/`:** the pet store task, its checklist, a change request with its own
  checklist, the runners and the analysis scripts, and what each round showed.
- The skill's fast path names the shop recipe.

## 0.3.0

A second recipe, the five DSL additions of ElastiCORE 3.0.261021 on the quick reference, and a
contract test that also checks an ElastiCORE build not yet on Maven Central.

A harder task than the board - books, members and loans - showed where an agent still wrote Java
by hand: dates the server sets that a request could overwrite, "loans not yet returned" as a
search, an ISBN format rule, a loan that had to send the nested member instead of `memberId`, and a
409 with its own reason ("no copy left to lend"). ElastiCORE 3.0.261021 covers each in the DSL or
the runtime; the kit now shows how.

- **`references/recipe-library.md`:** books, members and loans as a complete project - an ISBN key
  checked by `@pattern`, a unique e-mail address, loans that name their member and book by key
  (`member: Member!`), dates set in `beforeSave` and kept out of requests by `@readonly`, a rule
  that counts the loans of a book and refuses with `ConflictException` (409, the message as
  `detail`), returning a loan as a method of `LoanService` with one small controller of its own,
  and `returnedDateEmpty` to find what is still out - with every request and answer, the
  400/404/409 refusals included. It needs 3.0.261021 or later and says what to write instead on
  3.0.261020 (built and called by hand with 3.0.261020-alpha2), and how to add the
  `ConflictException` handler to an error handler generated before 3.0.261021.
- The skill's fast path names both recipes and when to pick which, and allows one small controller
  for an operation the CRUD does not have.
- **`references/quick-reference.md`:** the five additions, each marked "(from 3.0.261021)":
  `@readonly` for a value the server sets, `@search(isnull)` (a `<field>Empty` search),
  `@pattern('regex', 'message')`, `post: Post!` requiring the key field, and `ConflictException`
  for a 409 with your message. Also the key names of references under `hexagonal`/`ddd`
  (`memberId`, `bookIsbn`), the two 409s that come for free (a key that exists, a unique index),
  and `entityManager` for reading and counting rows in a service. `recipe-board.md` says that from
  3.0.261021 `post: Post!` makes its `postId` check unnecessary.
- **Contract test:** a version ending in `-SNAPSHOT` is also taken from the local Maven repository
  (`mavenLocal()` before `mavenCentral()` in both repository blocks of the template), so
  `ELASTICORE_VERSION=3.0.261021-SNAPSHOT` checks a build published with `publishToMavenLocal`. The
  library recipe is built as written - generate, add the methods and the controller, `bootJar` -
  started, and called with every request of its API table, the 404 and 409 answers with the
  messages the recipe throws; 24 contracts. They run only when the version is 3.0.261021 or later;
  with an older one each is reported `SKIP` and the summary line ends `, 24 skipped (needs
  3.0.261021)`. The other contracts are unchanged.
- **`references/run-and-check.md`:** on Windows build with `./gradlew.bat`, from Git Bash too. The
  Unix wrapper script - `./gradlew`, `sh ./gradlew`, `bash ./gradlew` - run from Claude Code's Bash
  tool does not return when it starts a Gradle daemon: the daemon inherits the tool's output pipe,
  Claude Code waits for the call's timeout, moves it to the background and stops it ten minutes
  later. In the library comparison that cost a Claude Code run ten minutes on a build that had
  finished in twelve seconds, and made it look slower with the kit than without. Reproduced in that
  tool: `sh ./gradlew` and `bash ./gradlew` hang whether their output goes to a pipe or a file,
  `./gradlew.bat` from the same bash returns, PowerShell returns, `--no-daemon` returns. The page
  said the opposite - that the daemon is no problem in bash and in Claude Code - and offered
  `sh ./gradlew` as the answer to `ClassNotFoundException: GradleWrapperMain`; both are corrected,
  the answer to that error is `./gradlew.bat`. The skill's fast path, the quick reference and the
  `generate` skill say the same. The same run with the corrected page: 2 minutes 18 seconds, nine
  tool calls, no command stuck, 20.5 of 21 (the plain Spring Boot run of the same task took 4
  minutes 41 seconds). The half point is the README's jar name - the page now says to write the
  name seen in `build/libs/`, not a guessed `-0.0.1-SNAPSHOT.jar`.
- **`references/recipe-library.md`:** insert the service methods with the file-editing tool, not
  with a script - an agent spent a minute and a half on an awk splice that put them in the wrong
  place, then wrote the files by hand anyway.
- **Codex CLI on the same task** (`codex exec`, `gpt-5.6-sol` with reasoning low, the skill copied
  to the project's `.agents/skills/elasticore`): without the kit 7 minutes 13 seconds to its answer,
  29 model calls, 21 of 21 - 23 Java files by hand, four failed builds before it found where Spring
  Boot 4 had moved `@AutoConfigureMockMvc`, half a minute searching the jars in `~/.gradle`; with
  the kit 3 minutes 45 seconds, 23 calls, 21 of 21, 14 percent less context read - the skill and
  four of its pages, the recipe's YAML, one `--no-daemon` build. Two things that run showed, both
  fixed: the `codex` process did not end after its answer, held by the Gradle daemon that
  `gradle wrapper` had started (`run-and-check.md` and `new-project.md` now say
  `gradle --no-daemon wrapper ...` and why - with the daemon the process was still alive after five
  minutes and after twenty, with `--no-daemon` it ended with the answer), and Codex looked for the
  skill's pages under `~/.agents/skills` first, four failed reads before it opened the copy next to
  `SKILL.md` - the skill now says where its pages are.
- **`benchmarks/library/`:** the comparison as a folder anyone can read and repeat - the task
  (Korean original and English), the grader's checklist, the runners for Claude Code, Codex and
  opencode, the token and timeline scripts, and the write-up with every run's numbers, what each
  agent did, the earlier runs and the caveats. The README keeps the table and links there.

## 0.2.0

Guidance a small model can follow, opencode support, and the fixes that were to be 0.1.2.

A comparison on one task - a board API with posts and comments, the same spec with and without
ElastiCORE - showed where agents lose time. Claude Code (Sonnet) built it faster with the kit; a
small local model in opencode took three times as long with ElastiCORE as without. It read the long
guides in pieces, guessed the shape of the generated API, started the server with `./gradlew
bootRun` (which never returns and held the shell for minutes), and left the creation time unset.

- **`references/quick-reference.md`:** the DSL on one page - field types and checks (`string!`
  does not refuse `""`, `@notblank` does; `@length(min=)`, `@email`, `@min`/`@max`), keys, the
  entity line, the exact API of an `@expose` entity (lists and searches are `POST /search`, an
  update carries its key in the body), time stamps (they need `@EnableJpaAuditing`; there is no
  `@createtime`), where hand-written checks go, names to avoid, and the YAML pitfall that drops a
  whole file. Its sample model is generated, built and called in CI.
- **`references/recipe-board.md`:** posts and comments as a complete project - the DSL, the
  application class and the one hand-written check that makes a comment need an existing post -
  with every request and answer, all checked in CI. It records that `post: Post!` makes the
  generated DTO require the nested object instead of `postId`.
- **`references/run-and-check.md`:** how an agent builds, starts, calls and stops the application:
  a jar in the background with its process id written down, in bash and in PowerShell; never
  `bootRun` from a tool's shell, never stopping processes by name. The PowerShell start lets the
  server write its own log (`--logging.file.name`) instead of `-RedirectStandardOutput`: with the
  redirect the server holds the shell's pipe, and in opencode the tool call did not return until
  the server exited (a run sat for ten minutes on it). For the same reason a Gradle run that
  starts the Gradle daemon never returns to opencode's PowerShell shell on Windows: the page says
  to build with `--no-daemon` there, or to start opencode with `GRADLE_OPTS=-Dorg.gradle.daemon=false`.
  The wait for the server stops as soon as the server process is gone and shows its log, instead
  of waiting the full 90 seconds for a server that failed at startup.
- The skill starts with a five-step fast path that sends the agent to these pages first.
- `new-project.md` gives the template its test setup, so a project's tests run with
  `./gradlew build`.
- **opencode:** see the opencode section below.

### opencode

- `opencode/` installs the same skill and hook script into opencode (`install.sh`, `install.ps1`,
  for the user or `--project`), with `plugins/elasticore.js`, an opencode plugin that runs the hook
  script on opencode's tool calls - refusals become tool errors, notes are added to the tool's
  output - and the agents and commands in opencode's own format.
- Seen live with opencode 1.18.31: the skill is found, an edit of a generated file and a `-Pforce`
  run are refused, a DSL edit gets its note. The note after a build, `apply_patch` and long saved
  output are covered by `tests/opencode/test-adapter.mjs` (44 cases, in CI), not seen live. The
  reminder when a session goes idle does not continue `opencode run`.
- An older ElastiCORE skill in `~/.claude/skills` with the same name can be loaded instead of the
  kit's: `opencode/README.md` says how to keep it out.

### Fixes (from the reviews of 0.1.1)

Fixes from a second independent review, each checked against ElastiCORE 3.0.261015-alpha1 and
against what Claude Code really sends a hook.

- **The model was refused.** The ElastiCORE wizard writes `# Generated by ElastiCORE Framework` at
  the top of the `env.yml` and `model.yml` it creates, and 0.1.1 took them for generated files. The
  DSL is always editable now, and only resources (`.properties`, `.xml`, `.yml`) are taken as
  regenerated by that comment - a source file without `//ecd:` is the developer's.
- **PowerShell.** On Windows Claude often runs commands with its PowerShell tool, which the hooks
  did not see: `-Pforce` went through and a successful build did not count. They now watch
  `Bash|PowerShell`, and read `.\gradlew.bat`, `cmd /c gradlew.bat` and `(cd app && ./gradlew ...)`.
- **Failed builds.** A command that exits non-zero comes as `PostToolUseFailure`, which the hooks did
  not listen to - the 2.x generator's warnings, which stop the build, never reached Claude. They do
  now, from the `error` Claude Code sends.
- **Long output.** Claude Code passes on the first 30,000 characters of a successful command's
  output and saves all of it to a file; `BUILD SUCCESSFUL` at the end was cut off, so a large
  project's build never counted. The hook reads the saved file. Of a failed command only the first
  10,000 characters come, with no file - the README says so.
- **A YAML file that does not parse** is printed as `* LOAD ERROR: <file>` and left out of the model,
  and the build passes. The hook reports it and keeps the note; the skill says to look for it.
- **"Compiled" means compiled.** Generation alone - `elcore3`, `elcore3ts`, or a build with `-x` on
  the compiling tasks - no longer counts as the build that ends a DSL change, nor does a command in
  which one Gradle run failed and another passed; a compiling task has to run and pass.
- **Preserved blocks** go where the generator puts their code back on every regeneration: right
  before the class's closing brace. Only that edit is let through - one Edit whose old text ends
  with the last `}` and that adds one whole block, its end line holding `//` and no other end marker,
  each on lines of their own. Not code outside the block, generated code moved into it, a block in
  a method, two blocks, `replace_all` or a MultiEdit.
- **`-Pforce`** is also refused as `"-Pforce"`, `-P force`, `--project-prop force`,
  `-Dorg.gradle.project.force` and `ORG_GRADLE_PROJECT_force=`, through `& ".\gradlew.bat"`,
  `cmd /c`, `bash -c`, `env` or `time`. The command is read as a shell reads it - quotes, separators,
  here-documents - so a commit message that mentions `-Pforce` is not refused.
- **New projects:** `gradle wrapper` needs a settings file, so `new-project.md` makes the wrapper
  after `settings.gradle` and before `build.gradle` - from an empty folder Gradle failed and
  suggested `gradle init`.
- **Layered Java** keeps the 2.x-compatible output on the rule engine: `@access`, `@owner` and
  `@password` are not enforced (the generator warns), and with 3.0.261015-alpha1 a `money` field
  does not compile there. The skill, the agents and `new-project.md` say so, and a new project
  uses `hexagonal` or `ddd`. The 2.x generator writes `money` without its converter rather than not
  at all; the wording says so.
- `elasticore { architecture = ... }` on one line and `elasticore.architecture = ...` count as the
  rule engine. The 2.x generator rewrites a hand-edited file that has a preserved block (`[INGORE]`);
  the hook and the reviewer say so. `new-project.md` takes the newest 3.x version as the contract test
  does, and makes the Gradle wrapper before `build.gradle` exists.
- The agents may use the PowerShell tool.
- Tests: 132 hook cases, the payloads as Claude Code sends them (checked by recording real ones);
  new contracts for the wrapper, a YAML file that does not parse, layered Java, and the 2.x generator
  ignoring `@access` without a warning. The macOS `/bin/bash` run no longer stops when the first run
  fails.

## 0.1.1

Fixes from a first real use - "build a board with ElastiCORE" in an empty folder - and from an
independent review.

- **New projects.** Claude found no ElastiCORE 3 in the local Maven cache, built it from a source
  checkout and published it locally, and searched other projects for a template. The skill now
  starts a project from the release on Maven Central with `references/new-project.md` - the
  coordinates, how to find the newest version, a template, how to try it in a browser - and says to
  stay inside the project: no other repositories, no building ElastiCORE, no discarding git work.
- **Which generator.** A build without an `elasticore { }` block runs the 2.x generator, which
  ignores `@access`, `@owner`, `@password`, `@login`, `states:`, `@compute` and `@snapshot` without a
  warning and has no `money`. The skill, the agents and the change report check it; the hook says so
  when such a model is edited there. Both generators' output is described as each prints it: the 2.x
  generator fails the build on DSL warnings and lists hand-edited files under
  `[WARN] Externally Modified Files Detected:`.
- **"Never built" means a successful generating build.** The note a DSL edit leaves was cleared by a
  background build, interrupted or cut output, a dry run, or a `grep` of `build.gradle`. Now only a
  Gradle command that runs a generating task, whose output shows the generator ran and
  `BUILD SUCCESSFUL`, clears it; hand-edited files in the output no longer keep it.
- **Generated files without an `//ecd:` line** - `blueprint/schema.yml`, `semantic_model.yml`,
  `context-map.md`, the copied guides, the default messages file - are refused and no longer count
  as the model. A translation copied from the messages file stays editable.
- **Preserved blocks.** Adding one whole block to a generated file goes through, so a custom query
  can go in a repository; the refusal says how. The rule engine keeps the block through a
  regeneration that rewrites the file - now a contract.
- **`-Pforce`** is refused unless the user allows it (`ELASTICORE_ALLOW_FORCE=1`).
- The ownership line is matched by its prefix, `// Initially generated by ElastiCORE;` - the
  templates write four endings. A UTF-8 BOM before `//ecd:` no longer hides a generated file.
- The hooks read files as bytes, so macOS's BSD tools also see a BOM and accept a file that is not
  UTF-8, such as a comment in MS949.
- The README says how to update: this marketplace is not auto-updated unless you turn it on.
- The hand-edit note asks before restoring a file Claude did not edit; `@genid` without a length is
  a UUID; the example's 401/404 and the owned files are stated correctly; the agents can load the
  skill; `/elasticore:review` builds only with `full`; `build.gradle` edits count as model changes.
- The skill lists `REMOVED(the DSL no longer produces it)` - the rule engine deletes a generated
  file the model no longer produces, unless someone edited it. The `dto.yml` case is stated as it
  happens: generation warns `unresolved type 'OrderLineDTO'`, then `compileJava` fails. On Spring
  Boot 4 the 2.x generator's services do not compile with 3.0.261015-alpha1 (Spring Data 4's
  `delete`); the skill says so and a contract notices when ElastiCORE fixes it.
- Tests: 74 hook cases, also under macOS's `/bin/bash`; the contract test builds the template from
  `new-project.md`, the example, and a 2.x-generator project, starts the application and checks
  what a browser sees. CI jobs have time limits.

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
