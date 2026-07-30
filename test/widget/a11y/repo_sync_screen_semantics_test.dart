import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/core/errors/failure.dart';
import 'package:markdown_viewer/features/repo_sync/application/repo_sync_notifier.dart';
import 'package:markdown_viewer/features/repo_sync/application/repo_sync_providers.dart';
import 'package:markdown_viewer/features/repo_sync/data/services/pat_store.dart';
import 'package:markdown_viewer/features/repo_sync/domain/entities/synced_repo.dart';
import 'package:markdown_viewer/features/repo_sync/presentation/screens/repo_sync_screen.dart';
import 'package:markdown_viewer/l10n/generated/app_localizations.dart';

import 'semantics_audit.dart';

void main() {
  late AppLocalizations l10n;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  Widget harness({bool error = false}) {
    return ProviderScope(
      overrides: [
        patStoreProvider.overrideWithValue(
          const PatStore(FlutterSecureStorage()),
        ),
        syncedReposProvider.overrideWith((_) async => const <SyncedRepo>[]),
        if (error) repoSyncNotifierProvider.overrideWith(_ErrorNotifier.new),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RepoSyncScreen(initialUrl: 'https://github.com/example/docs'),
      ),
    );
  }

  testWidgets(
    'should expose RepoSyncScreen header fields and labelled controls',
    (tester) async {
      await withSemanticsAudit(tester, () async {
        await tester.pumpWidget(harness());
        await tester.pumpAndSettle();

        final title =
            tester
                .getSemantics(find.bySemanticsLabel(l10n.navRepoSync))
                .getSemanticsData();
        expect(title.flagsCollection.isHeader, isTrue);

        final urlField =
            tester
                .getSemantics(find.bySemanticsLabel(l10n.syncUrlHint))
                .getSemanticsData();
        expect(urlField.flagsCollection.isTextField, isTrue);

        for (final label in [l10n.syncPatToggle, l10n.syncStart]) {
          final data =
              tester
                  .getSemantics(find.bySemanticsLabel(label))
                  .getSemanticsData();
          expect(data.label, label);
          expect(data.flagsCollection.isButton, isTrue);
          expect(data.hasAction(SemanticsAction.tap), isTrue);
        }

        expectEveryTapTargetLabeled(tester);
        expectTapTargetsAtLeast(tester);
      });
    },
  );

  testWidgets('should expose RepoSyncScreen errors as live regions', (
    tester,
  ) async {
    await withSemanticsAudit(tester, () async {
      await tester.pumpWidget(harness(error: true));
      await tester.pumpAndSettle();

      final liveRegions =
          semanticsNodes(tester)
              .map((node) => node.getSemanticsData())
              .where((data) => data.flagsCollection.isLiveRegion)
              .toList();
      expect(liveRegions, hasLength(1));
      expect(liveRegions.single.label, contains(l10n.errorNetworkUnavailable));
    });
  });
}

final class _ErrorNotifier extends RepoSyncNotifier {
  @override
  RepoSyncState build() =>
      const SyncError(NetworkUnavailableFailure(message: 'offline'));
}
