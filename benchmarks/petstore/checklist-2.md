# Grading one change request of the pet store experiment (phase 2)

An AI agent was given a working pet store project (committed in the project's own git repository as
"phase 1 as delivered") and the change request in `prompt.md` next to the `project/` folder. Grade
what the project does now, not what its README or the agent claims. The same checklist and standard
for every project; do not compare projects.

Rules:
- Work only inside the arm's folder. Do not edit the project's source. Scratch files go under
  `ARM/grading/`. `git -C project diff HEAD --stat` and `git -C project status` show what the agent
  changed; read them.
- Find the endpoints from the code and the README, and use the real paths and shapes. Sign-in is a
  session: keep the cookie.
- Use the port given for the arm. Build with `./gradlew.bat --no-daemon build`, start the jar in the
  background with `--server.port=PORT` and `--logging.file.name=ARM/grading/server.log`, stop only
  the process you started (check its command line first). Never stop processes by name. Set
  `TEMP`/`TMP` to `ARM/grading/tmp`.
- If the build fails or the server does not start, every runtime item is FAIL (say why).
- Each item: PASS, FAIL or PARTIAL with one line of evidence (request and status/body, or file:line).

## Checklist

B1  `gradlew build` succeeds, tests included.
B2  The server starts on the port.

S1  An item has a stock (0 or more, required): an item without it, or with -1, is refused (400);
    the sample items have stock.
S2  Ordering more than the stock is refused (409) and the message names the item; the stock of every
    line of that order is unchanged (no partial decrement).
S3  An accepted order decreases each line's item stock by its quantity.
S4  Cancelling an order puts the stock back.
S5  The administrator can change an item's stock; a customer cannot (403).

V1  A signed-in customer posts a review of an item: rating 1-5 and text 1-1000 required (0, 6, empty
    text, 1001 characters each 400); the time is set by the server.
V2  A second review of the same item by the same customer is refused (409).
V3  Another customer cannot change or delete it (403 or 404); the author can change and delete it;
    the administrator can delete it.
V4  Anyone (not signed in) lists an item's reviews, newest first; each shows the author's login and
    no other personal data (no email, address, password, birth date).

C1  Shipping an order as the administrator calls the courier (the fake one by default) and the order
    then carries a tracking number `TRK-<order id>`, visible in the order's answer.
C2  The courier's address is a setting (application properties); pointing it at an address that
    fails (a port nothing listens on, or a fake that answers an error) makes shipping fail with 502
    and the order stays PLACED. Use a second start of the server with that setting, or the project's
    own test, as evidence.

I1  An Apache Ossie semantic model file is produced by the build (e.g. `blueprint/semantic_model.yml`)
    and defines the four measures: revenue without cancelled orders, order count without cancelled,
    average order (revenue / count), customer count.
I2  The administrator's sales summary now returns the average order value, and it equals revenue /
    order count of the orders made during grading.

L1  With `Accept-Language: ko`, a 400 for an invalid field answers the field message in Korean;
    without the header, in English.

R1  Phase 1 still works: sign-up, sign-in, an order's amounts (VAT 5.5 %, discount 2.25 %), cancelling
    a shipped order 409, no card number or password in any answer.

F1  How the change sits on the generated code: run `./gradlew.bat --no-daemon elcore3` in a copy of
    the project (not in the project) and report its summary line and any `SKIP(user-modified` line;
    PASS when there is none. List the files the agent changed (`git diff HEAD --stat`, `git status`)
    split into: DSL files, generated files (first line `//ecd:` and no `Initially generated` line),
    files the developer owns, new hand-written files.
D1  README.md describes the new API, the changed settings and the hand-written files.
D2  The agent's final message (last text in `events.jsonl`) matches what you found - note any false
    claim.

## Report (your final message - the whole report, not a pointer to an earlier one)

A table: item, verdict, evidence. Then: score = PASS + 0.5 x PARTIAL, out of 20; the files table of
F1; anything that broke the rules of the task (other ports or folders, processes stopped by name,
servers left running, files outside the project).
