# Testing Standards

## Test Pyramid

```
         /\        ← Integration (few, slow, critical paths)
        /  \
       /----\      ← Golden / widget (medium, visual + interaction)
      /------\
     /--------\    ← Unit (many, fast, pure logic)
    /----------\
```

## Coverage Requirements

| Layer | Minimum line coverage |
|-------|----------------------|
| Domain | 95% |
| Application | 90% |
| Data (parsers, mappers) | 85% |
| Presentation | 70% (widget + golden) |
| **Overall** | **80%** |

CI must fail on a coverage regression of more than 1%.

## Test Types

### Unit Tests — `test/unit/`

- Pure Dart, no Flutter bindings
- One class per test file
- Use `mocktail` for mocks; prefer hand-written `Fake` for repositories
- Arrange / act / assert structure with blank-line separators

```dart
test('should return ParseFailure when input is empty', () {
  // arrange
  final parser = MarkdownParser();

  // act
  final result = parser.parse('');

  // assert
  expect(result, isA<ParseFailure>());
});
```

### Widget Tests — `test/widget/`

- Use `testWidgets` with `ProviderScope` and overridden providers
- Prefer `find.bySemanticsLabel` or `find.byKey` over `find.byType`
- Never use `find.text` for strings that will be localized

### Golden Tests — `test/golden/`

- Use `alchemist` or `golden_toolkit`
- One golden per screen × theme × locale
- Goldens are regenerated only on explicit `--update-goldens`

### Integration Tests — `integration_test/`

- Exercise real file loading and rendering
- Run on both iOS simulator and Android emulator in CI
- Critical paths only: open file, render mermaid, search, export

## Test Naming

```
test('should <expected behavior> when <condition>', () { ... });
```

## Fakes Over Mocks

- Prefer hand-written `Fake` classes for repositories and data sources
- Use mocks only when you need call verification

## What to Test

Always test:

- Parsers (round-trip and failure modes)
- Notifiers and use cases (state transitions)
- Failure mapping
- Critical widgets (viewer, TOC, search)

Don't test:

- Generated code (`*.g.dart`, `*.freezed.dart`)
- Private implementation details
- Third-party packages

## Test Data

- Fixture files in `test/fixtures/`
- `.md` samples: minimal, typical, large (1MB), edge cases
- Mermaid samples covering all supported diagram types

## CI Enforcement

- `flutter test --coverage` must pass on every PR
- Coverage delta is tracked by CI
- Integration tests gate release builds (not every PR)
