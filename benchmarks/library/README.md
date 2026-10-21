# One task, three agents, with and without the kit

How much does the kit change what a coding agent does with a Spring Boot task? Three agents got
the same task twice - once as written, once with the kit and the instruction to use ElastiCORE -
and an independent grader built, started and called every project against the same 21 checks.
This folder holds the task, the checklist, the runners and the numbers, so the comparison can be
read and repeated.

[한국어](README.ko.md)

## Setup

- **The task:** a library loan API - [task.md](task.md) (English) / [task.ko.md](task.ko.md) (the
  Korean text the agents received). Books keyed by a 13-digit ISBN, members with a unique e-mail
  and a joining date the server sets, loans whose dates the server sets, a 409 when no copy is left,
  a return operation, "not yet returned" as a search, 400/404/409 answers, a README with the API.
  **The kit's library recipe is this task's model and code**, written after the first round from
  what that round showed: the three runs with kit 0.3.0 wrote the recipe's 27-line `entity.yml`
  as it stands (byte for byte in all three) and its service methods and controller. So the
  with-kit numbers are for a task the kit has a recipe for; the first round (kit 0.2.0, under
  *Earlier runs*) is the number for a task it has none for.
- **One prompt, no questions:** each run started in an empty folder with the task, a port of its own
  and the instruction to decide for itself; nobody answered during a run. The Claude Code and
  Codex runs had a 25-minute limit (only the Codex with-kit run reached it, after its answer -
  see *Earlier runs*); the opencode rounds had a longer one that no run reached - the attempts
  without the kit ended on their own, exit code 1, minutes after the call that hung.
- **The arms:**

  | Agent | How it ran | The kit, when given |
  |---|---|---|
  | Claude Code, Sonnet | `claude -p --model sonnet`, permissions bypassed, no user settings or MCP servers ([run_claude.py](run_claude.py)) | the whole plugin through `--plugin-dir`: skill, hooks, agents, commands |
  | Codex CLI 0.163.0, `gpt-5.6-sol`, reasoning low | `codex exec --json`, no sandbox, no approvals ([run_codex.py](run_codex.py)) | the skill copied to the project's `.agents/skills/elasticore` - the skill only; the hooks are Claude Code's and opencode's |
  | opencode, `qwen3.8-flash-next-a5b` (a small model on a local vLLM server) | `opencode run --auto` in an isolated config that refuses process kills by name ([run_opencode.py](run_opencode.py)) | the skill and the kit's opencode plugin, which runs the hook script |

- **Versions:** kit 0.3.0 and a pre-release build of ElastiCORE 3.0.261021 (published to the local
  Maven repository as `3.0.261021-SNAPSHOT`; the task says so). Earlier runs with kit 0.2.0 and
  ElastiCORE 3.0.261020-alpha2 are under *Earlier runs*.
- **Grading:** [checklist.md](checklist.md), 21 items, PASS / PARTIAL / FAIL with evidence per item;
  score = PASS + 0.5 x PARTIAL. The grader was a separate Claude Code agent that had no part in the
  runs; it built each project, started it on the arm's port and sent the requests itself. It also
  checked the agent's final report against what it found (item D2) and looked for broken rules -
  other ports, processes stopped by name, servers left running.
- **Measuring:** wall time from the start of the agent's process to its exit (Claude Code,
  opencode) or to its final answer (Codex - see *Earlier runs* for why). Token counts come from each
  tool's own records: Claude Code's `result` events, Codex's session rollout (`token_count` per
  API call), opencode's `step_finish` parts ([usage.py](usage.py)). "Context read" is every prompt
  token the model read over the run, cache hits included; "peak" is the largest single prompt.
- **Where:** one Windows 11 PC, Gradle and dependencies already in the local caches. The first
  round (the runs without the kit, kit 0.2.0) ran on 2026-10-20, the kit 0.3.0 and Codex runs on
  2026-10-21.

## Results

