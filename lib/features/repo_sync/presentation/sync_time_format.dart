import 'package:markdown_viewer/l10n/generated/app_localizations.dart';

/// Relative-time formatter for "last synced N minutes/hours/days ago"
/// labels on sync UI surfaces. Shared between the drawer's synced-repo
/// tile and the sync-screen's recent-syncs list so the two strings
/// match and unit tests can exercise a single implementation.
///
/// [now] is injectable so tests can pin the reference point without
/// manipulating the system clock — production callers omit it and
/// fall through to `DateTime.now()`.
String formatLastSynced(DateTime at, AppLocalizations l10n, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(at);
  if (diff.inMinutes < 1) return l10n.syncLastSyncedJustNow;
  if (diff.inHours < 1) return l10n.syncLastSyncedMinutes(diff.inMinutes);
  if (diff.inDays < 1) return l10n.syncLastSyncedHours(diff.inHours);
  return l10n.syncLastSyncedDays(diff.inDays);
}
