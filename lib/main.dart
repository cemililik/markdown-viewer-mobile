import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown_viewer/app/app.dart';
import 'package:markdown_viewer/features/viewer/application/document_repository_provider.dart';
import 'package:markdown_viewer/features/viewer/application/mermaid_renderer_provider.dart';
import 'package:markdown_viewer/features/viewer/data/parsers/markdown_parser.dart';
import 'package:markdown_viewer/features/viewer/data/repositories/document_repository_impl.dart';
import 'package:markdown_viewer/features/viewer/data/services/mermaid/mermaid_renderer_impl.dart';
import 'package:markdown_viewer/features/viewer/domain/services/mermaid_renderer.dart';

Future<void> main() async {
  // Required so we can load asset bundles and run the mermaid
  // pre-warm before the first frame.
  WidgetsFlutterBinding.ensureInitialized();

  final mermaidRenderer = await _buildMermaidRenderer();

  runApp(
    ProviderScope(
      // Composition root — this is the only place in the app that is
      // allowed to reach into `features/**/data/` and hand a concrete
      // implementation to an application-layer port. Every other file
      // depends on the abstract [documentRepositoryProvider] /
      // [mermaidRendererProvider] declared in the application layer,
      // so data implementations can be swapped (tests, fakes,
      // integration harnesses) without touching application or
      // presentation code.
      overrides: [
        documentRepositoryProvider.overrideWithValue(
          const DocumentRepositoryImpl(parser: MarkdownParser()),
        ),
        mermaidRendererProvider.overrideWith((ref) {
          ref.onDispose(mermaidRenderer.dispose);
          return mermaidRenderer;
        }),
      ],
      child: const MarkdownViewerApp(),
    ),
  );
}

/// Loads the bundled mermaid runtime, constructs a production
/// [MermaidRendererImpl], and pre-warms its sandboxed WebView.
///
/// The asset load and pre-warm are both wrapped in a try/catch: if
/// either fails (asset missing because `tool/fetch_mermaid.sh` was
/// not run, WebView platform binding unavailable, etc.) we still
/// return a usable renderer instance — its internal "permanent
/// failure" flag will route every subsequent render to a typed
/// [MermaidRenderFailure] so the rest of the document continues to
/// load. A diagram-less reading experience is strictly better than
/// a crashed app.
Future<MermaidRenderer> _buildMermaidRenderer() async {
  try {
    final mermaidJs = await rootBundle.loadString(
      'assets/mermaid/mermaid.min.js',
    );
    final renderer = MermaidRendererImpl.production(mermaidJs: mermaidJs);
    await renderer.prewarm();
    return renderer;
  } catch (_) {
    return MermaidRendererImpl.production(mermaidJs: '');
  }
}
