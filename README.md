# ElastiCORE agent kit

A [Claude Code](https://code.claude.com) plugin, also packaged for [opencode](https://opencode.ai),
for projects built with [ElastiCORE](https://github.com/xsko/ElastiCORE) - Spring Boot applications
generated from a YAML DSL.

Left to itself, an agent edits the generated Java. The next build either overwrites the edit or
stops updating the file from the model, and nobody notices. With this plugin the agent changes the
DSL, regenerates, compiles, and tells you what changed for the business.

[한국어](README.ko.md)

## Measured: one task, with and without the kit

A task neither agent had seen before - a library loan API: books keyed by a 13-digit ISBN, members
with a unique e-mail and a joining date the server sets, loans whose dates the server sets, a 409
when no copy is left, a return operation, and "not yet returned" as a search. Each agent got the
same text, once with the kit and once without, and an independent grader built, started and called
every project against 21 checks (2026-10-21, one Windows PC, the Gradle builds inside the times;
kit 0.3.0 with a pre-release build of ElastiCORE 3.0.261021).

| Agent | Without the kit | With the kit |
|---|---|---|
| Claude Code, Sonnet | 4 min 41 s, 20.5 of 21 - every entity, DTO, repository, service, controller and error handler written by hand | **2 min 18 s, 20.5 of 21** - one 27-line YAML, two service methods, one controller |
| opencode, a small local model (`qwen3.8-flash-next-a5b`) | did not finish in four attempts - each stalled in a shell call that never returned | **11 min 42 s, 21 of 21** |

With the kit, Claude Code read the one-page reference and the library recipe, wrote the YAML,
generated, added the two methods and the controller the recipe gives, built, started the server,
sent fifteen requests - 400 for a bad ISBN, 409 for a duplicate, for a loan with no copy left and
for a second return, 404 for an unknown member - stopped the server by its process id and reported,
naming what it had not checked. It opened no guide and no jar. The grader found no claim that did
not hold; the half point is the jar name in its README.

The same task is where ElastiCORE 3.0.261021 got `@readonly`, `@search(isnull)`, `@pattern` with a
message, `ref: Entity!` and `ConflictException`: the kit's first run on it showed what an agent
still had to write in Java, and the DSL took that over. The kit's earlier page sent agents into a
Gradle call that never returns on Windows and cost one run ten minutes; [CHANGELOG.md](CHANGELOG.md)
has the numbers before and after.

## Install

```bash
claude plugin marketplace add xsko/elasticore-agent-kit
claude plugin install elasticore@elasticore-agent-kit
```

In a session: `/plugin marketplace add xsko/elasticore-agent-kit`, then
`/plugin install elasticore@elasticore-agent-kit`.

It works in an existing ElastiCORE 3.0 project, and starts a new one: ask for an application "with
ElastiCORE" and Claude sets it up from the release on Maven Central with a template that CI builds
every week - it does not build ElastiCORE from source or look through other projects on your machine.

The hooks run in bash: macOS and Linux have it, and on Windows Claude Code runs hooks with Git Bash.
On Windows without Git Bash, Claude Code reports a hook error on every edit and command - install
Git for Windows, or disable the plugin.

**opencode:** clone this repository and run `opencode/install.sh` (or `opencode/install.ps1`). It
installs the same skill and hook script, an opencode plugin that runs them, and the agents and
commands as opencode's own - see [opencode/README.md](opencode/README.md).

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

## What you get

| Part | What it does |
|---|---|
| Skill `elasticore` | Loads when Claude works in an ElastiCORE project or starts one. It starts with a fast path: a one-page DSL reference, two complete recipes - posts and comments (CRUD, validation, search, paging, time stamps), and books, members and loans (rules on other rows, values the server sets, an operation of its own; ElastiCORE 3.0.261021 or later) - and how an agent runs and checks the application. Then: which generator the build runs and what each supports, how to tell generated files from yours, where a change belongs, the loop (change the DSL, `./gradlew compileJava`, read the generator's warnings), what to ask you first, and how to report. Everything the reference and the recipes show is generated, built and called by the contract test - the library recipe when the ElastiCORE under test is 3.0.261021 or later; for the rest it sends Claude to the guides ElastiCORE copies into the project. |
| Hooks | Stop edits to generated files and `-Pforce` runs, say what to run after a DSL change, pass on the generator's warnings, and keep Claude from finishing with a DSL change that no successful build has generated and compiled. |
| Agent `elasticore:modeler` | Turns a requirement into a DSL change that generates and compiles, and reports it in business terms. |
| Agent `elasticore:reviewer` | Reviews a change: hand edits to generated files, DSL the guides or the generator do not know, generated code out of step with the DSL, and who gains or loses what. |
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

- **The kit holds no DSL reference.** Every generation copies the guides of the ElastiCORE version a
  project uses into its `src/main/resources/blueprint/`, and the skill sends Claude there. When a
  project upgrades ElastiCORE, Claude reads the new guides.
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
