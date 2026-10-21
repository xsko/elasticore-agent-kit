# Grading one project of the pet store experiment

You grade a Spring Boot project an AI agent built from `prompt.md` (next to the `project/` folder).
Grade what the project does, not what its README or the agent claims. The same checklist and the
same standard for every project; do not compare projects while grading.

Rules:
- Work only inside the arm's folder. Do not edit the project's source - grading must not fix it.
  You may write scratch files (logs, JSON bodies, cookie jars) under `ARM/grading/`.
- Find the endpoints from the code (controllers, README) and use the real paths and shapes. Sign-in
  is session based unless the code says otherwise: keep the cookie (`curl -c/-b`).
- Use the port given for the arm. Start the server from a built jar in the background with
  `--server.port=PORT` and its log written to a file under `ARM/grading/` (`--logging.file.name`),
  and stop it when done - only the process you started; check its command line before stopping it.
  Never stop processes by name. Set `TEMP`/`TMP` to `ARM/grading/tmp` and `-Djava.io.tmpdir` likewise.
  On Windows run Gradle as `./gradlew.bat`.
- If the build fails or the server does not start, every runtime item below is FAIL (say why).
- For each item give PASS, FAIL or PARTIAL with one line of evidence: the request and the status
  or response, or `file:line`.

## Checklist

B1  `gradlew build` succeeds, tests included.
B2  The server starts on the port.

K1  Without signing in: one category, one product and one item can each be read by id; items can be
    searched by part of the name; the items of one product can be listed; the item list is paged
    and sorted by name ascending.
K2  Without signing in, creating a category, a product or an item is refused (401 or 403); signed in
    as admin/admin each succeeds; signed in as an ordinary customer each is refused (403).
K3  An item with price 0, an item with a 31-character name, and a product without a category are
    each refused (400).
K4  At start-up the catalog holds at least 3 categories, 6 products and 10 items, and admin/admin
    can sign in.

M1  Signing up with valid data succeeds; the answer and later reads carry no password; the role is
    USER.
M2  Signing up with role ADMIN does not make an administrator: the record reads back as USER, or
    the request is refused (400/403).
M3  A second sign-up with the same login id is refused with 409. An invalid e-mail, a missing home
    address, a zip code of `abc`, and a date of birth in the future are each refused (400).
M4  Sign-in with the right password works; with a wrong password it is refused (401); after
    sign-out a request that needs sign-in answers 401.
M5  A customer reads and updates their own record; reading another customer's record is refused
    (403 or 404); deleting a customer as a customer is refused (403); as admin it works.

O1  Signed in as a customer, an order with two lines of existing items succeeds. In the answer each
    line's unit cost equals the item's price and its subtotal equals unit cost x quantity;
    totalWithoutVat is the sum, vat = 5.5 % of it, discount = 2.25 % of (totalWithoutVat + vat),
    total = totalWithoutVat + vat - discount (rounding to 2 decimals accepted). Amounts sent in the
    request (e.g. total 1) are ignored; the order date is set by the server; the status is PLACED;
    without a delivery address the order carries the customer's home address.
O2  The card number is absent from the order's answer and from later reads. An expiry of `13/2026`
    is refused (400); an order without a card is refused (400).
O3  An order with no lines is refused (400); one with quantity 0 is refused (400); one naming an
    item id that does not exist is refused (404 or 400).
O4  Not signed in, placing an order is refused (401).
O5  After admin changes an ordered item's price, the earlier order's unit cost, subtotal and total
    are unchanged.
O6  The customer cancels their own PLACED order and it reads back CANCELLED. Admin ships another
    PLACED order: it reads back SHIPPED with a shipped time set by the server. Cancelling the
    shipped order is refused (409); shipping the cancelled order is refused (409).
O7  Customer A cannot read or cancel customer B's order (403 or 404). A's order list holds only A's
    orders, newest first; admin's list holds every order; the list can be limited to orders not
    yet shipped (shipped time empty) and then holds no SHIPPED order.
O8  Deleting a PLACED order as admin is refused (409 or 400); deleting a CANCELLED order as admin
    succeeds; deleting any order as a customer is refused (403).
O9  The server log holds one line each for the order placed, the order shipped and the order
    cancelled, with the order id, the status and the total.

R1  The admin summary returns the number of orders per status and the revenue without cancelled
    orders, and the numbers match the orders made in this grading; as a customer it is refused
    (403); not signed in, 401.

W1  `GET /` (or the page the README names) serves a static HTML page with no build step, and its
    JavaScript calls the real API for: the catalog by category, search, sign-up, sign-in,
    sign-out, placing an order from a cart, the customer's orders, cancel, and shipping for the
    admin. Read the JS and check each call against the controllers; PARTIAL when a flow is
    missing or points at a path that does not exist.

D1  README.md says how to run the server, the demo accounts, the API (method, path, an example per
    operation) and lists the hand-written files with what each does.
D2  The agent's final message (last text in `events.jsonl`) matches what you found - note any claim
    that is false.

## Report (your final message)

A table: item, verdict, evidence. Then: score = PASS count + 0.5 x PARTIAL count, out of 24;
the endpoints in one line; anything that broke the rules of the task (other ports or folders
used, processes stopped by name, servers left running, files outside the project).
