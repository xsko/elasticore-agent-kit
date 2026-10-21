# Changelog

The plugin's `version` in `plugins/elasticore/.claude-plugin/plugin.json` pins what users get:
raise it with every release, or `claude plugin update` finds nothing new.

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
