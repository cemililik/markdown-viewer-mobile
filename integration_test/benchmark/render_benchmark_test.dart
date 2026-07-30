import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:markdown_viewer/features/library/data/services/library_content_search_impl.dart';
import 'package:markdown_viewer/features/library/domain/entities/recent_document.dart';
import 'package:markdown_viewer/features/library/domain/services/library_content_search.dart';
import 'package:markdown_viewer/features/settings/domain/reading_settings.dart';
import 'package:markdown_viewer/features/viewer/data/parsers/markdown_parser.dart';
import 'package:markdown_viewer/features/viewer/data/repositories/document_repository_impl.dart';
import 'package:markdown_viewer/features/viewer/data/services/mermaid/mermaid_renderer_impl.dart';
import 'package:markdown_viewer/features/viewer/domain/entities/document.dart';
import 'package:markdown_viewer/features/viewer/domain/services/mermaid_renderer.dart';
import 'package:markdown_viewer/features/viewer/presentation/services/syntax_highlight_service.dart';
import 'package:markdown_viewer/features/viewer/presentation/widgets/markdown_view.dart';
import 'package:markdown_viewer/l10n/generated/app_localizations.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../tool/performance/benchmark_schema.dart';

const _measuredRepetitions = 5;
const _oneMiB = 1024 * 1024;
const _scrollLineCount = 10000;
const _codeLineCount = 1000;
const _searchDocumentCount = 500;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const parser = MarkdownParser();
  const repository = DocumentRepositoryImpl(parser: parser);
  const contentSearch = LibraryContentSearchImpl();
  final metrics = <String, Map<String, Object>>{};
  final timelineSummaries = <String, Map<String, Object?>>{};

  late Directory fixtureRoot;
  late Uint8List largeMarkdownBytes;
  late Uint8List scrollMarkdownBytes;
  late String codeSource;
  late File largeMarkdownFile;
  late List<RecentDocument> searchDocuments;
  late String mermaidJavaScript;

  setUpAll(() async {
    fixtureRoot = await Directory.systemTemp.createTemp(
      'markdown-viewer-benchmark-',
    );
    largeMarkdownBytes = _largeMarkdownBytes();
    scrollMarkdownBytes = _scrollMarkdownBytes();
    codeSource = _codeSource();
    largeMarkdownFile = File('${fixtureRoot.path}/large.md');
    await largeMarkdownFile.writeAsBytes(largeMarkdownBytes, flush: true);
    searchDocuments = await _createSearchCorpus(fixtureRoot);
    mermaidJavaScript = await rootBundle.loadString(
      'assets/mermaid/mermaid.min.js',
    );
  });

  tearDownAll(() async {
    binding.reportData = <String, Object>{
      'schemaVersion': benchmarkSchemaVersion,
      'suite': 'android-fixed-profile-v1',
      'measurement': <String, Object>{
        'warmUpCount': 1,
        'sampleCount': _measuredRepetitions,
      },
      'fixtures': <String, Object>{
        'documentBytes': largeMarkdownBytes.length,
        'scrollLines': _scrollLineCount,
        'codeLines': _codeLineCount,
        'searchDocuments': _searchDocumentCount,
        'searchCorpusBytes': await _corpusByteCount(searchDocuments),
        'locale': 'en-US',
        'viewportLogicalWidth': 390,
        'viewportLogicalHeight': 844,
        'devicePixelRatio': 3,
      },
      'metrics': metrics,
      'timelineSummaries': timelineSummaries,
    };
    if (await fixtureRoot.exists()) {
      await fixtureRoot.delete(recursive: true);
    }
  });

  setUp(() {
    final previousInterval =
        VisibilityDetectorController.instance.updateInterval;
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    addTearDown(() {
      VisibilityDetectorController.instance.updateInterval = previousInterval;
    });
  });

  testWidgets(
    'should measure document open through first render when the fixed fixture is exercised',
    (tester) async {
      final samples = await _measureLatency<
        ({ScrollController controller, Document document})
      >(
        (_) async {
          final document = await repository.load(
            DocumentId(largeMarkdownFile.path),
          );
          final controller = ScrollController();
          await tester.pumpWidget(_benchmarkApp(document, controller));
          await tester.pump();
          return (controller: controller, document: document);
        },
        afterEach: (result) async {
          expect(result.document.byteSize, largeMarkdownBytes.length);
          await tester.pumpWidget(const SizedBox.shrink());
          result.controller.dispose();
        },
      );

      metrics['document_open_first_render_ms'] = _latencyMetric(samples);
    },
  );

  test(
    'should measure UTF-8 decode and parse when the one MiB fixture is exercised',
    () async {
      final samples = await _measureLatency<Document>(
        (iteration) async => parser.parse(
          id: DocumentId('benchmark/parse/$iteration'),
          bytes: largeMarkdownBytes,
        ),
        afterEach:
            (document) async =>
                expect(document.byteSize, largeMarkdownBytes.length),
      );

      metrics['decode_parse_ms'] = _latencyMetric(samples);
    },
  );

  testWidgets(
    'should measure the document widget tree build when the one MiB fixture is exercised',
    (tester) async {
      final documents = List.generate(
        _measuredRepetitions + 1,
        (index) => parser.parse(
          id: DocumentId('benchmark/widget/$index'),
          bytes: largeMarkdownBytes,
        ),
      );
      final samples = await _measureLatency<ScrollController>(
        (iteration) async {
          final controller = ScrollController();
          await tester.pumpWidget(
            _benchmarkApp(documents[iteration + 1], controller),
          );
          await tester.pump();
          return controller;
        },
        afterEach: (controller) async {
          await tester.pumpWidget(const SizedBox.shrink());
          controller.dispose();
        },
      );

      metrics['widget_build_ms'] = _latencyMetric(samples);
    },
  );

  testWidgets(
    'should measure scrolling frame time when the ten-thousand-line fixture is exercised',
    (tester) async {
      final document = parser.parse(
        id: const DocumentId('benchmark/scroll'),
        bytes: scrollMarkdownBytes,
      );

      final warmUpController = await _prepareScroll(tester, document);
      await _runScrollGesture(tester);
      await _tearDownScroll(tester, warmUpController);
      final samples = <double>[];
      for (var index = 0; index < _measuredRepetitions; index += 1) {
        final controller = await _prepareScroll(tester, document);
        final reportKey = 'scroll_run_$index';
        await binding.watchPerformance(
          () => _runScrollGesture(tester),
          reportKey: reportKey,
        );
        final summary = Map<String, Object?>.from(
          binding.reportData!.remove(reportKey)! as Map,
        );
        timelineSummaries[reportKey] = summary;
        samples.add(_frameTimeP95(summary));
        await _tearDownScroll(tester, controller);
      }

      metrics['scroll_frame_time_ms'] = _frameMetric(samples);
    },
  );

  test(
    'should measure syntax highlighting when the thousand-line code fixture is exercised',
    () async {
      final highlighters = List.generate(
        _measuredRepetitions + 1,
        (_) => SyntaxHighlightService(),
      );
      final samples = await _measureLatency<List<SyntaxHighlightToken>>(
        (iteration) async => highlighters[iteration + 1].highlightSynchronously(
          codeSource,
          'dart',
        ),
        afterEach: (tokens) async {
          expect(tokens, isNotEmpty);
          expect(
            tokens.fold<int>(0, (length, token) => length + token.text.length),
            codeSource.length,
          );
        },
      );

      metrics['code_highlight_ms'] = _latencyMetric(samples);
    },
  );

  test(
    'should measure Mermaid prewarm and first render when a typical diagram is exercised',
    () async {
      final renderers = List.generate(
        _measuredRepetitions + 1,
        (_) => MermaidRendererImpl.production(mermaidJs: mermaidJavaScript),
      );
      final samples = await _measureLatency<
        ({MermaidRendererImpl renderer, MermaidRenderResult result})
      >(
        (iteration) async {
          final renderer = renderers[iteration + 1];
          await renderer.prewarm();
          final result = await renderer.render(
            'flowchart LR\n  Input --> Parse --> Render --> Read',
          );
          return (renderer: renderer, result: result);
        },
        afterEach: (measurement) async {
          expect(measurement.result, isA<MermaidRenderSuccess>());
          await measurement.renderer.dispose();
        },
      );

      metrics['mermaid_cold_render_ms'] = _latencyMetric(samples);
    },
  );

  test(
    'should measure representative library content search when five hundred files are exercised',
    () async {
      final samples = await _measureLatency<List<ContentSearchMatch>>(
        (_) => contentSearch.search(
          query: 'benchmark-target',
          recents: searchDocuments,
          folders: const [],
          syncedRepos: const [],
          recentsSourceLabel: 'Recent',
          folderSourceLabelBuilder: (_) => 'Folder',
          syncedRepoSourceLabelBuilder: (_) => 'Repository',
        ),
        afterEach: (matches) async {
          expect(matches, hasLength(50));
          expect(matches.first.matchCount, greaterThanOrEqualTo(1));
        },
      );

      metrics['library_search_ms'] = _latencyMetric(samples);
    },
  );
}

