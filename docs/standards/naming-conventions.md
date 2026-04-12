# Naming Conventions

## Files

- `snake_case.dart`
- Feature files: `<feature>_<role>.dart` — e.g. `viewer_notifier.dart`,
  `document_repository.dart`
- Test files mirror source path under `test/` with the `_test.dart` suffix
- Generated files: `*.g.dart`, `*.freezed.dart` — committed to the repo

## Directories

- `snake_case`
- Feature folders are singular nouns: `viewer/`, `library/`, `search/`

## Symbols

| Construct | Convention | Example |
|-----------|------------|---------|
| Class / enum / typedef | `UpperCamelCase` | `DocumentRepository` |
| Extension | `UpperCamelCase` with `X` suffix | `StringX` |
| Method / function / variable | `lowerCamelCase` | `parseDocument` |
| Constant | `lowerCamelCase` | `defaultFontSize` |
| Private | `_leadingUnderscore` | `_cache` |
| Type parameter | `T`, or descriptive `TItem` | `T`, `TItem` |
| Boolean | `is/has/can/should` prefix | `isLoading`, `hasError` |

## Riverpod Providers

- Suffix `Provider` — `viewerNotifierProvider`, `themeModeProvider`
- Generated providers follow `riverpod_generator` conventions
- Family providers: `<name>FamilyProvider`

## Failures

- Suffix `Failure` — `FileNotFoundFailure`, `ParseFailure`
- Sealed base class: `Failure`

## Tests

- Top-level `group('ClassName', ...)`
- `test('should <expected behavior> when <condition>', ...)`

## Assets

- `snake_case.{png,svg,json}`
- Mermaid: `assets/mermaid/mermaid.min.js`
- Fonts: `assets/fonts/<family>/<family>-<weight>.ttf`

## Localization Keys

- `lowerCamelCase` describing intent: `viewerEmptyStateTitle`
- Scoped by screen or feature: `settings.themeLightLabel`
- See [localization-standards.md](localization-standards.md)
