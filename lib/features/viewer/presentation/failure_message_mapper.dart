import 'package:markdown_viewer/core/errors/failure.dart';
import 'package:markdown_viewer/l10n/generated/app_localizations.dart';

/// Translates a [Failure] into a user-facing, localized message string.
///
/// Kept as a pure top-level function rather than a class so unit tests
/// can exercise every subtype without mocking. The switch is exhaustive
/// on the sealed [Failure] hierarchy — adding a new subclass breaks
/// this call site at compile time, which is the whole point.
///
/// Callers are expected to pass the [AppLocalizations] instance from
/// the build context (`context.l10n`), not construct one themselves.
String mapFailureToViewerMessage(Failure failure, AppLocalizations l10n) {
  return switch (failure) {
    FileNotFoundFailure() => l10n.errorFileNotFound,
    PermissionDeniedFailure() => l10n.errorPermissionDenied,
    ParseFailure() => l10n.errorParseFailed,
    RenderFailure() => l10n.errorRenderFailed,
    UnknownFailure() => l10n.errorUnknown,
  };
}
