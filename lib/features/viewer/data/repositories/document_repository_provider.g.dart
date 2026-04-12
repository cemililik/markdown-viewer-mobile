// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'document_repository_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Exposes the singleton [DocumentRepository] to the rest of the app.
///
/// The concrete impl and the parser are wired here so every other layer
/// only sees the [DocumentRepository] port — the data layer is the only
/// place that knows about `dart:io` or the underlying `markdown` package.

@ProviderFor(documentRepository)
final documentRepositoryProvider = DocumentRepositoryProvider._();

/// Exposes the singleton [DocumentRepository] to the rest of the app.
///
/// The concrete impl and the parser are wired here so every other layer
/// only sees the [DocumentRepository] port — the data layer is the only
/// place that knows about `dart:io` or the underlying `markdown` package.

final class DocumentRepositoryProvider
    extends
        $FunctionalProvider<
          DocumentRepository,
          DocumentRepository,
          DocumentRepository
        >
    with $Provider<DocumentRepository> {
  /// Exposes the singleton [DocumentRepository] to the rest of the app.
  ///
  /// The concrete impl and the parser are wired here so every other layer
  /// only sees the [DocumentRepository] port — the data layer is the only
  /// place that knows about `dart:io` or the underlying `markdown` package.
  DocumentRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'documentRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$documentRepositoryHash();

  @$internal
  @override
  $ProviderElement<DocumentRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DocumentRepository create(Ref ref) {
    return documentRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DocumentRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DocumentRepository>(value),
    );
  }
}

String _$documentRepositoryHash() =>
    r'7e0cd7ca15af7cd00d8c0e4818ee767582de785f';
