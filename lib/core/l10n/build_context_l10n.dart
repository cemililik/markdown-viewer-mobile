import 'package:flutter/widgets.dart';

import '../../l10n/generated/app_localizations.dart';

extension BuildContextL10n on BuildContext {
  /// Localized strings for the current [BuildContext].
  ///
  /// Throws [StateError] if no [Localizations] ancestor with
  /// [AppLocalizations] support is in scope. Always wrap the app root in
  /// `MaterialApp` (or `WidgetsApp`) with [AppLocalizations.localizationsDelegates]
  /// and [AppLocalizations.supportedLocales] before calling.
  AppLocalizations get l10n {
    final l10n = AppLocalizations.of(this);
    if (l10n == null) {
      throw StateError(
        'AppLocalizations not found in widget tree. Did you forget to '
        'register AppLocalizations.localizationsDelegates on MaterialApp?',
      );
    }
    return l10n;
  }
}