| Agent | Without the kit | With the kit |
|---|---|---|
| Claude Code, Sonnet | 4 min 41 s, **20.5** of 21 | **2 min 18 s**, **20.5** of 21 |
| Codex CLI, `gpt-5.6-sol` | 7 min 13 s, **21** of 21 | **3 min 45 s**, **21** of 21 |
| opencode, `qwen3.8-flash-next-a5b` | no run reached a final report in four attempts; the best was graded 19.5 of 21 without a README | **11 min 42 s**, **21** of 21 |

| Run | Model calls | Context read | of it from cache | Peak prompt | Output tokens | Cost |
|---|---|---|---|---|---|---|
| Claude Code, without | 16 | 657k | 618k | 56k | 26.0k | $0.48 |
| Claude Code, with | 10 | 437k | 400k | 54k | 7.5k | $0.26 |
| Codex, without | 29 | 1,000k | 947k | 47k | 14.6k | (subscription) |
| Codex, with | 24 | 859k | 817k | 45k | 9.5k | (subscription) |
| opencode, without (attempt 4) | 66 | 1,396k | 0 | 34k | 16.9k | local |
| opencode, with | 48 | 1,993k | 0 | 62k | 15.2k | local |

The half point Claude Code lost without the kit: its final report said the integration test had
checked the 404 for an unknown book as well as for an unknown member; it checked only the member.
With the kit: the README named the jar `library-0.0.1-SNAPSHOT.jar` while the build produced
`library.jar`. The grader found no false claim in either Codex report and none in opencode's run
with the kit.

## What each agent did

- **Claude Code without the kit** (16 calls): wrote every entity, DTO, repository, service,
  controller and the error handler by hand, built, started the server, ran its checks, wrote the
  README and a test.
- **Claude Code with the kit** (10 calls): read the skill's one-page reference and the library
  recipe, wrote one 27-line YAML, generated, added the two service methods and the one controller
  the recipe gives, built, started the server, sent fifteen requests (400 for a bad ISBN, 409 for a
  duplicate, for a loan with no copy left and for a second return, 404 for an unknown member),
  stopped the server by its process id and reported, naming what it had not checked. It opened no
  guide and no jar.
- **Codex without the kit** (29 calls): 23 Java files by hand, a test among them. Four builds
  failed before it found where Spring Boot 4 had moved `@AutoConfigureMockMvc`, with half a minute
  spent searching the jars under `~/.gradle`; then build, server, checks, README.
- **Codex with the kit** (24 calls): read `SKILL.md` and four of its pages (after four failed reads
  - it looked for them under `~/.agents/skills` first), wrote the recipe's 27-line YAML, generated,
  added the recipe's methods and its 25-line controller, one `--no-daemon` build, server, checks
  through 400, 404 and both 409s, stopped the server by the pid it had saved.
- **opencode without the kit:** four attempts of 9 to 32 minutes; each ended without a final report,
  stuck in a shell call that did not return - in the fourth, the call that started the server. That
  fourth attempt had a working server when it stopped - graded 19.5 - but no README.
- **opencode with the kit** (48 calls): the skill's path - YAML, generate, the recipe's methods,
  build, server, checks, README - in 11 min 42 s, 21 of 21.

## Earlier runs, and what they changed

- **Kit 0.2.0 with ElastiCORE 3.0.261020-alpha2 - the kit without a recipe for the task.** Claude
  Code with the kit: 7 min 47 s, 20.5, 21 calls, 1.1M context read - slower than without the kit.
  It read the kit's pages (the board recipe among them) and the generated sources, and wrote Java
  for what the DSL did not have: dates the server sets that a request could overwrite, "not yet
  returned" as a search, the ISBN format rule, a loan that had to send the nested member, a 409
  with its own message. Those became `@readonly`, `@search(isnull)`, `@pattern('re', 'message')`,
  `ref: Entity!` and `ConflictException` in ElastiCORE 3.0.261021, and the task's model and code
  became the library recipe in kit 0.3.0. opencode with the kit: 18 min 57 s, 19 (no README, no
  unreturned-only filter) and, on a second attempt, 34 min 2 s, 20.