Widget _benchmarkApp(Document document, ScrollController controller) {
  return ProviderScope(
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844), devicePixelRatio: 3),
          child: MarkdownView(
            document: document,
            controller: controller,
            readingSettings: ReadingSettings.defaults,
          ),
        ),
      ),
    ),
  );
}

Future<List<double>> _measureLatency<T>(
  Future<T> Function(int iteration) operation, {
  Future<void> Function(T result)? afterEach,
}) async {
  final warmUpResult = await operation(-1);
  await afterEach?.call(warmUpResult);
  final samples = <double>[];
  for (var index = 0; index < _measuredRepetitions; index += 1) {
    final stopwatch = Stopwatch()..start();
    final result = await operation(index);
    stopwatch.stop();
    samples.add(stopwatch.elapsedMicroseconds / 1000);
    await afterEach?.call(result);
  }
  return List.unmodifiable(samples);
}

Map<String, Object> _latencyMetric(List<double> samples) {
  return <String, Object>{
    'unit': 'ms',
    'aggregation': 'median',
    'samples': samples,
    'value': _percentile(samples, 0.5),
  };
}

Map<String, Object> _frameMetric(List<double> samples) {
  return <String, Object>{
    'unit': 'ms',
    'aggregation': 'p95',
    'samples': samples,
    'value': _percentile(samples, 0.95),
  };
}

