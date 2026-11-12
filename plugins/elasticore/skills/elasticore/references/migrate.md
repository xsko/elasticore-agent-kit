# Moving from the 2.x code to the 3.0 code

A project 2.x generated - or one on the Gradle plugin that keeps `elasticore { output = 'v2' }` - can move to the
3.0 code (`output = 'v3'`). Nothing forces it: `output = 'v2'` keeps working. The project's own
`blueprint/elasticore-migration-guide.md` is the reference for its version; this page is the order of work.

## The steps

1. **Build as it is** and commit: the starting point compiles and its tests pass.
2. **Check** (from ElastiCORE 3.0.261113): `./gradlew elcoreMigrationCheck` runs the first 3.0 build with nothing
   written and writes `build/elasticore/migration-check.md`. Its sections, most urgent first:
   - generated files the build removes or no longer writes **that the user's code uses** - by name, or a
     repository through the domain helper's getter (`helper.getCode()`);
   - conflicts, files kept as the user's, files left as the 2.x code (edited, base not confirmed);
   - imports a merge takes out of a file the user wrote more into;
   - older stamps no longer written, and plain removals.
3. **Fix the DSL** for the first section, and check again until it is empty.
4. **Move**: `output = 'v3'`, `./gradlew compileJava`. The statuses are the check's.
5. **Fix what is left** with the table, **test**, and commit `.elasticore/cache` with the sources.

## Failures and their fixes

| What you see | Why | Fix |
|---|---|---|
| `cannot find symbol` on `helper.getXxx()` or `XxxRepository` | 3.0 writes a repository only for `@expose`, `@service` or `@repository`; 2.x wrote one for every keyed entity | `@repository` on the entity line (from 3.0.261113): the repository and the getter, no service, no API |
| `cannot find symbol` on a DTO or service class in a file you edited | the merge took out a 2.x wildcard (`import ...dto.*;`) | from 3.0.261113 the merge keeps it while the generated code imports from that package; otherwise add the import |
| `reference to X is ambiguous` | two kept wildcards both have an `X` | import `X` by name |
| `CONFLICT` and `<<<<<<< yours` in a file | your edit and the 3.0 code change the same lines | resolve as a git conflict - usually the 3.0 code plus what your edit was for |
| `KEPT(yours - ...)` | a file of yours the 3.0 code changes where you changed it too | carry over what the `[elcore3]` lines name |
| `SKIP(user-modified; ...)` | an edited file whose 2.x base could not be confirmed: it stays the 2.x code | move what you wrote into a file of your own or the DSL, delete it, build again |
| `no suitable method found for delete(Specification<...>)` | `output = 'v2'` on Spring Boot 4 before 3.0.261113 | upgrade ElastiCORE (the 2.x-compatible delete reads the rows and removes them there), or move to `output = 'v3'` |
| `new Order(id)` does not compile | the 3.0 entity has the default constructor only | `repository.getReferenceById(id)`, or the default constructor and setters |
| A 2.x `*ServiceTest` fails | it mocks the repository calls of the 2.x CoreService | fix it to the new calls or delete it |
| The guides turned English | after 3.0.261031-rc7 they are English by default | `elasticore { guides = 'ko' }`; from 3.0.261113 Korean guides already there stay Korean |

## What behaves differently (say it to the user in business terms)

- A save is validated first (Bean Validation), and a key that exists is `DuplicateKeyException` - use `update`.
- A delete by search removes the rows one by one: entity listeners and cascades run.
- `@search(like)` ignores case (`@search(%_%)` keeps it).
- `@writeonly` / `@nooutput` values are not copied to the DTO.
