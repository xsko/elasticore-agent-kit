# Building a project against an ElastiCORE that is not released yet

A project uses an ElastiCORE release from Maven Central (`new-project.md`). Only when the user asks
to try a build of ElastiCORE that is not released - a fix in a pull request, a branch - does the
project take it from the local Maven repository (`~/.m2`), and only on the machine it was published
on. Do not do this on your own to get past a problem: say what the release lacks instead.

## 1. Publish ElastiCORE under a `-local` version

In the ElastiCORE checkout the user names, set `elasticoreVersion` in its `gradle.properties` to the
release the build is based on plus `-local` - `3.0.261127-local` - and publish:

```bash
./gradlew publishToMavenLocal        # ./gradlew.bat on Windows
```

Set it in the file, not with `-P`: the Gradle plugin is an included build of its own that reads the
version from that file, so a `-PelasticoreVersion=...` would publish the libraries under one version
and the plugin under another. Do not commit the change. The `-local` suffix keeps the build apart from a release (`3.0.261127`)
and from a SNAPSHOT (`3.0.261128-SNAPSHOT`), and the settings below switch on it. Afterwards
`~/.m2/repository/io/elasticore/` holds `elasticore-base`, `elasticore-gradle-plugin`, the plugin's
marker `io.elasticore.gradle.plugin` and `springboot3/elasticore-springboot3` and
`springboot4/elasticore-springboot4`, each under that version.

## 2. The project: one property, `mavenLocal()` for ElastiCORE only

### `gradle.properties`

```properties
elasticoreVersion=3.0.261127-local
```

### `settings.gradle`

```gradle
pluginManagement {
    repositories {
        // A local build of ElastiCORE (publishToMavenLocal), and only ElastiCORE, from ~/.m2.
        if (settings.elasticoreVersion.endsWith('-local')) {
            mavenLocal { content { includeGroupByRegex 'io\\.elasticore.*' } }
        }
        mavenCentral()
        gradlePluginPortal()
    }
    plugins {
        id 'io.elasticore' version settings.elasticoreVersion
    }
}
rootProject.name = 'shop'
```

### `build.gradle` - what changes against `new-project.md`

```gradle
plugins {
    id 'java'
    id 'org.springframework.boot' version '4.0.8'
    id 'io.spring.dependency-management' version '1.1.7'
    id 'io.elasticore'                  // the version is settings.gradle's
}

repositories {
    if (elasticoreVersion.endsWith('-local')) {
        mavenLocal { content { includeGroupByRegex 'io\\.elasticore.*' } }
    }
    mavenCentral()
}

dependencies {
    implementation "io.elasticore:elasticore-base:${elasticoreVersion}"
    implementation "io.elasticore.springboot4:elasticore-springboot4:${elasticoreVersion}"
    // ... the rest as in new-project.md
}
```

- The plugin comes from `pluginManagement`, the generator the plugin runs and the runtime library
  from the project's `repositories`: `~/.m2` is needed in both.
- `content { includeGroupByRegex 'io\\.elasticore.*' }` lets Gradle look in `~/.m2` for ElastiCORE
  only (`io.elasticore`, `io.elasticore.springboot3`, `io.elasticore.springboot4`); every other
  library still comes from Maven Central, not from whatever else is in `~/.m2`.
- Going back to a release is one line: `elasticoreVersion=3.0.261127` in `gradle.properties` - and
  `mavenLocal()` is no longer in either list. (`-PelasticoreVersion=3.0.261127` on one command line
  does the same for that build.)
- Double quotes around `"io.elasticore:...:${elasticoreVersion}"`: Groovy fills a property in only
  there.

## 3. Build

```bash
./gradlew --refresh-dependencies compileJava
```

- `--refresh-dependencies` on the first build with the `-local` version: Gradle resolves every
  dependency again instead of reusing what it resolved before - a version it looked for before
  `~/.m2` was in the lists is otherwise remembered as missing. Gradle reads `~/.m2` in place;
  nothing of the `-local` build is copied into its own cache.
- A generated file whose content did not change is not written again (`UNCHANGED`), so a fix that
  changes no output shows nothing in the project. To see what the new build writes for one file,
  delete that file - one nobody edited - and build again.
- `./gradlew dependencies --configuration runtimeClasspath` shows
  `io.elasticore:elasticore-base:3.0.261127-local` when the project uses the local build.

Checked with Gradle 8.14.3 on Windows: a project with exactly these files (the shop of
`recipe-shop.md`) built against `3.0.261127-local` from `~/.m2` - the plugin, the generator and the
runtime library - and `dependencies` listed `3.0.261127-local`; with `-PelasticoreVersion=3.0.261127`
the same files resolved the release from Maven Central.

## 4. Say where it works

The build exists on this machine only. CI, other developers and a fresh checkout cannot resolve
`3.0.261127-local` - their build fails until the version is released and `gradle.properties` names
it. Write that in the project's README while the project uses it, and tell the user which
ElastiCORE change it waits for.
