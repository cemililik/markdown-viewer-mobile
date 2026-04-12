import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown_viewer/app/app.dart';
import 'package:markdown_viewer/features/viewer/application/document_repository_provider.dart';
import 'package:markdown_viewer/features/viewer/data/parsers/markdown_parser.dart';
import 'package:markdown_viewer/features/viewer/data/repositories/document_repository_impl.dart';

void main() {
  runApp(
    ProviderScope(
      // Composition root — this is the only place in the app that is
      // allowed to reach into `features/**/data/` and hand a concrete
      // implementation to an application-layer port. Every other file
      // depends on the abstract [documentRepositoryProvider] declared
      // in the application layer, so the data implementation can be
      // swapped (tests, fakes, integration harnesses) without touching
      // application or presentation code.
      overrides: [
        documentRepositoryProvider.overrideWithValue(
          const DocumentRepositoryImpl(parser: MarkdownParser()),
        ),
      ],
      child: const MarkdownViewerApp(),
    ),
  );
}
