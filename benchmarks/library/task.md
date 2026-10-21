# The task: a library loan API

This is an English rendering of [task.ko.md](task.ko.md), the Korean text every agent received.
The runners fill two placeholders: `{PORT}` with the arm's port, and `{TOOL_LINE}` with nothing
for the arm without the kit, or with this line for the arm with it:

> Build it with ElastiCORE (a tool that generates Spring Boot code from a YAML DSL). The ElastiCORE
> version is VERSION.

(When VERSION ends in `-SNAPSHOT` the line adds: "and it is in the local Maven repository: put
`mavenLocal()` before `mavenCentral()` in `pluginManagement` of `settings.gradle` and in
`repositories` of `build.gradle`.")

The prompt starts with one line before the task: "Do the task below to the end. Do not ask
questions; decide for yourself and proceed."

---

Build a Spring Boot 4 REST API server in this (empty) folder. No screens, no sign-in, no
permissions.

- Java 17 or later, Gradle with the Gradle wrapper, an in-memory H2 database.
- Port 8080 is used by another program on this PC. When you start the server to check it, use port
  `{PORT}`.
- Other people's programs (Java among them) run on this PC. Do not stop processes by name. Stop a
  server you started the way you started it (for example, keep a note of the background job).

## Features

1. Books: ISBN (13 digits, required, 409 when it exists), title (1 to 200 characters, required),
   author (1 to 100 characters, required), year of publication (1450 to 2100), copies owned (0 or
   more, required). Create, read one, update, delete. The list is paged, sorted by title ascending,
   and can be searched by part of the title or part of the author.
2. Members: name (1 to 50 characters, required), e-mail (format checked, required, 409 when it
   exists), joining date (set by the server). Create, read one, update, list.
3. Loans: a loan names a member and a book. The loan date and the due date (loan date + 14 days)
   are set by the server; the return date is empty until the loan is returned.
   - No loan for an unknown member or an unknown book (404).
   - No loan when the book's remaining copies (copies owned minus unreturned loans) are 0 (409).
   - Return: returning a loan records its return date. Returning a loan that is already returned
     is a 409.
   - A member's loans (it must be possible to see only the unreturned ones) and a book's loans.
4. Bad input answers 400, missing data 404.

## Before you finish

- `./gradlew build` must succeed.
- Start the server on port `{PORT}` and check for yourself: create a book and a member, loan, 409
  when no copy is left, return, 409 on a second return. Stop the server afterwards.
- Write README.md: how to run it and the API (method, path, an example curl).
