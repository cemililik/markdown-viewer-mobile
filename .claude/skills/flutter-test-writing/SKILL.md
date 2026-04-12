---
name: flutter-test-writing
description: Write unit, widget, or golden tests for Flutter code in this project, following docs/standards/testing-standards.md. Use when the user asks you to add tests, increase coverage, or test-drive a new feature.
---

# Flutter Test Writing Skill

Produce tests for Flutter code that conform to the project's testing
standards.

## Before You Write

1. Read `docs/standards/testing-standards.md`
2. Read `docs/standards/naming-conventions.md` (test naming section)
3. Read the code you are testing — understand its contract, not its
   implementation

## Process

1. Identify the right tier:
   - **Unit** — pure logic, no Flutter bindings
   - **Widget** — UI composition and interaction
   - **Golden** — pixel-level regressions
   - **Integration** — critical end-to-end paths only
2. Place the test in the correct directory:
   - `test/unit/`, `test/widget/`, `test/golden/`, `integration_test/`
3. Mirror the source path in the test path
4. Use the naming convention:
   `test('should <behavior> when <condition>')`
5. Structure each test as arrange / act / assert with blank-line separators
6. Use `Fake` implementations for repositories; `mocktail` only when you
   need call verification
7. Cover happy path **and** failure modes — at least one of each for
   anything non-trivial

## Riverpod Tests

- Always wrap widget tests in `ProviderScope` with `overrides:`
- Override async providers with `AsyncValue.data(...)`, `.loading()`,
  `.error(...)` to exercise each state

## Golden Tests

- Use the existing golden harness (check `test/golden/`)
- One golden per screen × theme × locale
- Do not regenerate goldens unless the user explicitly asks

## Output Format

- Produce a complete, compilable test file
- Include only the imports that are used
- No explanatory comments inside the test body

## Forbidden

- Tests against generated code (`*.g.dart`, `*.freezed.dart`)
- Tests that assert private implementation details
- `find.text` for strings that will be localized
- Ignored futures inside `testWidgets`
