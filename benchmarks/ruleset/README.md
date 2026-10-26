# Team rules: can an agent write a ruleset from the guides?

A change request on a finished library project (books, members, loans): put four team rules into
the generator as a ruleset in its own Gradle module - a `@pii` field that never leaves in a response,
a `@nodelete` entity with no delete API, a two-character minimum for `like` searches, a build that
fails on a page size over 50. The agent may only mark the model; it must not edit generated files.
`grade.py` builds, starts and calls the result - no judgement calls - and `guide_reads.py` shows
how the agent found out how ElastiCORE works: the guide index, the guides, the kit, or a jar.

## Files

| File | What |
|---|---|
| `task.ko.md` | the task, in Korean as it is given (`{TOOL_LINE}`, `{PORT}` filled by the runner) |
| `run.py TOOL ROOT BASE ARM PORT MINUTES` | one arm with Claude Code or opencode on a copy of `BASE`, generated once with `ELASTICORE_VERSION` and committed first so the change reads as a diff |
| `grade.py ARM_DIR PORT` | 17 items, PASS / FAIL with the evidence, on a copy of the arm's project; writes `grade.json` |
| `guide_reads.py LABEL EVENTS.jsonl ...` | per arm: calls and characters read from the index, the guides, the kit and jars |
| `reference/apply.py PROJECT` | applies the reference answer (`reference/library-rules`) - it must score 17 of 17 |

`BASE` is a library project built from `plugins/elasticore/skills/elasticore/references/recipe-library.md`; the contract test's `library`
project will do. The runners are written for Windows (gradlew.bat, taskkill). The agent may not stop
processes by name (`taskkill /IM`, `Stop-Process -Name`, `pkill`, `killall`, `wmic process`): `run.py`
denies those commands for Claude Code, `../library/opencode_config.py` for opencode, because an auto-approved run once stopped every Java process on the machine.

## Results

The reference answer scores 17 of 17 (a 3.0.261023 snapshot of ElastiCORE). The agent arms have not been
measured to the end yet - no numbers until they are.
