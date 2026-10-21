# ElastiCORE agent kit

A [Claude Code](https://code.claude.com) plugin for projects built with
[ElastiCORE](https://github.com/xsko/ElastiCORE), which generates a Spring Boot application from a
YAML model - entities, DTOs, repositories, services, REST controllers, validation and error
handling - and regenerates it on every build. The same skill is packaged for
[opencode](https://opencode.ai) and works in [Codex CLI](https://github.com/openai/codex).

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

- **A skill:** the pages the agent reads. A fast path, a one-page DSL reference, two complete
  recipes - a board (posts and comments) and a library (books, members, loans) - and how to run and
  check the application from a shell. It knows which files the generator owns and where a change
  belongs.
- **Hooks:** checks on every edit and build. An edit to a generated file is refused, with where the
  change belongs instead; a build with `-Pforce` - the Gradle property that makes ElastiCORE
  overwrite hand-edited files - is refused; after a model change the agent is told to generate and
  compile, and is not allowed to finish until a successful build has done both.
- **Two agents and three commands:** a modeler that turns a requirement into a model change and
  reports it in business terms, a reviewer, and `/elasticore:generate`, `/elasticore:change-report`
  and `/elasticore:review`.

## Requirements

- Claude Code - or opencode or Codex CLI, see Install.
- JDK 17 or later. For a new project, Gradle 8.14 or later on the PATH: the template creates the
  Gradle wrapper with it.
- On Windows, Git for Windows. The hooks run in bash, and Claude Code runs them with Git Bash;
  without it Claude Code reports a hook error on every edit and command - install Git for Windows,
  or disable the plugin.
- ElastiCORE 3.0, which is in alpha on Maven Central; a new project gets the newest release there.
  In a 2.x project the hooks work; the reference and the recipes are written for 3.0.

## Install

```bash
claude plugin marketplace add xsko/elasticore-agent-kit
claude plugin install elasticore@elasticore-agent-kit
```

In a session: `/plugin marketplace add xsko/elasticore-agent-kit`, then
`/plugin install elasticore@elasticore-agent-kit`.

**opencode:** clone this repository and run `opencode/install.sh` (or `opencode/install.ps1`). It
installs the same skill and hook script, an opencode plugin that runs them, and the agents and
commands in opencode's own form - see [opencode/README.md](opencode/README.md).

**Codex CLI:** copy `plugins/elasticore/skills/elasticore` into your project as
`.agents/skills/elasticore` (or into `~/.agents/skills/elasticore` for every project). Codex gets
the skill - the fast path, the reference and the recipes; the hooks are Claude Code's and
opencode's. That is how it ran in the comparison below.

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
`claude plugin list` shows the version you have; [CHANGELOG.md](CHANGELOG.md) says what changed.

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
under test, which is not on Maven Central yet; with today's 3.0.261020-alpha2 the recipe says what
to write by hand instead.

The task, the checklist, the runners, the token counts, what each agent did, the earlier runs and
every caveat are in [benchmarks/library](benchmarks/library/README.md).

## What you get

| Part | What it does |
|---|---|
| Skill `elasticore` | Loads when Claude works in an ElastiCORE project or starts one. Knows which files the generator owns, holds the one-page DSL reference, the two recipes and the run-and-check page, and says where a change belongs, what to ask you first and how to report. What the reference and the recipes show is generated, built and called by the contract test; for anything else it sends Claude to the guides ElastiCORE copies into the project. |
| Hooks | Stop edits to generated files and `-Pforce` runs, say what to run after a DSL change, pass on the generator's warnings, and keep Claude from finishing with a DSL change that no successful build has generated and compiled. |
| Agent `elasticore:modeler` | Turns a requirement into a DSL change that generates and compiles, and reports it in business terms. |
| Agent `elasticore:reviewer` | Reviews a change: hand edits to generated files, DSL the guides or the generator do not know, generated code out of step with the DSL, and which roles gain or lose access. |
| `/elasticore:generate [task]` | Regenerates and compiles, then explains every warning, skipped file and error, with the DSL fix. |
| `/elasticore:change-report [range]` | Writes what a DSL change means for the business and what needs a decision. |
| `/elasticore:review [range] [full]` | Runs the reviewer on uncommitted changes or a range. It only reads, unless you add `full` - then it also builds, which regenerates files. |

### The hooks

| When | What happens |
|---|---|
| Claude uses the edit tools on a generated file - first line `//ecd:`, no `// Initially generated by ElastiCORE;` line, no preserved block | The edit is refused, with where the change belongs instead. Adding one whole preserved block (`// !----------` ... `// ------------!`) goes through. |
| Claude edits a file ElastiCORE rewrites on every generation - `blueprint/schema.yml`, the copied guides, the default `i18n/<domain>-messages.properties`, a generated `orm.xml` | Refused |
| Claude edits a generated file that has a preserved block | Allowed, with a reminder that only the block survives regeneration |
| Claude runs Gradle with `-Pforce`, or sets the property another way (`-P force`, `ORG_GRADLE_PROJECT_force`, ...) | Refused: it overwrites hand edits. You decide |
| Claude changes the model under `src/main/resources/blueprint/<domain>/` | Told to run `./gradlew compileJava` and fix the warnings before finishing; on a build without the `elasticore { }` block, also told that the 2.x generator ignores access rules, lifecycles and derived values |
| A Gradle build - successful or failed - prints DSL validation warnings, a YAML file it could not read, or hand-edited generated files | Told what that means and what to do |
| Claude is about to finish while no successful build has generated and compiled its DSL change | Sent back once to build. A build in the background, cut short or filtered, or one that only generated, does not count |

The hooks see the edit tools and Gradle runs through Bash or PowerShell. The output of a successful
command too long for Claude Code to pass on is read from the file it saves it to; of a failed one,
Claude Code passes on only the first 10,000 characters, so in a very large project the warnings may
be past what the hook sees. An edit made another way - a script through a shell - is not stopped;
the skill tells Claude not to make one.

To let Claude edit generated files anyway, set `ELASTICORE_ALLOW_GENERATED_EDITS=1`, and
`ELASTICORE_ALLOW_FORCE=1` for `-Pforce`, for example in `.claude/settings.local.json`:

```json
{ "env": { "ELASTICORE_ALLOW_GENERATED_EDITS": "1" } }
```

## Keeping up with ElastiCORE

- **The kit holds no copy of the DSL documentation** - only the one-page reference and the recipes,
  which the contract test checks against the newest release. The full guides are the ones every
  generation copies into the project's `src/main/resources/blueprint/`, from the ElastiCORE
  version the project uses, and the skill sends Claude there for everything the reference does not
  have. When a project upgrades ElastiCORE, Claude reads the new guides. The guides are in Korean;
  the kit's own pages are in English.
- **What the kit does rely on is tested against ElastiCORE.** The new-project template and the
  worked example, the file markers, both generators' status lines and warning headers, the guide
  names, the Gradle tasks and what the started application answers are checked by
  [`tests/contract/check.py`](tests/contract/check.py): it builds the template, the example and a
  2.x-generator project with the newest ElastiCORE 3 release from Maven Central, and generates,
  edits, breaks, restores and starts them. CI runs it on every change and every Monday; a failure
  names the assumption that no longer holds and where the kit states it.

## Develop

```bash
bash tests/hooks/test-hooks.sh                     # the hook script, on the JSON Claude Code sends (HOOK_BASH=/bin/bash for another shell)
python3 tests/contract/check.py                    # JDK 17 and Gradle 8.14 or later on the PATH
claude plugin validate ./plugins/elasticore --strict
claude plugin validate . --strict
claude --plugin-dir ./plugins/elasticore           # try the working copy in an ElastiCORE project
```

`ELASTICORE_VERSION=3.0.261015-alpha1 python3 tests/contract/check.py` checks a given release. A
version ending in `-SNAPSHOT` is also looked up in the local Maven repository, so a build of
ElastiCORE published there with `publishToMavenLocal` can be checked before its release. The library
recipe's contracts run with 3.0.261021 or later; with an older version the summary line counts them
as skipped.

## License

[Apache License 2.0](LICENSE)
