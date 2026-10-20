# Starting a new ElastiCORE project

ElastiCORE is released to Maven Central: the Gradle plugin `io.elasticore`, the generator
`io.elasticore:elasticore-base`, and the runtime libraries `io.elasticore.springboot4:elasticore-springboot4`
(Spring Boot 4) and `io.elasticore.springboot3:elasticore-springboot3` (Spring Boot 3). A new project
uses a released version from there and nothing else.

- **Do not** build ElastiCORE from its source or run `publishToMavenLocal` for it - that is for
  working on ElastiCORE itself and gives the project a build no user has.
- **Do not** look through other projects or repositories on the machine for a template, and do not
  change them. A local `~/.m2` without ElastiCORE 3 only means it was never downloaded.
- **The version:** the last `3.` entry in the `<versions>` list of
  `https://repo1.maven.org/maven2/io/elasticore/elasticore-base/maven-metadata.xml` - the newest
  3.x release, the one the agent kit's CI checks. Use the same version in the three places marked
  `VERSION` below. If the machine cannot reach Maven Central, say so to the user instead of working
  around it.
- **Tools:** Java 17 or later. Spring Boot 4's Gradle plugin needs Gradle 8.14 or later. A project
  without a Gradle wrapper gets one first, in the empty folder, before `build.gradle` exists - an
  installed Gradle older than 8.14 cannot run a build that applies Spring Boot 4:
  `gradle wrapper --gradle-version 8.14.3`. Without an installed Gradle, ask the user.

The files below are the ElastiCORE README's quick start. The agent kit's CI builds this exact
project with the newest ElastiCORE release every week. Rename `shop` and `com.acme.shop` together:
the domain folder, `domainName`, `namespace.base` and the application's package.

## `settings.gradle`

```gradle
pluginManagement {
    repositories {
        mavenCentral()
        gradlePluginPortal()
    }
}
rootProject.name = 'shop'
```

## `build.gradle`

```gradle
plugins {
    id 'java'
    id 'org.springframework.boot' version '4.0.8'
    id 'io.spring.dependency-management' version '1.1.7'
    id 'io.elasticore' version 'VERSION'
}

repositories {
    mavenCentral()
}

elasticore {
    architecture = 'hexagonal'    // or 'ddd'; not 'layered' - see below
    language     = 'java'         // java | kotlin
}

dependencies {
    implementation 'io.elasticore:elasticore-base:VERSION'
    implementation 'io.elasticore.springboot4:elasticore-springboot4:VERSION'

    implementation 'org.springframework.boot:spring-boot-starter-webmvc'
    implementation 'org.springframework.boot:spring-boot-starter-data-jpa'
    implementation 'org.springframework.boot:spring-boot-starter-validation'
    implementation 'org.springdoc:springdoc-openapi-starter-webmvc-ui:3.0.3'
    compileOnly 'org.projectlombok:lombok'
    annotationProcessor 'org.projectlombok:lombok'
    runtimeOnly 'com.h2database:h2'
}
```

The `elasticore { }` block is what selects the 3.0 rule engine. Without it the build runs the 2.x
generator, which ignores `@access`, `@owner`, `@password`, `states:`, `@compute` and `@snapshot`
without a warning, and whose services do not compile on Spring Boot 4 with 3.0.261015-alpha1.
`architecture = 'layered'` in Java is the 2.x-compatible output on the rule engine: `@access` is not
enforced (the generator warns), and with 3.0.261015-alpha1 the `money` field below does not compile
there.

## `src/main/resources/blueprint/shop/env.yml`

```yaml
elasticore:
  enable: true
  config:
    domainName: shop
    framework: springboot
    mode: jpa
    j2ee: jakarta
    apiPath: "/api"
  namespace:
    base: com.acme.shop
```

## `src/main/resources/blueprint/shop/model/entity.yml`

```yaml
entity:
  Product:
    meta: entity @root @editable @expose(20) @access(read=public) @sort(name+) -- product
    fields:
      productId: long @id @sequence
      name:      string(100)! @search(like)
      price:     money(10.2)! @min(0.01, 'price must be positive')
```

## `src/main/java/com/acme/shop/ShopApplication.java`

```java
package com.acme.shop;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class ShopApplication {
    public static void main(String[] args) {
        SpringApplication.run(ShopApplication.class, args);
    }
}
```

## Run it and try it in a browser

1. `./gradlew bootRun` generates, compiles and starts the application on port 8080, with an
   in-memory H2 database that starts empty on every run.
2. Open `http://localhost:8080/swagger-ui.html`: every operation the model exposes can be called
   from there. For `Product` they are, under `/api/shop/product`: `POST` creates, `GET /{productId}`
   reads one, `POST /search` returns a page (`{}` as the body lists everything), `PUT` updates,
   `DELETE /{productId}` deletes. There is no `GET` for the list - use `/search`.
3. `@access` decides who may do what. An operation it does not list is for an administrator, so with
   `@access(read=public)` reading and searching work without signing in, and creating a product
   answers 401 `Sign in to create Product`. For sign-in, see the `@access` / `@owner` and `@login`
   sections of `elasticore-annotation-guide.md` in the blueprint folder once it has been generated.
   A rule relaxed only to make a demo work (`create=public`) must be named as such to the user.
4. Validation comes before the access check: even without signing in, a price of 0 gets 400
   `price: price must be positive`.

The runtime library for Spring Boot 4 keeps the Java package `io.elasticore.springboot3` on
purpose - it shares its sources with the Spring Boot 3 library. That is not a wrong dependency.
