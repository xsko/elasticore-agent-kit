---
name: contribute
description: Work on ElastiCORE itself, in a checkout of xsko/ElastiCORE - plan the change for an issue before writing code (where it goes, every JPA/MyBatis/MongoDB x Java/Kotlin/TypeScript x layered/ddd/hexagonal combination it reaches, the tests, the 2.x compatibility checks, the English and Korean guides, the changes/ fragment, the target branch), then build it by the checkout's CONTRIBUTING.md. Use when the working folder is an ElastiCORE checkout (elasticore-project/elasticore-base) and the user names an issue or asks for a change to the generator, its runtime libraries or its guides.
argument-hint: "<issue number> [plan | build]"
---

# Contribute to ElastiCORE

This is for a checkout of ElastiCORE itself - a folder with `elasticore-project/elasticore-base`
and a `settings.gradle` that includes it. In a project that *uses* ElastiCORE, use the `elasticore`
skill instead. Here the samples and templates are generated and edited on purpose, so the kit's
user-project guards are off; the hooks check the checkout's own rules instead (no edit of
`elasticore-history.md`, ASCII-only `elasticore-base` main sources, both guide languages, a fragment
and the format gates before a push).

## 0. The rules are the checkout's, not this page's

Read them first, every time - they change with the version, and this page does not copy them:

- `CONTRIBUTING.md` - the checks that must pass, the gates on changed lines, adding a rule, what
  the codebase learned the hard way, pull requests;
- `changes/README.md` - the change fragment's form (a checkout without `changes/` predates it: there
  the history is edited directly, as its CONTRIBUTING says);
- `BRANCHING.md` and `RELEASING.md` when the target branch or a release is in question;
- a `CLAUDE.md` or `AGENTS.md` in the checkout, if there is one.

Where this page and those files disagree, they win.

## 1. Read the issue

`gh issue view <number> -R xsko/ElastiCORE --comments` (or the issue page). Note what is asked,
what the reporter writes today, what was agreed in the comments, and what was left open. A
feature that is not agreed yet - no maintainer said to build it - gets a plan and questions, not
code. Do not add DSL words the issue does not ask for.

## 2. Plan before code

Write the plan and show it to the user. With `plan` (or no second argument) stop there; build only
after the user agrees, or when they asked for `build`. The plan names:

1. **Where the change goes**, by reading the code, not by guessing: the model loader(s) - one per
   mode, and a field added to the model has to reach every one; the rule set(s) under
   `elasticore-base/src/main/java/io/elasticore/base/model/pub/rules/` and their registration; the
   templates per language; the runtime libraries (`elasticore-springboot3`, `-springboot4`) when
   generated code calls them; the Gradle plugin when a task or setting changes. Name the files.
2. **The combinations it reaches.** A table: JPA / MyBatis / MongoDB x Java / Kotlin / TypeScript
   client x layered / ddd / hexagonal (and Spring Boot 3 / 4 where it differs). For each cell: works,
   not applicable, or left out **with the warning the build prints there**. A combination left out
   keeps a clear warning - never silently nothing.
3. **Every path end to end.** Follow the value from the YAML to what the running application
   answers: a field declared in a DTO is also filled by the mapper, read by the service, written by
   the repository, shown in the TypeScript type; a new check is reached from every way in (REST,
   GraphQL, the domain helper).
4. **The tests.** Unit tests that fail without the change (say how you will see them fail), and a
   run-level test in a sample module - generated, compiled and called - that shows the real
   generated output. A test that only checks that the build passes is not enough: check the output
   itself. Add the DSL to a template sample when the template does not declare it yet, so the
   compatibility checks compare it from then on.
5. **2.x compatibility.** Whether the change can move what an existing project generates, and the
   checks that prove it does not: `./gradlew build` leaving the 2.x template as committed,
   `elcoreRulesCheck -Pstrict` and `elcoreTreeCheck` with the numbers CONTRIBUTING gives.
6. **The guides**, in English (`elasticore-guide/`) and Korean (`elasticore-guide/ko/`), at the same
   lines, with the environment markers the guides use (which modes, languages, Boot versions).
7. **The change fragment** `changes/<topic>.md`, in the form `changes/README.md` gives.
8. **The target branch.** A pull request branches from the latest `main`. A change to what existing
   projects generate goes to `main` only; split an additive part (a new word, a new warning) and an
   output-changing part into two pull requests. Whether a fix also goes to a release line is in
   `BRANCHING.md`.
9. **Open questions** for the owner - anything the issue does not settle.

## 3. Build it

- One concern per branch and pull request; one commit and one fragment per fix.
- `elasticore-base` main sources are ASCII only; files are read and written with explicit UTF-8.
- Never edit `elasticore-history.md` on a feature branch; never commit the guide copies in the
  samples' `blueprint/`.
- Run the targeted tests of what you changed, then the checks CONTRIBUTING lists for generation
  changes. One Gradle build at a time, with `--no-daemon` from an agent's shell.
- Before every push: rebase on the latest `origin/main`, then `./gradlew formatChanged` (commit what
  it changes), then `./gradlew formatCheck diffErrorprone -PdiffBase=origin/main` (or
  `./gradlew prCheck` for all four gates). CI must not be the first to find a format or Error Prone
  finding.
- Push the branch; open a pull request only when the user asks.

## 4. Report

What changed and why; the combinations table as built (with the warning text of each one left out);
the tests added and that they failed before the change; the compatibility check lines; the guides
and the fragment; what is left open.
