---
name: report-issue
description: Draft an issue for xsko/ElastiCORE when ElastiCORE itself falls short - generated code that does not compile or is wrong while the DSL is right, a generator error or exception, a requirement the DSL cannot say so that you had to write a workaround, or a guide that says one thing while the build does another. Reproduces it in a minimal project first, searches the existing issues, removes private details, and shows the draft; posts only after the user says yes.
argument-hint: "[what went wrong, in a few words]"
---

# Report an ElastiCORE issue

Use this when the fault is ElastiCORE's, not the project's: the DSL is right by the project's guides
and still the generated code does not compile, does the wrong thing, or the generator throws; or the
DSL has no way to say what the requirement needs and the agent had to write code around it; or a
guide says X and the build does Y. A DSL warning that names what to change, a model check that
fails with the fix in its message, or a compile error in code the developer wrote is not one -
fix those in the project.

You never post on your own. The issue goes to a public repository: the user reads the whole draft
and says yes first.

## 1. Reproduce it in a minimal project

1. Write down what the project uses: the ElastiCORE version (the `io.elasticore` plugin line in
   `build.gradle`, or `gradle.properties`), `architecture`, `language` and `output` in the
   `elasticore { }` block, `mode:` in `env.yml` (JPA by default, `mybatis`, `mongo`), the Spring Boot
   version, `typescriptClient`.
2. Make a new folder outside the project - in the system temp folder, never inside the user's
   repository - and set up the smallest project the elasticore skill's `references/new-project.md`
   describes, with the **same** ElastiCORE version and settings. If the project's version is not the
   newest release on Maven Central, try the newest too, and say in the report which versions show it.
3. Copy in only what the problem needs: one domain, the `env.yml` keys that matter, the one or two
   entities or DTOs. Rename business names that are not needed to show it (`Order`, `Item`,
   `Customer` are fine).
4. Run the same build (`./gradlew compileJava`, `./gradlew.bat` on Windows) and confirm the same
   error or the same wrong output. If it does not reproduce, add back what you left out until it
   does; if it never does, the cause is in the project - say so and stop.
5. Keep the exact evidence: the build lines (`[elcore3]` lines, `=== elcore3: ... ===`, the
   warning or the exception with its first stack frames), and the part of the generated file that is
   wrong, with its path below the project.

## 2. Look for the same issue

Search the open **and closed** issues of xsko/ElastiCORE for the annotation, the error text and the
generated class: `gh issue list -R xsko/ElastiCORE --state all --search "<words>" --limit 20`
(or the issues page in a browser). Read the ones that look close. If one describes the same
problem, do not draft a new issue: draft a comment for that one instead - what the reproduction
adds (another version, mode or architecture it happens in, a smaller model) - and treat it as below.
A closed issue that should have fixed it: say which version you ran, and that it still happens.

## 3. Fill the repository's template

Read the templates of the repository - `.github/ISSUE_TEMPLATE/bug_report.md` and
`feature_request.md` in xsko/ElastiCORE (`gh api repos/xsko/ElastiCORE/contents/.github/ISSUE_TEMPLATE/bug_report.md
-H "Accept: application/vnd.github.raw"`, or the files in a checkout) - and use the one that fits,
keeping its headings. The templates change; do not use a copy from memory.

- **A defect** (bug report): the version and how it generates, the Boot version and language, the
  smallest `env.yml` and model YAML from step 1, the wrong part of the generated file, what was
  expected, the build output.
- **A gap** - the DSL cannot say what the requirement needs (feature request): write it as a need,
  not as a design:
  - the need, in words: the business rule or structure, with the example entity;
  - what the guide says about it, quoted with the guide's name and section, when one does;
  - what you write today - the workaround, as YAML and code - and what it costs (code nothing
    calls, types the screens cannot use, a rule checked by hand);
  - what you would expect generated, as behaviour, and what a developer gains;
  - what was not checked (other modes, Kotlin).

  **Do not propose new DSL syntax** - no new annotation, keyword or YAML key, not even "a sketch".
  Where the template asks how to write it in the DSL, write that the maintainers decide the form,
  and describe the expected behaviour instead. Whether to add a word to the DSL is the
  maintainers' decision.

## 4. Remove what is not the user's to publish

Before you show the draft, go through it line by line and take out or replace:

- company and product package names (`com.<company>....` becomes `com.example....`) and the
  project's name;
- business entity and field names that the problem does not need (keep a name only when it is the
  point, such as a reserved word);
- host names, URLs, IP addresses, ports of internal systems, database names;
- file system paths (keep only the path below the project: `src/main/java/...`);
- user names, e-mail addresses, credentials, tokens, keys, passwords, connection strings, personal
  data in sample rows.

## 5. Show it, and post only on yes

Show the user the whole draft: the title, the body, the labels the template sets, and whether it is
a new issue or a comment on an existing one (with its number). Ask: "Post this to xsko/ElastiCORE?"

- Only on an explicit yes, post it with the user's GitHub CLI:
  `gh issue create -R xsko/ElastiCORE --title "<title>" --body-file <file> --label <label>`
  (a comment: `gh issue comment <number> -R xsko/ElastiCORE --body-file <file>`), and give the
  user the link it prints.
- Anything else - no, a change wanted, no answer, a run with nobody to ask - posts nothing. Change
  the draft if asked and show it again.
- Without `gh` (or not signed in), print the title and body for the user to copy into
  https://github.com/xsko/ElastiCORE/issues/new/choose.

Keep the minimal project folder until the user has decided; tell them where it is, since the
maintainers may ask for it.
