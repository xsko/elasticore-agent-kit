# Pet store: what an agent builds with the kit, and what it still writes by hand

A shop task - catalog, members who sign in, orders with a lifecycle and prices the server works out,
an administrator's report, a static page - given to Claude Code with the kit, in three arms:
Java hexagonal, Java ddd and Kotlin hexagonal. Each result was built, started and called by a
separate Claude Code agent with `checklist.md` (24 items). The point was not the score: it was to
find where the agent left the DSL - the long guides it searched, the jar it opened, the Java it wrote
- and to fix ElastiCORE or the kit there. Then the same task again with the fixes.

## Files

| File | What |
|---|---|
| `task.ko.md` | the task, in Korean as it was given (`{TOOL_LINE}`, `{LANG_LINE}`, `{PORT}` filled by the runner) |
| `checklist.md` | the grader's 24 items |
| `task-2.ko.md`, `checklist-2.md` | the change request given on top of a finished project (stock, reviews, a courier API, BI measures, Korean messages), and its 20 items |
| `run_claude.py ROOT ARM PORT MINUTES` | one arm with Claude Code, headless, the kit's plugin loaded from a copy (`ARM`: `hex-java`, `ddd-java`, `hex-kotlin`, `ddd-kotlin`) |
| `run_change.py ROOT FROM_ARM NEW_ARM PORT MINUTES` | the change request on a copy of a finished arm, committed first so the change reads as a diff |
| `struggles.py EVENTS.jsonl` | where an arm left the kit: guide searches, jar lookups, errors, hand-written files |
| `fusion_check.py PROJECT [--force]` | how hand code sits on generated code: files by owner, `elcore3` on a copy (any `SKIP(user-modified)`), `-Pforce` and a build |
| `final_message.py EVENTS.jsonl` | turns, time, cost and the agent's last message |

The runners are written for Windows (taskkill, netstat, PowerShell).

## Round 1 - ElastiCORE 3.0.261021 before the fixes, kit 0.3.0

All three arms 23.5 of 24 (each lost half a point on README examples); no false claim in any final
message; regenerating each project changed no file and `-Pforce` builds.

| Arm | Time | Cost | Turns |
|---|---|---|---|
| Java hexagonal | 8 min 06 s | $1.46 | 50 |
| Java ddd | 8 min 40 s | $1.25 | 42 |
| Kotlin hexagonal | 30 min 53 s | $2.09 | 72 |

What every arm did outside the DSL, and what changed because of it:

| Seen in round 1 | Now |
|---|---|
| searched the long guides for value objects, `@login`/`@access`, `states:`, `@snapshot`/`@compute` in its first two minutes | on the quick reference, with `recipe-shop.md` as a whole model |
| ran `javap` on `CurrentUser`, `SessionCurrentUser`, `Money` and the exceptions | a table of the runtime classes on the quick reference |
| wrote a sign-in controller (sign in, sign out, who am I) | generated with `@signin` (ElastiCORE) |
| patched the error handler to answer a refused state step 409 instead of 422 | 409 generated |
| looked up every referenced row to answer 404 | generated (`requireReferences`), 404 |
| set the order time in `beforeSave` | `@readonly @default(now)`, on the quick reference |
| wrote the administrator's role check by hand | `ACCESS.require(currentUser, "report")`, in the recipe |
| (the Kotlin arm) missed `@past` after a grep error, lost seven minutes in a script that started and called the server in one call | on the quick reference; `run-and-check.md` |

Writing the shop recipe found two more ElastiCORE bugs: an optional embedded address with required
fields refused every order without it (NOT NULL columns), and a model file that did not parse was
dropped while the build succeeded.

## Round 2 - after the fixes

ElastiCORE 3.0.261021 with the sign-in, 409/404 and timestamp fixes, kit 0.4.0 with `recipe-shop.md`.

| Arm | Score | Time | Cost | Turns |
|---|---|---|---|---|
| Java hexagonal | 24 / 24 | 7 min 25 s | $0.86 | 28 |
| Java ddd | 23 / 24 | 8 min 49 s | $1.01 | 37 |
| Kotlin hexagonal | 24 / 24 | 9 min 14 s | - | - |

The ddd arm lost a point on README curl examples and a final message that said its server was
stopped while it was still listening. No arm searched the long guides for the shop's features or wrote
a sign-in controller or a role check; the jar was opened once, for `Money`. Hand code left: the
start-up data, the report endpoint, the event listener, VAT and discount in the owned service.

A caveat for reading round 2: `recipe-shop.md` was written after round 1 and is close to this task
(members, products, orders), so round 2 measures the kit with a recipe for the task's domain.

## Phase 2 - a change request on each round-2 project

`task-2.ko.md` on a copy of each finished project, committed first so the change reads as a diff;
graded with `checklist-2.md` (20 items).

| Arm | Score | Time | Cost | Turns |
|---|---|---|---|---|
| Java hexagonal | 20 / 20 | 13 min 24 s | $1.67 | 56 |
| Java ddd | 19.5 / 20 | 14 min 11 s | $2.02 | 70 |
| Kotlin hexagonal | 20 / 20 | 13 min 58 s | $1.77 | 70 |

Regenerating each changed project on a copy wrote nothing and reported no `SKIP(user-modified)`: the
hand code sat on owned files only. What the graders and the transcripts found, and what changed:

| Seen in phase 2 | Now (ElastiCORE 3.0.261021, kit 0.4.0) |
|---|---|
| all three searched the long guides for `metrics:` and `ossie-export` | on the quick reference |
| built-in validation messages in the machine's language next to English DSL messages; each arm set `spring.web.locale` or wrote `ValidationMessages.properties` | one language per answer: `Accept-Language`, else `spring.web.locale`, never the machine's |
| a hand rule in an `update()` override was bypassed by `PUT /batch` (an admin edited a member's review) | `batchUpdate` calls `update()`; the quick reference points to `beforeSave` |
| a review could be moved to another item | `@updatable(false)` on a reference works |
| the TypeScript client kept the phase-1 model (`elcore3ts` is a task of its own) | `typescriptClient = true`, and a warning when the client is older than the model |
| a courier failure needed a hand-written exception and handler for 502 | `PortCallException`, 502 |
| an unknown enum value answered Spring's default body | problem+json with `fieldErrors` for every request error |
| `count(Customer)` exported as a bare `COUNT(*)` | the metric names its dataset |
| name search kept case | `@search(like)` ignores case on the rule engine |

Left as hand code, as business logic: stock taken on order and put back on cancel, the reviewer's
login stored on the review, the courier call itself.
