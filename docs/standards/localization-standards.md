# Localization Standards

## Supported Locales (v1)

- `en` — English (**source of truth**)
- `tr` — Turkish

Adding a locale is a self-service operation — see
[../how-to/add-a-language.md](../how-to/add-a-language.md) for the
step-by-step procedure. The infrastructure is designed so that adding a
new language never requires touching application code.

## Tooling and File Layout

- `flutter_localizations` + `intl` (`intl` version is pinned by the
  Flutter SDK — see [tech-stack.md](../tech-stack.md))
- Generation configured via [`l10n.yaml`](../../l10n.yaml) at the
  project root, with `synthetic-package: false` set explicitly so the
  generator writes into `output-dir` regardless of Flutter SDK defaults
- ARB source files: [`lib/l10n/app_<locale>.arb`](../../lib/l10n/)
- Generated classes: `lib/l10n/generated/app_localizations.dart` and the
  per-locale files — **committed** per
  [naming-conventions.md](naming-conventions.md), and verified by CI
  with a `git diff --exit-code` drift check after `flutter gen-l10n`
- Context extension: [`lib/core/l10n/build_context_l10n.dart`](../../lib/core/l10n/build_context_l10n.dart)
- Access strings via `context.l10n.<keyName>` from any widget

```dart
import 'package:markdown_viewer/core/l10n/build_context_l10n.dart';

Text(context.l10n.libraryEmptyTitle)
```

## Key Rules

- Keys are `lowerCamelCase`
- Keys describe **intent**, not the text — `viewerEmptyStateTitle`,
  not `openAFileToStart`
- Keys are scoped by feature using a flat prefix: `settingsThemeLight`,
  `viewerTocTitle`, `syncFilesFound`. ARB does not support nested keys,
  so the scoping is done in the name itself.
- No hardcoded user-facing strings anywhere in `lib/` — every string a
  user can see goes through an ARB key
- Number and date formatting via `intl` formatters, never `toString`
- New keys are added to `app_en.arb` first (with a `@key` description
  block), then mirrored into every other ARB file in the same PR

## Plurals

- Use ICU `plural` syntax
- Always define `zero`, `one`, and `other` at minimum
- Test with `0`, `1`, `2`, `11`, `22` for locale-specific plural categories

## Text Length

- Design for 1.3× text expansion (typical EN → DE/TR)
- Never hardcode widget widths around specific text
- Use `Flexible` and `Expanded` aggressively in rows

## RTL

- RTL is **not** in scope for v1, but code must not break in RTL:
  - Use `EdgeInsetsDirectional` and `AlignmentDirectional`
  - Test layouts under `textDirection: TextDirection.rtl`

## Translators

- ARB descriptions (`@key`) required for every key
- Context hints explain what the text refers to
- Placeholders include type and example

## Review

- Linguistic review is separate from code review
- CI verifies that every non-source locale has the same key set via
  `test/unit/l10n/locale_completeness_test.dart`
- Missing keys fall back to `en` at runtime and log a warning

## Adding a Language

The full procedure is in
[../how-to/add-a-language.md](../how-to/add-a-language.md). Summary:

1. Copy `lib/l10n/app_en.arb` to `lib/l10n/app_<locale>.arb`
2. Change `@@locale` and translate every value
3. Run `flutter gen-l10n`
4. (Optional) add the locale to `preferred-supported-locales` in `l10n.yaml`
   to surface it in the in-app language picker
5. Run the completeness test
6. Open a PR labeled `i18n`

No application code changes are required to add a language.