- **Kit 0.3.0, first Claude Code run: 15 min 32 s, 21.** Ten of those minutes were one
  `sh ./gradlew build` that had finished in twelve seconds: on Windows the Unix wrapper script does
  not return from Claude Code's Bash tool when it starts a Gradle daemon (the daemon inherits the
  tool's pipe), so the call waited for its timeout and was then stopped in the background. The
  kit's page had sent the agent there. With the corrected page (`./gradlew.bat`, from Git Bash
  too) the same run took 2 min 18 s.
- **Codex: the process outlived its answer.** With the kit, Codex wrote its final report after
  3 min 45 s, but `codex exec` was still running when the 25-minute limit stopped it; without the
  kit it ended 6 minutes after its report. A Gradle daemon started inside one of its shell calls
  holds that call's pipe: reproduced with `gradle wrapper --gradle-version 8.14.3` (answer after
  16 s, process still alive after 5 minutes) and absent with `gradle --no-daemon wrapper ...`
  (ended with the answer). The kit's pages now say `--no-daemon` there, and `run_codex.py` sets
  `GRADLE_OPTS=-Dorg.gradle.daemon=false`. The Codex times above are to the final report, read
  from the session rollout ([timeline_codex.py](timeline_codex.py)).

## Caveats

- The library recipe is this task's solution, written from the first round. The with-kit results
  measure an agent that has a recipe for the task's domain; the kit 0.2.0 run is the one without.
- The task drove the five DSL additions of the ElastiCORE version under test, and that version
  (3.0.261021) is not on Maven Central yet; with 3.0.261020-alpha2 the recipe needs the hand-written
  checks its last section lists.
- The Claude Code with-kit number is a second run, after a fix the first run exposed (the Gradle
  call that never returned); the without-kit arm ran once.
- One run per arm (opencode without the kit: four). Run-to-run variation is not measured.
- The comparison is within each agent - the same agent, the same model, with and without the kit.
  The three agents differ in model, price and speed, and the numbers do not rank them.
- The task is one task, of the kind the kit's recipes are written for. A task the DSL cannot
  express would look different.
- The grader is an AI agent too. Its per-item evidence (requests, statuses, `file:line`) was kept
  for every run, and spot-checked; it is not in this repository.
- The kit's authors ran the comparison.
- Times include Gradle builds, with dependencies already cached on the machine, on a PC shared with
  other work.

## Reproduce

Windows (the runners use `taskkill`, `netstat` and PowerShell), with the agents installed and
signed in, JDK 17 and Gradle 8.14 or later on the PATH, and the ElastiCORE version the task names.
Until 3.0.261021 is on Maven Central, build it yourself: clone
[xsko/ElastiCORE](https://github.com/xsko/ElastiCORE) at the merge of its pull request 4 (commit
`879716d`), run `./gradlew publishToMavenLocal`, and set `ELASTICORE_VERSION=3.0.261021-SNAPSHOT`
- the runners then tell the agent to use the local Maven repository.

```bash
cd benchmarks/library
python run_claude.py  C:/tmp/exp plain      18101 25      # then: elasticore 18102
python run_codex.py   C:/tmp/exp plain      18111 25      # then: elasticore 18112
OPENCODE_MODEL=provider/model python run_opencode.py C:/tmp/exp plain 18121 25
python usage.py claude-plain C:/tmp/exp/plain/events.jsonl ...     # the token table
python timeline_claude.py C:/tmp/exp/plain/events.jsonl --sum      # where a Claude Code run's time went
python timeline_codex.py  C:/tmp/exp/plain/events.jsonl            # the same for Codex, from its rollout
```

`ELASTICORE_VERSION`, `KIT_DIR` and `TASK` change the version the task names, the plugin folder and
the task file. Run one arm at a time, give each its own port, and grade each project with
[checklist.md](checklist.md) - by an agent or by hand - without reading the other projects first.
