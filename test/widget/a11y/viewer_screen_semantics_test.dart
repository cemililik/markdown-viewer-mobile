import 'dart:async';
import 'dart:ui' show SemanticsAction, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/features/library/application/recent_documents_provider.dart';
import 'package:markdown_viewer/features/library/domain/entities/recent_document.dart';
import 'package:markdown_viewer/features/library/domain/repositories/recent_documents_store.dart';
import 'package:markdown_viewer/features/settings/application/settings_providers.dart';
import 'package:markdown_viewer/features/settings/data/settings_store_impl.dart';
import 'package:markdown_viewer/features/viewer/application/document_repository_provider.dart';
import 'package:markdown_viewer/features/viewer/application/reading_position_store_provider.dart';
import 'package:markdown_viewer/features/viewer/domain/entities/document.dart';
import 'package:markdown_viewer/features/viewer/domain/entities/reading_position.dart';
import 'package:markdown_viewer/features/viewer/domain/repositories/document_repository.dart';
import 'package:markdown_viewer/features/viewer/domain/repositories/reading_position_store.dart';
import 'package:markdown_viewer/features/viewer/presentation/screens/viewer_screen.dart';
import 'package:markdown_viewer/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'semantics_audit.dart';

void main() {
  const id = DocumentId('/tmp/accessible.md');
  const document = Document(
    id: id,
    source: '# Accessible\n\nReadable body.',
    headings: [
      HeadingRef(
        level: 1,
        text: 'Accessible',
        anchor: 'accessible',
        blockIndex: 0,
      ),
    ],
    lineCount: 3,
    byteSize: 29,
    topLevelBlockCount: 2,
  );

  late AppLocalizations l10n;

  setUp(() {
    final original = VisibilityDetectorController.instance.updateInterval;
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    addTearDown(() {
      VisibilityDetectorController.instance.updateInterval = original;
    });
  });

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  Future<Widget> harness(DocumentRepository repository) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'settings.bookmarkHintSeen': true,
    });
    final preferences = await SharedPreferences.getInstance();
    return ProviderScope(
      overrides: [
        documentRepositoryProvider.overrideWithValue(repository),
        readingPositionStoreProvider.overrideWithValue(_PositionStore()),
        settingsStoreProvider.overrideWithValue(SettingsStoreImpl(preferences)),
        recentDocumentsStoreProvider.overrideWithValue(_RecentStore()),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: ViewerScreen(documentId: id),
      ),
    );
  }

  testWidgets(
    'should expose ViewerScreen header labelled actions and bookmark state when the widget is exercised',
    (tester) async {
      await withSemanticsAudit(tester, () async {
        await tester.pumpWidget(
          await harness(const _DocumentRepository(document)),
        );
        await tester.pumpAndSettle();

        final title =
            tester
                .getSemantics(find.bySemanticsLabel('accessible.md'))
                .getSemanticsData();
        expect(title.flagsCollection.isHeader, isTrue);
        final documentHeading =
            tester
                .getSemantics(find.bySemanticsLabel('Accessible'))
                .getSemanticsData();
        expect(documentHeading.flagsCollection.isHeader, isTrue);

        for (final label in [
          l10n.viewerShareTooltip,
          l10n.viewerSearchOpenTooltip,
          l10n.viewerTocOpenTooltip,
          l10n.viewerReadingPanelOpenTooltip,
        ]) {
          final data =
              tester
                  .getSemantics(find.bySemanticsLabel(label))
                  .getSemanticsData();
          expect(data.label, label);
          expect(
            data.hasAction(SemanticsAction.tap),
            isTrue,
            reason: 'Viewer action "$label" must expose a tap action.',
          );
          expect(data.flagsCollection.isButton, isTrue);
        }

        var bookmark =
            tester
                .getSemantics(
                  find.bySemanticsLabel(l10n.viewerBookmarkSaveTooltip),
                )
                .getSemanticsData();
        expect(bookmark.flagsCollection.isToggled, Tristate.isFalse);

        await tester.tap(find.bySemanticsLabel(l10n.viewerBookmarkSaveTooltip));
        await tester.pumpAndSettle();
        bookmark =
            tester
                .getSemantics(
                  find.bySemanticsLabel(l10n.viewerBookmarkSaveTooltip),
                )
                .getSemanticsData();
        expect(bookmark.flagsCollection.isToggled, Tristate.isTrue);

        expectEveryTapTargetLabeled(tester);
        expectTapTargetsAtLeast(tester);
      });
    },
  );

  testWidgets(
    'should expose ViewerScreen loading state as a live region when the widget is exercised',
    (tester) async {
      await withSemanticsAudit(tester, () async {
        final completer = Completer<Document>();
        await tester.pumpWidget(
          await harness(_PendingRepository(completer.future)),
        );
        await tester.pump();

        final loading =
            tester
                .getSemantics(find.bySemanticsLabel(l10n.viewerLoading))
                .getSemanticsData();
        expect(loading.label, l10n.viewerLoading);
        expect(loading.flagsCollection.isLiveRegion, isTrue);

        completer.complete(document);
        await tester.pumpAndSettle();
      });
    },
  );
}

final class _DocumentRepository implements DocumentRepository {
  const _DocumentRepository(this.document);

  final Document document;

  @override
  Future<Document> load(DocumentId path) async => document;
}

final class _PendingRepository implements DocumentRepository {
  const _PendingRepository(this.future);

  final Future<Document> future;

  @override
  Future<Document> load(DocumentId path) => future;
}

final class _PositionStore implements ReadingPositionStore {
  final Map<String, ReadingPosition> _positions = {};

  @override
  ReadingPosition? read(DocumentId documentId) => _positions[documentId.value];

  @override
  Future<void> write(ReadingPosition position) async {
    _positions[position.documentId.value] = position;
  }

  @override
  Future<void> clear(DocumentId documentId) async {
    _positions.remove(documentId.value);
  }
}

final class _RecentStore implements RecentDocumentsStore {
  List<RecentDocument> _documents = const <RecentDocument>[];

  @override
  List<RecentDocument> read() => List.unmodifiable(_documents);

  @override
  Future<void> write(List<RecentDocument> documents) async {
    _documents = List.of(documents);
  }
}