double _frameTimeP95(Map<String, Object?> summary) {
  final buildTimes =
      (summary['frame_build_times']! as List)
          .map((value) => (value as num).toDouble())
          .toList();
  final rasterTimes =
      (summary['frame_rasterizer_times']! as List)
          .map((value) => (value as num).toDouble())
          .toList();
  expect(buildTimes, isNotEmpty);
  expect(rasterTimes, hasLength(buildTimes.length));
  final totalFrameTimes = <double>[
    for (var index = 0; index < buildTimes.length; index += 1)
      math.max(buildTimes[index], rasterTimes[index]) / 1000,
  ];
  return _percentile(totalFrameTimes, 0.95);
}

double _percentile(List<double> values, double percentile) {
  final sorted = [...values]..sort();
  final index = ((sorted.length - 1) * percentile).ceil();
  return sorted[index];
}

Future<ScrollController> _prepareScroll(
  WidgetTester tester,
  Document document,
) async {
  final controller = ScrollController();
  await tester.pumpWidget(_benchmarkApp(document, controller));
  await tester.pump();
  expect(controller.position.maxScrollExtent, greaterThan(0));
  return controller;
}

Future<void> _runScrollGesture(WidgetTester tester) async {
  await tester.fling(
    find.byType(SingleChildScrollView),
    const Offset(0, -6000),
    10000,
  );
  await tester.pumpAndSettle();
}

Future<void> _tearDownScroll(
  WidgetTester tester,
  ScrollController controller,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  controller.dispose();
}

Uint8List _largeMarkdownBytes() {
  const paragraph =
      '## Benchmark section\n\n'
      'Measured mobile reading must preserve non-ASCII text such as '
      'İstanbul, naïve, and 🌍 while rendering links, **emphasis**, and '
      'inline `code` deterministically.\n\n'
      '- Stable fixture item A\n'
      '- Stable fixture item B\n'
      '- Stable fixture item C\n\n';
  return _repeatUtf8Fixture(paragraph, _oneMiB);
}

Uint8List _scrollMarkdownBytes() {
  final buffer = StringBuffer('# Scroll benchmark\n\n');
  for (var index = 0; index < _scrollLineCount; index += 1) {
    buffer.writeln(
      'Paragraph $index keeps the document moving through a deterministic '
      'reading surface.',
    );
    buffer.writeln();
  }
  return Uint8List.fromList(utf8.encode(buffer.toString()));
}

String _codeSource() {
  final buffer = StringBuffer();
  for (var index = 0; index < _codeLineCount; index += 1) {
    buffer.writeln(
      "final String field$index = 'değer_$index'; // deterministic line",
    );
  }
  return buffer.toString();
}

Uint8List _repeatUtf8Fixture(String chunk, int minimumBytes) {
  final buffer = StringBuffer();
  final chunkBytes = utf8.encode(chunk).length;
  var byteCount = 0;
  while (byteCount < minimumBytes) {
    buffer.write(chunk);
    byteCount += chunkBytes;
  }
  final bytes = utf8.encode(buffer.toString());
  return Uint8List.fromList(bytes);
}

Future<List<RecentDocument>> _createSearchCorpus(Directory root) async {
  final documents = <RecentDocument>[];
  for (var index = 0; index < _searchDocumentCount; index += 1) {
    final file = File(
      '${root.path}/search-${index.toString().padLeft(3, '0')}.md',
    );
    final marker = index.isEven ? 'benchmark-target' : 'control-text';
    await file.writeAsBytes(
      utf8.encode(
        '# Search fixture $index\n\n'
        'This synthetic document contains $marker and deterministic '
        'UTF-8 content for mobile library search: ölçüm 🌍.\n',
      ),
      flush: true,
    );
    documents.add(
      RecentDocument(
        documentId: DocumentId(file.path),
        openedAt: DateTime.utc(2026, 7, 30),
        displayName: 'search-$index.md',
      ),
    );
  }
  return List.unmodifiable(documents);
}

Future<int> _corpusByteCount(List<RecentDocument> documents) async {
  var total = 0;
  for (final document in documents) {
    total += await File(document.documentId.value).length();
  }
  return total;
}
