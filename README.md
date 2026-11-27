# ElastiCORE agent kit

A [Claude Code](https://code.claude.com) plugin for projects built with
[ElastiCORE](https://github.com/xsko/ElastiCORE), which generates a Spring Boot application from a
YAML model - entities, DTOs, repositories, services, REST controllers, validation and error
handling - and regenerates it on every build. The same skills and hooks are packaged for
[opencode](https://opencode.ai), [Codex CLI](https://github.com/openai/codex), [pi](https://pi.dev)
and [oh-my-pi](https://omp.sh).

Left to itself, an agent edits the generated Java. The next build overwrites the edit, or the file
silently stops following the YAML, and nobody notices. With this plugin the agent changes the YAML,
regenerates, compiles, and tells you what changed for the business.

[한국어](README.ko.md)

## What the agent writes instead of Java

The model behind a posts-and-comments API, as the kit's board recipe writes it (one of its two
entities):

```yaml
entity:
  Post:
    meta: entity @root @editable @expose(20) @sort(postId-) -- post
    fields:
      postId:    long @id @sequence
      title:     string(100)! @notblank @search(like) -- title
      body:      text! @notblank -- body
      author:    string(30)! @notblank -- author name
      createdAt: datetime @updatable(false) @jpa:org.springframework.data.annotation.CreatedDate -- written at
```

One build turns that into the JPA entity, the request and response DTOs with their validation (`!`
required, `string(100)` at most 100 characters, `@notblank`), the repository, the service, the
REST controller - create, read, update, delete, a paged list newest first, a search by part of the
title - and the error handler that answers 400 and 404. The agent writes Java only for what the
model cannot say - a rule that reads other rows, an operation the CRUD does not have - and only in
the files the generator hands over.

## The plugin

- **A skill:** the pages the agent reads. A fast path, a one-page DSL reference, three complete
  recipes - a board (posts and comments), a library (books, members, loans) and a shop (members who
  sign in, orders) - and how to run and
  check the application from a shell. It knows which files the generator owns and where a change
  belongs.
- **Hooks:** checks on every edit and build. An edit to a generated file is refused, with where the
  change belongs instead; a build with `-Pforce` - the Gradle property that makes ElastiCORE
  overwrite hand-edited files - is refused; after a model change the agent is told to generate and
  compile, and is not allowed to finish until a successful build has done both.
- **Two agents and four commands:** a modeler that turns a requirement into a model change and
  reports it in business terms, a reviewer, and `/elasticore:generate`, `/elasticore:change-report`,
  `/elasticore:review` and `/elasticore:migrate`.
- **When ElastiCORE itself falls short:** the `report-issue` skill reproduces the problem in a
  minimal project, looks for the same issue, and drafts one for xsko/ElastiCORE with the private
  details taken out. It posts only after you say yes.
- **Contributor mode:** in a checkout of ElastiCORE itself the user-project hooks stay off, and
  hooks for the checkout's own rules take over; the `contribute` skill plans the change for an
  issue before any code.

## Requirements

- Claude Code - or opencode, Codex CLI, pi or oh-my-pi, see Install.
- JDK 17 or later. For a new project, Gradle 8.14 or later on the PATH: the template creates the
  Gradle wrapper with it.
- On Windows, Git for Windows. The hooks run in bash, and Claude Code runs them with Git Bash;
  without it Claude Code reports a hook error on every edit and command - install Git for Windows,
  or disable the plugin.
- ElastiCORE 3.0.261119 or later - 3.0, the stable release on Maven Central; a new project gets the
  newest release there.
  In a 2.x project the hooks work; the reference and the recipes are written for 3.0.

## Install

```bash
claude plugin marketplace add xsko/elasticore-agent-kit
claude plugin install elasticore@elasticore-agent-kit
```

In a session: `/plugin marketplace add xsko/elasticore-agent-kit`, then
`/plugin install elasticore@elasticore-agent-kit`.

**opencode:** clone this repository and run `opencode/install.sh` (or `opencode/install.ps1`). It
installs the same skill and hook script, an opencode plugin that runs them (opencode 1.x and 2.x),
and the agents and commands in opencode's own form - see [opencode/README.md](opencode/README.md).

**Codex CLI:** clone this repository and run `codex/install.sh` (or `codex/install.ps1`), with
`--project` for one project. It installs the skills, the modeler and the reviewer as Codex agents,
and the hooks with a `hooks.json` that runs them; trust them in Codex's `/hooks`. Or take the skills
and hooks as a plugin - `codex plugin marketplace add xsko/elasticore-agent-kit`, then
`codex plugin add elasticore@elasticore-agent-kit` - see [codex/README.md](codex/README.md). (The
comparison below ran Codex with the skill alone, kit 0.3.0.)

**pi:** `pi install git:github.com/xsko/elasticore-agent-kit@v1.4.0` installs the skills and an
extension that runs the hooks; or clone this repository and run `pi/install.sh` (or
`pi/install.ps1`), with `--project` for one project - then trust the project in pi, which loads a
project's own files only once you do. See [pi/README.md](pi/README.md).

**oh-my-pi (omp):** clone this repository and run `pi/install.sh --omp` (or `pi/install.ps1 -Omp`),
with `--project` for one project. It installs the skills, the extension, and the modeler and the
reviewer as omp task agents `elasticore-modeler` and `elasticore-reviewer`, next to omp's own
reviewer. omp's marketplace installs the plugin too (`omp plugin marketplace add
xsko/elasticore-agent-kit`, then `omp plugin install elasticore@elasticore-agent-kit`), but then the
kit's `reviewer` replaces omp's. omp needs Bun 1.4.4 or later - see [pi/README.md](pi/README.md).

## Try it

In an empty folder, start Claude Code and ask for an application "with ElastiCORE" - for example:

> Build a REST API for a library with ElastiCORE: books with a 13-digit ISBN, members with a unique
> e-mail, loans the server dates, a 409 when no copy of a book is left, a return operation. Build it,
> start it on port 18080, check it, stop it.

In the runs measured below the agent then read the skill's reference and the recipe that fits,
wrote the YAML, generated and built with the Gradle wrapper, started the jar in the background,
sent its requests - the 400s, 404s and 409s among them - stopped the server by its process id and
reported, naming what it had not checked. It sets the project up from the ElastiCORE release on
Maven Central, with the template the kit's CI builds every week; it does not build ElastiCORE from
source or read other projects on your machine.

## Update

Claude Code does not update plugins from a marketplace like this one on its own. To get the newest
version:

```bash
claude plugin marketplace update elasticore-agent-kit
claude plugin update elasticore@elasticore-agent-kit
```

Then start a new Claude Code session, or run `/reload-plugins` in one that is open.
`claude plugin list` shows the version you have; [CHANGELOG.md](CHANGELOG.md) says what changed,
and every version is a [release](https://github.com/xsko/elasticore-agent-kit/releases) with the
same notes ([RELEASING.md](RELEASING.md)).

In a session: `/plugin`, the **Installed** tab, `elasticore`, **Update now**. To have it updated
automatically: `/plugin`, the **Marketplaces** tab, `elasticore-agent-kit`, **Enable auto-update** -
Claude Code then updates it when a session starts, and the next session loads the new version.

## Measured: the same task, with and without the kit

Three agents got a task - a library loan API with books, members, loans, a 409 when no copy is
left and a return operation - once as written and once with the kit and "build it with ElastiCORE".
A separate Claude Code agent that took no part in the runs built, started and called every project
against the same 21 checks. One run per arm; we ran it ourselves (2026-10-20/21, one Windows PC,
Gradle builds inside the times, kit 0.3.0, Codex CLI 0.163.0).

| Agent | Without the kit | With the kit |
|---|---|---|
| Claude Code, Sonnet | 4 min 41 s, 20.5 of 21 | 2 min 18 s, 20.5 of 21 |
| Codex CLI, `gpt-5.6-sol` | 7 min 13 s, 21 of 21 | 3 min 45 s, 21 of 21 |
| opencode, a small local model (`qwen3.8-flash-next-a5b`) | no final report in four attempts (best: 19.5 of 21, no README) | 11 min 42 s, 21 of 21 |

Without the kit, an agent writes every entity, DTO, repository, service, controller and error
handler by hand. With it, the same agent writes one 27-line YAML, the service methods and the one
controller the recipe gives, and the generator does the rest: Claude Code finished in 10 model
calls instead of 16 and read a third less context, Codex in 24 instead of 29.

Two things to read the table with. The kit's library recipe was written from this task after the
first round, so the runs with the kit had a recipe for the task's domain and wrote its 27-line YAML
as it stands; the first run, with kit 0.2.0 and no such recipe, took Claude Code 7 min 47 s for 20.5
- slower than without the kit - and is the number for a task the kit has no recipe for. What that
run still had to write in Java became five DSL additions in ElastiCORE 3.0.261021, the version
under test; every ElastiCORE the kit supports has them.

The task, the checklist, the runners, the token counts, what each agent did, the earlier runs and
every caveat are in [benchmarks/library](benchmarks/library/README.md).

## What you get

| Part | What it does |
|---|---|
| Skill `elasticore` | Loads when Claude works in an ElastiCORE project or starts one. Knows which files the generator owns, holds the one-page DSL reference, the three recipes and the run-and-check page, and says where a change belongs, what to ask you first and how to report. What the reference and the recipes show is generated, built and called by the contract test; for anything else it sends Claude to the guides ElastiCORE copies into the project. |
| Hooks | Stop edits to generated files and `-Pforce` runs, say what to run after a DSL change, pass on the generator's warnings, and keep Claude from finishing with a DSL change that no successful build has generated and compiled. |
| Agent `elasticore:modeler` | Turns a requirement into a DSL change that generates and compiles, and reports it in business terms. |
| Agent `elasticore:reviewer` | Reviews a change: hand edits to generated files, DSL the guides or the generator do not know, generated code out of step with the DSL, and which roles gain or lose access. |
| `/elasticore:generate [task]` | Regenerates and compiles, then explains every warning, skipped file and error, with the DSL fix. |
| `/elasticore:change-report [range]` | Writes what a DSL change means for the business and what needs a decision. |
| `/elasticore:review [range] [full]` | Runs the reviewer on uncommitted changes or a range. It only reads, unless you add `full` - then it also builds, which regenerates files. |
| `/elasticore:migrate [check \| move]` | Moves a project 2.x generated (or `output = 'v2'`) to the 3.0 code: `elcoreMigrationCheck` first (it writes nothing), the DSL fixes it asks for, then - on `move` and your yes - the move, its compile errors matched to their causes, and the tests. |
| Skill `report-issue` | For an ElastiCORE defect or gap - generated code that does not compile or is wrong while the DSL is right, a generator exception, a requirement the DSL cannot say, a guide the build contradicts. Reproduces it in a minimal project on your version and settings, searches the open and closed issues (a match gets a comment instead), fills the repository's issue template - a gap as a need, never as new DSL syntax - and removes package and business names, hosts, paths and credentials. Shows the whole draft; `gh issue create` only on your yes, otherwise the text to paste. The hooks suggest it once a session. |
| Skill `contribute <issue> [plan \| build]` | In a checkout of ElastiCORE: reads its `CONTRIBUTING.md` and `changes/README.md`, then plans the change - where it goes, every JPA / MyBatis / MongoDB x Java / Kotlin / TypeScript x layered / ddd / hexagonal combination it reaches, the tests on the real output, the 2.x checks, both guide languages, the fragment, the branch. Builds only on `build` or your go-ahead. |

### The hooks

| When | What happens |
|---|---|
| Claude uses the edit tools on a generated file - first line `//ecd:`, no `// Initially generated by ElastiCORE;` line, no preserved block | The edit is refused, with where the change belongs instead. Adding one whole preserved block (`// !----------` ... `// ------------!`) goes through. |
| Claude edits a file ElastiCORE rewrites on every generation - `blueprint/schema.yml`, the copied guides, the default `i18n/<domain>-messages.properties` and a generated `orm.xml` (these two without a merge base) | Refused |
| Claude edits a generated file of a project with a merge base - `.elasticore/generated-base.zip`, or `.elasticore/cache` from an ElastiCORE before the rename (the 3.0 code: no `//ecd:` line, edits merged with the DSL's changes) - including the messages file and `orm.xml` | Allowed: the edit is kept. Told once per session that the DSL comes first and that an edit on lines the DSL also changes stops the build with conflict marks |
| Claude writes a whole new content (`Write`) over such a merged generated file - a class of its own given the name of a generated one | Refused before the write: to change the file, edit it; for a class of its own, another name |
| A build reports a merge `CONFLICT`, a file of the developer's left `KEPT(yours ...)`, or a file `SKIP(not in the cache)` | Told how to resolve the marks (never by deleting the file or the merge base), what to carry over by hand, and when to ask. The base is committed with the generated files - never deleted or ignored |
| Claude edits a generated file that has a preserved block | Allowed, with a reminder that only the block survives regeneration |
| Claude runs Gradle with `-Pforce`, or sets the property another way (`-P force`, `ORG_GRADLE_PROJECT_force`, ...) | Refused: it overwrites hand edits. You decide |
| Claude changes the model under `src/main/resources/blueprint/<domain>/` | Told to run `./gradlew compileJava` and fix the warnings before finishing; on a build that runs the 2.x generator (`elasticore { output = 'v2' }`, or a project on ElastiCORE 2.x), also told that it ignores access rules, lifecycles and derived values |
| A Gradle build - successful or failed - prints DSL validation warnings, a YAML file it could not read, or hand-edited generated files | Told what that means and what to do |
| Claude is about to finish while no successful build has generated and compiled its DSL change | Sent back once to build. A build in the background, cut short or filtered, or one that only generated, does not count |
| A project with a TypeScript client ElastiCORE generated (`src/main/ts`) - and screens type-checked against it (a `package.json` with a `check` script, or a `tsconfig.json` that includes the client) - and the DSL changed | Also told to regenerate the client (`./gradlew elcore3ts`, or a build that sets `typescriptClient = true`) and then type-check the screens; at the end sent back once, naming the step still missing: the client not regenerated, the screens not type-checked since. A failed `tsc`, or one run before the client was regenerated, does not count. A project without a generated client: as before |
| The last build compiled the change but printed DSL warnings | Sent back once with `built; N DSL warning(s) left: ...` - fix them, or tell you. A warning the DSL cannot fix (an ElastiCORE defect) can be accepted by a line in the project's `.elasticore/accepted-warnings.txt`, reviewed like code; a build whose every warning is accepted counts |
| A build fails with a compile error in a file ElastiCORE generated, or the generator fails with an exception of its own (not a model check that names the fix) | Told to check the DSL first, and that the `report-issue` skill can draft an issue - once a session |
| A shell command changes a generated file whose edit was refused | Told not to work around the refusal, and about `report-issue` if the DSL cannot say what is needed |
| `gh issue create` or `comment`, or a `gh api` write to its issues, aimed at xsko/ElastiCORE | Refused once a session: show the user the whole draft and get their explicit yes first. The next try goes through |

The hooks see the edit tools and Gradle runs through Bash or PowerShell. The output of a successful
command too long for Claude Code to pass on is read from the file it saves it to. A build whose
output goes to a file - `> build.log 2>&1`, `>> build.log`, `*> build.log`, `| tee build.log`,
`| Tee-Object build.log`, `| Out-File build.log` - is read from that file, when the command names it
and it was written after the command started (UTF-16 from Windows PowerShell 5.1 included; at most
4 MB, and of a file appended to only what the command added). Of a failed command,
Claude Code passes on only the first 10,000 characters, so in a very large project the warnings may
be past what the hook sees. An edit made another way - a script through a shell - is not stopped;
the skill tells Claude not to make one.

To let Claude edit generated files anyway, set `ELASTICORE_ALLOW_GENERATED_EDITS=1`, and
`ELASTICORE_ALLOW_FORCE=1` for `-Pforce`, for example in `.claude/settings.local.json`:

```json
{ "env": { "ELASTICORE_ALLOW_GENERATED_EDITS": "1" } }
```

### Contributor mode

In a checkout of ElastiCORE itself - `elasticore-project/elasticore-base` and a `settings.gradle`
that includes it - the samples and templates are generated and edited on purpose, so none of the
hooks above fire. These do instead:

| When | What happens |
|---|---|
| An edit of `elasticore-history.md` | Refused, with the `changes/<topic>.md` fragment instead - not in a checkout without `changes/`, not on a `version/*` branch, not with `ELASTICORE_ALLOW_HISTORY_EDITS=1` |
| An edit leaves non-ASCII characters in `elasticore-base/src/main/java` | Told the lines, and why (`SourceAsciiTest`, MS949 on Korean Windows) |
| Finishing after a guide under `elasticore-guide/` changed without its `ko/` twin, or the other way round | Sent back once |
| `git push` or `gh pr create` from a branch whose commits change `src/main` without a committed new `changes/*.md`, or with Java changed since `formatCheck diffErrorprone` (or `prCheck`) last passed in the session | Refused once, naming what is missing (a fragment not committed yet is named); the next try goes through. Not on a `version/*` branch; a branch tracking `release/*` is compared with it |

The `contribute` skill and the reviewer follow the checkout's `CONTRIBUTING.md`, which they read
each time rather than carry a copy of.

## Keeping up with ElastiCORE

- **The kit holds no copy of the DSL documentation** - only the one-page reference and the recipes,
  which the contract test checks against the newest release. The full guides are the ones every
  generation copies into the project's `src/main/resources/blueprint/`, from the ElastiCORE
  version the project uses, and the skill sends Claude there for everything the reference does not
  have. When a project upgrades ElastiCORE, Claude reads the new guides. They are in English
  (Korean with `elasticore { guides = 'ko' }`), as are the kit's own pages.
- **What the kit does rely on is tested against ElastiCORE.** The new-project template and the
  worked example, the file markers, both generators' status lines and warning headers, the guide
  names, the Gradle tasks and what the started application answers are checked by
  [`tests/contract/check.py`](tests/contract/check.py): it builds the template, the example and a
  2.x-generator project with the newest ElastiCORE 3 release from Maven Central, and generates,
  edits, breaks, restores and starts them - the shop recipe twice, on JPA and on MyBatis
  (hexagonal), with every request of its API table. CI runs it on every change and every Monday; a
  failure names the assumption that no longer holds and where the kit states it.

## Develop

```bash
bash tests/hooks/test-hooks.sh                     # the hook script, on the JSON Claude Code and Codex send (HOOK_BASH=/bin/bash for another shell)
bash tests/codex/test-codex.sh                     # the Codex agents, manifest, hooks file and installer
node tests/opencode/test-adapter.mjs               # the opencode plugin
node tests/pi/test-adapter.mjs                     # the pi / oh-my-pi extension, pi/install.sh and the package manifests
python3 tests/frontmatter/check_frontmatter.py     # every skill's, agent's and command's front matter is strict YAML (PyYAML)
python3 tests/contract/check.py                    # JDK 17 and Gradle 8.14 or later on the PATH
claude plugin validate ./plugins/elasticore --strict
claude plugin validate . --strict
claude --plugin-dir ./plugins/elasticore           # try the working copy in an ElastiCORE project
```

`ELASTICORE_VERSION=3.0.261119 python3 tests/contract/check.py` checks a given release. A
version ending in `-SNAPSHOT` is also looked up in the local Maven repository, so a build of
ElastiCORE published there with `publishToMavenLocal` can be checked before its release. A version
older than 3.0.261119, the oldest the kit supports, is refused.

## License

[Apache License 2.0](LICENSE)
