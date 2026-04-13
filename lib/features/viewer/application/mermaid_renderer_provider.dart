import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown_viewer/features/viewer/domain/services/mermaid_renderer.dart';

/// Application-layer binding point for the [MermaidRenderer] port.
///
/// Mirrors `documentRepositoryProvider`: the application layer
/// declares an abstract slot, the composition root in
/// `lib/main.dart` overrides it with a concrete WebView-backed
/// implementation, and tests override it with a fake. The default
/// build throws so a missing override fails loudly instead of
/// silently rendering every diagram as an error.
final mermaidRendererProvider = Provider<MermaidRenderer>((ref) {
  throw UnimplementedError(
    'mermaidRendererProvider must be overridden in the composition '
    'root (lib/main.dart) or in tests with a concrete MermaidRenderer. '
    'No default implementation is registered — the application layer '
    'is forbidden from importing data-layer symbols directly.',
  );
});
