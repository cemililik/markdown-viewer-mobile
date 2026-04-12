import 'package:flutter/widgets.dart';
import 'package:markdown_viewer/l10n/generated/app_localizations.dart';

extension BuildContextL10n on BuildContext {
  /// Localized strings for the current [BuildContext].
  ///
  /// Returns the generated [AppLocalizations] for the active locale. The
  /// generator is configured with `nullable-getter: false` in `l10n.yaml`,
  /// so this never returns null at runtime — Flutter throws earlier if
  /// the [Localizations] ancestor is missing.
  AppLocalizations get l10n => AppLocalizations.of(this);
}
