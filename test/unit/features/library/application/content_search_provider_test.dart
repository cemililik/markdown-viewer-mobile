import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/features/library/application/content_search_provider.dart';

void main() {
  test('idle state is empty by default', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final state = container.read(contentSearchControllerProvider);
    expect(state.query, '');
    expect(state.results, isEmpty);
    expect(state.isLoading, isFalse);
  });

  test('empty query reverts to idle immediately', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(contentSearchControllerProvider.notifier)
        .submitQuery(
          raw: '   ',
          recentsSourceLabel: 'Recent',
          folderSourceLabelBuilder: (_) => 'Folder',
          syncedRepoSourceLabelBuilder: (_) => 'Repo',
        );
    final state = container.read(contentSearchControllerProvider);
    expect(state.query, '');
    expect(state.results, isEmpty);
    expect(state.isLoading, isFalse);
  });

  // Note: end-to-end dispatch (debounce → service → state update)
  // depends on the recents / folders / synced-repos Riverpod
  // providers being reachable from `ref.read`. Wiring the full
  // store/notifier override chain inside a unit test would
  // essentially reproduce `main.dart`'s composition root. Higher-
  // level behaviour is covered by the widget tests that mount
  // `LibraryScreen` with concrete stubs; this test file focuses on
  // the state-machine behaviour of the notifier itself.

  test(
    'non-empty submit flips the state to loading with the normalised query',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(contentSearchControllerProvider.notifier)
          .submitQuery(
            raw: '  KeyWord  ',
            recentsSourceLabel: 'Recent',
            folderSourceLabelBuilder: (_) => 'F',
            syncedRepoSourceLabelBuilder: (_) => 'R',
          );
      final state = container.read(contentSearchControllerProvider);
      expect(state.query, 'keyword');
      expect(state.isLoading, isTrue);
    },
  );

  test('clear() returns the notifier to idle', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(contentSearchControllerProvider.notifier);
    notifier.submitQuery(
      raw: 'abcd',
      recentsSourceLabel: 'Recent',
      folderSourceLabelBuilder: (_) => 'F',
      syncedRepoSourceLabelBuilder: (_) => 'R',
    );
    notifier.clear();
    final state = container.read(contentSearchControllerProvider);
    expect(state.query, '');
    expect(state.results, isEmpty);
    expect(state.isLoading, isFalse);
  });
}
