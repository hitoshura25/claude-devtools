# Kotlin + JUnit Stack Reference

Read this file when:
- The project's language is Kotlin or Java and build tool is Gradle
- Setting up tooling (SKILL.md Steps 2–3)
- Creating test fixtures (Step 3)
- Writing stubs for mutation testing (Step 3b)

---

## Build Tool Setup

```bash
./gradlew dependencies   # verify deps resolve
./gradlew test           # run tests
./gradlew ktlintCheck    # run lint
```

Minimal additions to `build.gradle.kts`:
```kotlin
plugins {
    kotlin("jvm") version "1.9.0"
    id("org.jlleitschuh.gradle.ktlint") version "11.6.1"
    id("info.solidsoft.pitest") version "1.15.0"
}

dependencies {
    testImplementation("org.junit.jupiter:junit-jupiter:5.10.0")
    testImplementation("io.mockk:mockk:1.13.8")
}

tasks.test {
    useJUnitPlatform()
}
```

---

## Lint Wrapper

Gradle tasks only process source files — they don't accept arbitrary filenames appended by aider. The lint command can be used directly without a wrapper:

```json
{
  "tooling": {
    "lint_cmd": "./gradlew ktlintFormat",
    "test_cmd": "./gradlew test",
    "language": "kotlin",
    "framework": "junit",
    "linter": "ktlint"
  }
}
```

Note: `ktlintFormat` (with auto-fix) rather than `ktlintCheck` so trivial formatting issues are corrected automatically rather than sent to the small model.

---

## Stub Design

```kotlin
class RecordFilter {
    fun filter(rows: List<Row>, watermark: Long): List<Row> {
        throw NotImplementedError()
    }

    fun count(rows: List<Row>): Int {
        throw NotImplementedError()
    }
}
```

**Companion object singletons:** If a class has a companion object that initializes resources at class-load time (e.g., reading config, opening connections), loading the class during test compilation/reflection will trigger it. Stub companion objects with no-op implementations.

---

## Mocking Framework Modules

For frameworks not on the classpath, use MockK to mock entire classes/objects:

```kotlin
// In test setup
mockkObject(SomeFramework)
every { SomeFramework.someMethod(any()) } returns mockResult
```

For dependency injection frameworks (Spring, Koin), use their test utilities or mock the injected interfaces directly rather than the framework itself.

**Verification:** Ensure test source sets compile cleanly with `./gradlew compileTestKotlin` before running tests.

---

## External Dependency Mock Fixtures

Use MockK for fluent API mocking:

```kotlin
// Shared test fixture
fun createMockS3Client(): Pair<S3Client, () -> ByteArray> {
    val mockClient = mockk<S3Client>()
    var capturedBody: ByteArray = byteArrayOf()

    every {
        mockClient.putObject(any<PutObjectRequest>(), any<RequestBody>())
    } answers {
        capturedBody = (secondArg<RequestBody>()).contentStreamProvider().newStream().readBytes()
        mockk()
    }

    return Pair(mockClient) { capturedBody }
}
```

Usage:
```kotlin
@Test
fun `uploads correct bytes`() {
    val (client, captureBody) = createMockS3Client()
    val writer = MyWriter(client)
    writer.write(data)
    assertThat(captureBody()).isEqualTo(expectedBytes)
}
```

---

## Mutation Testing — Pitest

```kotlin
// build.gradle.kts
plugins {
    id("info.solidsoft.pitest") version "1.15.0"
}

pitest {
    targetClasses.set(listOf("com.example.mymodule.*"))
    targetTests.set(listOf("com.example.mymodule.*Test"))
    mutationThreshold.set(80)
    outputFormats.set(setOf("HTML", "XML"))
}
```

**Run:**
```bash
./gradlew pitest
# Report at: build/reports/pitest/index.html
```

Target: ≥80% mutation score before embedding tests in task docs.
