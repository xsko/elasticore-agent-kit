# The generated contract tests on the project's real database

With `testCode: "contract"` in `env.yml` ElastiCORE writes a `<Domain>ContractSupport` and a
`<Entity>ContractTest` for each entity the API creates (`elasticore-env-guide.md` 6.2.1). The
support class names an in-memory H2 in its `@SpringBootTest(properties = ...)` - "Change them here
to test on another database". Do not: the support class is written once per domain and is the
developer's from then on, so the change is made again for every domain, and a new domain is back on
H2. On MyBatis the database matters most - the SQL, the paging and the DDL differ per database, and
a project that runs PostgreSQL should test its SQL on PostgreSQL.

Instead, one class of the project's tests puts the real database in front of every test context,
present and future, without touching a generated or owned file: a Spring `ContextCustomizerFactory`
that adds the `spring.datasource.*` properties **first** among the property sources - before the
support class's inlined H2 ones - and a database server started from the test classpath.

## `build.gradle`

```gradle
dependencies {
    // ... as before, and the database's driver: runtimeOnly 'org.postgresql:postgresql'
    testImplementation 'io.zonky.test:embedded-postgres:2.2.3'
    testImplementation enforcedPlatform('io.zonky.test.postgres:embedded-postgres-binaries-bom:18.7.0')
}
```

`io.zonky.test:embedded-postgres` starts a real PostgreSQL from binaries in a jar - no Docker, no
installed database; the BOM picks the PostgreSQL version (18.7 here). It brings the binaries for
Windows, Linux and Intel macOS; on an ARM Mac add
`testImplementation 'io.zonky.test.postgres:embedded-postgres-binaries-darwin-arm64v8'`.

## `src/test/java/<base package>/testdb/EmbeddedPostgresContextCustomizerFactory.java`

```java
package com.acme.store.testdb;

import io.zonky.test.db.postgres.embedded.EmbeddedPostgres;
import java.io.IOException;
import java.io.UncheckedIOException;
import java.sql.Connection;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;
import org.springframework.context.ConfigurableApplicationContext;
import org.springframework.core.env.MapPropertySource;
import org.springframework.test.context.ContextConfigurationAttributes;
import org.springframework.test.context.ContextCustomizer;
import org.springframework.test.context.ContextCustomizerFactory;
import org.springframework.test.context.MergedContextConfiguration;

/**
 * Every Spring test context of the project on PostgreSQL: an embedded server started once from
 * the test classpath, and a database of its own for each context, put first among the property
 * sources - before the H2 that each generated ContractSupport names in its @SpringBootTest.
 * Registered in src/test/resources/META-INF/spring.factories.
 */
public class EmbeddedPostgresContextCustomizerFactory implements ContextCustomizerFactory {

    @Override
    public ContextCustomizer createContextCustomizer(
            Class<?> testClass, List<ContextConfigurationAttributes> configAttributes) {
        return new Customizer();
    }

    private static final class Customizer implements ContextCustomizer {

        private static final AtomicInteger DATABASES = new AtomicInteger();

        @Override
        public void customizeContext(ConfigurableApplicationContext context, MergedContextConfiguration merged) {
            String database = "contract_" + DATABASES.incrementAndGet();
            EmbeddedPostgres server = Server.get();
            try (Connection c = server.getPostgresDatabase().getConnection();
                    Statement s = c.createStatement()) {
                s.execute("CREATE DATABASE " + database);
            } catch (SQLException e) {
                throw new IllegalStateException("Could not create the test database " + database, e);
            }
            Map<String, Object> properties = new HashMap<>();
            properties.put("spring.datasource.url", server.getJdbcUrl("postgres", database));
            properties.put("spring.datasource.driver-class-name", "org.postgresql.Driver");
            properties.put("spring.datasource.username", "postgres");
            properties.put("spring.datasource.password", "postgres");
            context.getEnvironment().getPropertySources().addFirst(new MapPropertySource("embeddedPostgres", properties));
        }

        // One customizer equals another: the context cache keeps one context for every test class
        // that shares the rest of its configuration, as it does without this factory.
        @Override
        public boolean equals(Object other) {
            return other != null && other.getClass() == getClass();
        }

        @Override
        public int hashCode() {
            return getClass().hashCode();
        }
    }

    /** The embedded server, started on first use and stopped when the test JVM ends. */
    private static final class Server {
        private static EmbeddedPostgres server;

        static synchronized EmbeddedPostgres get() {
            if (server == null) {
                try {
                    server = EmbeddedPostgres.builder().start();
                } catch (IOException e) {
                    throw new UncheckedIOException("Could not start the embedded PostgreSQL", e);
                }
                EmbeddedPostgres started = server;
                Runtime.getRuntime().addShutdownHook(new Thread(() -> {
                    try {
                        started.close();
                    } catch (IOException ignored) {
                        // the JVM is ending
                    }
                }));
            }
            return server;
        }
    }
}
```

## `src/test/resources/META-INF/spring.factories`

```properties
org.springframework.test.context.ContextCustomizerFactory=com.acme.store.testdb.EmbeddedPostgresContextCustomizerFactory
```

Spring's test framework reads the factories listed there for every test context; nothing is added
to a test class.

## What each part is for

- **`addFirst`.** The support class's `properties` are inlined test properties, which win over
  `application.properties` and the environment. A property source added first, before the context
  starts, wins over them - so the H2 URL in every support class, present and future, is never used.
- **One database per context.** Each Spring context the run starts gets `CREATE DATABASE
  contract_<n>` of its own on the one server: two contexts never see each other's rows or schema
  history. The generated tests roll their rows back (`@Transactional` on the support class).
- **`equals` and `hashCode`.** Spring keeps a started context for the next test class only when its
  configuration, customizers included, is equal. A customizer without them is equal to no other, and
  every test class would start the application anew (and get a database of its own).
- **The schema.** On MyBatis the support class leaves the schema to the application - Flyway, or
  `spring.sql.init`. With the project DDL's migrations (`elasticore { ddl { migration = 'flyway' } }`,
  `elasticore-env-guide.md` 9-1) set the folder per database in `application.properties`:

  ```properties
  spring.flyway.locations=classpath:db/migration/{vendor}
  ```

  Flyway then runs `db/migration/postgresql/` on PostgreSQL and `db/migration/h2/` on H2; under the
  default `classpath:db/migration` it would read every database's folder. Add
  `org.flywaydb:flyway-database-postgresql` beside `spring-boot-starter-flyway`. On JPA the support
  class has Hibernate make the tables (`ddl-auto=create-drop`, Flyway off), on PostgreSQL as on H2.
- **Another database.** The same factory with another server: the URL, driver and account of a
  database the tests may use, and a database (or schema) of its own per context.

## Checked

The shop of `recipe-shop.md` on MyBatis, hexagonal, with `testCode: "contract"`, the project DDL for
`h2` and `postgresql` with Flyway migrations, ElastiCORE 3.0.261127 (a local build of it), Spring
Boot 4.0.8, on Windows: the 67 generated contract tests passed on H2 as generated, and with the two
files above on the embedded PostgreSQL 18.7 - one Spring context, one database (`contract_1`),
Flyway applying `db/migration/postgresql/V..._init.sql`. Not checked by the kit: the shop on JPA,
an application that makes its schema with `spring.sql.init` instead of Flyway, an ARM Mac, and the
local run of the application on the same embedded server (`bootTestRun`, or a test main of
`SpringApplication.from(...).with(...)`) - the team that reported this setup uses one.
