# MyBatis instead of JPA

A domain whose `env.yml` says `mode: mybatis` is generated with MyBatis: the same model, the same
DTOs, controllers, access checks and services, and a MyBatis mapper (interface and XML) for each
entity instead of a JPA repository. Nothing else in the model changes.

- **Layered Java** from ElastiCORE 3.0.261030-rc5; **`architecture = 'hexagonal'` or `'ddd'`** from
  3.0.261030-rc6 - the aggregate, its invariants, lifecycle, events and ports as with JPA, written by
  a generated repository adapter. Before rc6 the build stops on hexagonal or ddd with MyBatis.
- **Java only.** A Kotlin build stops with the reason.
- What MyBatis cannot keep, the build refuses by name, never silently: collections without
  `mappedBy`, `@ManyToMany`, value collections, keys from a sequence other than identity, JPQL in
  `repository.yml`, `@audited`, and more. The list is in `elasticore-env-guide.md` section 2.3 (in the
  project's `blueprint/` once it has been generated) - read it before modelling, and change the model
  rather than working around a refusal in code.

## Starting a project on MyBatis

Take `new-project.md` as it is, with three changes.

**1. `build.gradle`:** instead of `spring-boot-starter-data-jpa`, MyBatis and Spring Data's paging
types (Spring Boot 3: `mybatis-spring-boot-starter:3.0.5`):

### Instead of `spring-boot-starter-data-jpa`

```gradle
    implementation 'org.mybatis.spring.boot:mybatis-spring-boot-starter:4.0.0'
    implementation 'org.springframework.data:spring-data-commons'
```

**2. `env.yml`:** `mode: mybatis` instead of `mode: jpa`.

**3. The tables:** MyBatis makes none. The generator writes them to `db/<domain>-schema.sql`, and
Spring runs that file on the embedded H2 at start-up when the application says where it is:

### `src/main/resources/application.properties`

```properties
spring.sql.init.schema-locations=classpath:db/shop-schema.sql
```

Rename `shop` there with the domain. With more than one domain, list each file, comma-separated.

With the project's DDL (`elasticore { ddl { databases = [...] } }`, `elasticore-env-guide.md` section
9-1) a domain gets no `db/<domain>-schema.sql` of its own any more: the tables are in
`db/schema-<database>.sql` for each database listed. Then point `schema-locations` at
`classpath:db/schema-h2.sql` - with `'h2'` among the `databases` - for the embedded H2. For
PostgreSQL, Oracle or SQL Server, use that database's file with `spring.sql.init.mode=always` (Spring
runs the scripts by itself only on an embedded database), or Flyway with `migration = 'flyway'`.

## What is different from JPA

- **No `EntityManager`, no JPQL.** A query of your own is a MyBatis mapper of your own: an
  interface with `@Mapper` in the application's package (MyBatis finds it there), with its SQL in an
  annotation (`@Select`) or in an XML file under `src/main/resources` at the interface's package path
  (`com/acme/shop/OrderQueryMapper.xml` - Gradle copies no `.xml` from `src/main/java`, and MyBatis
  answers `Invalid bound statement (not found)` without it) - then injected where it is used. For SQL
  the model should own, a `dbms` port is the generated way (`recipe-shop.md`, "On MyBatis").
- The generated mappers' tables and columns are the model's names in snake case
  (`PurchaseOrder.orderedAt` -> table `purchase_order`, column `ordered_at`); a relation is
  `<field>_<the target's key column>` (`customer` to a key `customer_id` -> `customer_customer_id`);
  an enum with `@db(code)` is stored as its code (`OrderStatus.fromCode(...)` reads it back).
- The generated mapper XML may be edited (a hint, a condition): the edit is kept when the model
  changes, as with any generated file. A new statement goes in a mapper of your own, not in the
  generated one.
- On hexagonal or ddd, the generated `<Root>RepositoryAdapter` does what JPA did by itself: new row
  or update, the version check (409 when stale), the aggregate's members compared with the stored
  rows, the lifecycle callbacks and the domain events after the save. Use the ports as with JPA.

`recipe-shop.md` ends with the shop on MyBatis: its report as a `dbms` port. The agent kit's
contract test builds, starts and calls that shop on MyBatis with every request of its API table, as
it does on JPA.
