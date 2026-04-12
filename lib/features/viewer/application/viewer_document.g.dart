// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'viewer_document.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Application-layer entry point for loading a markdown document.
///
/// This provider is what presentation code (ViewerScreen) depends on.
/// It watches the abstract [documentRepositoryProvider] declared in
/// the application layer — never the concrete data-layer class — and
/// delegates the actual I/O to whatever concrete repository has been
/// wired at the composition root.
///
/// Parametrized by [DocumentId] so every distinct path gets its own
/// provider instance — `ref.invalidate(viewerDocumentProvider(id))`
/// forces a reload for one document without touching any others.

@ProviderFor(viewerDocument)
final viewerDocumentProvider = ViewerDocumentFamily._();

/// Application-layer entry point for loading a markdown document.
///
/// This provider is what presentation code (ViewerScreen) depends on.
/// It watches the abstract [documentRepositoryProvider] declared in
/// the application layer — never the concrete data-layer class — and
/// delegates the actual I/O to whatever concrete repository has been
/// wired at the composition root.
///
/// Parametrized by [DocumentId] so every distinct path gets its own
/// provider instance — `ref.invalidate(viewerDocumentProvider(id))`
/// forces a reload for one document without touching any others.

final class ViewerDocumentProvider
    extends
        $FunctionalProvider<AsyncValue<Document>, Document, FutureOr<Document>>
    with $FutureModifier<Document>, $FutureProvider<Document> {
  /// Application-layer entry point for loading a markdown document.
  ///
  /// This provider is what presentation code (ViewerScreen) depends on.
  /// It watches the abstract [documentRepositoryProvider] declared in
  /// the application layer — never the concrete data-layer class — and
  /// delegates the actual I/O to whatever concrete repository has been
  /// wired at the composition root.
  ///
  /// Parametrized by [DocumentId] so every distinct path gets its own
  /// provider instance — `ref.invalidate(viewerDocumentProvider(id))`
  /// forces a reload for one document without touching any others.
  ViewerDocumentProvider._({
    required ViewerDocumentFamily super.from,
    required DocumentId super.argument,
  }) : super(
         retry: null,
         name: r'viewerDocumentProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$viewerDocumentHash();

  @override
  String toString() {
    return r'viewerDocumentProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Document> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Document> create(Ref ref) {
    final argument = this.argument as DocumentId;
    return viewerDocument(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ViewerDocumentProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$viewerDocumentHash() => r'6a337cbf3b1540a6d773d72590d73a652d21c040';

/// Application-layer entry point for loading a markdown document.
///
/// This provider is what presentation code (ViewerScreen) depends on.
/// It watches the abstract [documentRepositoryProvider] declared in
/// the application layer — never the concrete data-layer class — and
/// delegates the actual I/O to whatever concrete repository has been
/// wired at the composition root.
///
/// Parametrized by [DocumentId] so every distinct path gets its own
/// provider instance — `ref.invalidate(viewerDocumentProvider(id))`
/// forces a reload for one document without touching any others.

final class ViewerDocumentFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Document>, DocumentId> {
  ViewerDocumentFamily._()
    : super(
        retry: null,
        name: r'viewerDocumentProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Application-layer entry point for loading a markdown document.
  ///
  /// This provider is what presentation code (ViewerScreen) depends on.
  /// It watches the abstract [documentRepositoryProvider] declared in
  /// the application layer — never the concrete data-layer class — and
  /// delegates the actual I/O to whatever concrete repository has been
  /// wired at the composition root.
  ///
  /// Parametrized by [DocumentId] so every distinct path gets its own
  /// provider instance — `ref.invalidate(viewerDocumentProvider(id))`
  /// forces a reload for one document without touching any others.

  ViewerDocumentProvider call(DocumentId id) =>
      ViewerDocumentProvider._(argument: id, from: this);

  @override
  String toString() => r'viewerDocumentProvider';
}
