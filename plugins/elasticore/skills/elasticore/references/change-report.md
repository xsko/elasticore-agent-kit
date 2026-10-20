# Change report

Write it for someone who decides about the business, not the code. Start from the DSL diff
(`git diff -- src/main/resources/blueprint`), then the files you own that you changed. Leave out
what did not change. Use the user's language.

## Template

```markdown
## What changes for the business

**<Entity, in business words>**
- Stores: <fields added, removed, or changed in type, length or "required">
- Who may: <access before -> after; name who gains and who loses>
- Lifecycle: <states or moves added or removed>
- Calculated: <values the server now derives or keeps>
- API: <operations added or removed>

## Needs a decision

- <anything that widens access, removes data, removes an API, or changes a key>

## Checked

- Generator: <3.0 rule engine, architecture X | 2.x generator - rules it ignores are not in force>
- Generation: <N written / N unchanged / N skipped / N failed>, DSL validation warnings: <none, or the lines>
- Compile and tests: <command and result>
- Hand-written code: <files you own that changed, one line each>
```

## What goes under "Needs a decision"

| DSL change | Why it needs a decision |
|---|---|
| `@access(...)` wider (`owner` -> `user` -> `public`), `@owner` removed | More people see or change data |
| A field removed or renamed | Its column and its API field disappear; stored values may be lost |
| A type narrowed: shorter `string(n)`, smaller `money(p.s)` | Existing values may no longer fit |
| A state or a move removed from `states:` | Records in that state may get stuck |
| `@expose` removed or reduced | Clients that call the API break |
| An `@id` or `@genid` changed | Keys and every reference to them change |
| `@password`, `@login` changed | Sign-in changes for every user |
