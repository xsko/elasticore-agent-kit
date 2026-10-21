# Grading one project of the library-API comparison

These are the instructions the grader received, as given. The grader was an agent of its own (a
Claude Code general-purpose agent) with no part in the runs; it graded one project at a time.

---

You grade a Spring Boot project an AI agent built from `prompt.md` (next to the `project/` folder).
Grade what the project does, not what its README or the agent claims. The same checklist and the
same standard for every project; do not compare projects while grading.

Rules:
- Work only inside the arm's folder. Do not edit the project's source - grading must not fix it.
  You may write scratch files (logs, JSON bodies) under `ARM/grading/`.
- Find the endpoints from the code (controllers, README) and use the real paths and shapes.
- Use the port given for the arm. Start the server from a built jar in the background with
  `--server.port=PORT`, and stop it when done - only the process you started; check its command line
  before stopping it. Never stop processes by name. Set `TEMP`/`TMP` to `ARM/grading/tmp` and
  `-Djava.io.tmpdir` likewise.
- If the build fails or the server does not start, every runtime item below is FAIL (say why).
- For each item give PASS, FAIL or PARTIAL with one line of evidence: the request and the status
  or response, or `file:line`.

## Checklist

| Item | Check |
|---|---|
| B1 | `gradlew build` (or `gradle build` when there is no wrapper) succeeds, tests included. |
| B2 | The server starts on the port. |
| K1 | Creating a book with valid data succeeds and returns it with its id. |
| K2 | An ISBN of 12 digits, one of 14, and one with a letter are each refused (400). |
| K3 | A second book with the same ISBN is refused with 409. |
| K4 | An empty title, a 201-character title, a missing author, a year of 1449 or 2101, and -1 copies are each refused (400). |
| K5 | A book can be read by its id; an unknown id answers 404. It can be updated and deleted. |
| K6 | The book list is paged and sorted by title ascending. |
| K7 | A search by part of the title, and one by part of the author, find the matching books only. |
| M1 | Creating a member succeeds; the joining date is set by the server (a value in the request is ignored). |
| M2 | An invalid e-mail is refused (400); a second member with the same e-mail is refused with 409. |
| M3 | A member can be read, updated and listed. |
| L1 | A loan of an existing book to an existing member succeeds; the loan date is today and the due date is 14 days later, both set by the server; the return date is empty. |
| L2 | A loan with an unknown member, and one with an unknown book, are each refused with 404. |
| L3 | When every copy of a book is out (copies minus unreturned loans = 0), another loan is refused with 409; after a return it succeeds again. |
| L4 | Returning a loan records its return date. |
| L5 | Returning a loan that is already returned is refused with 409. |
| L6 | A member's loans can be listed, and filtered to the unreturned ones only. |
| L7 | A book's loans can be listed, and only that book's. |
| D1 | README.md says how to run the server and lists the API (method, path, an example). |
| D2 | The agent's final message (last text in `events.jsonl`) matches what you found - note any claim that is false. |

## Report (your final message)

A table: item, verdict, evidence. Then: score = PASS count + 0.5 x PARTIAL count, out of 21;
the endpoints in one line; anything that broke the rules of the task (other ports or folders
used, processes stopped by name, servers left running, files outside the project).
