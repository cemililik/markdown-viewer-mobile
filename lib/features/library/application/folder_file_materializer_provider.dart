import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown_viewer/features/library/data/services/folder_file_materializer.dart';
import 'package:markdown_viewer/features/library/data/services/native_library_folders_channel.dart';

/// Single shared [NativeLibraryFoldersChannel] for the whole app.
///
/// The method channel is a stateless RPC proxy — there is no harm in
/// sharing a single instance, and routing every caller through the
/// provider lets widget tests swap in a fake that records calls
/// without subclassing the widget tree. Overridden in `main.dart`
/// with a `const NativeLibraryFoldersChannel()` and replaced in
/// tests with an injectable fake.
final nativeLibraryFoldersChannelProvider =
    Provider<NativeLibraryFoldersChannel>(
      (ref) => NativeLibraryFoldersChannel(),
    );

/// Application-layer binding for [FolderFileMaterializer].
///
/// Resolves its [NativeLibraryFoldersChannel] through
/// [nativeLibraryFoldersChannelProvider] so tests can inject a fake
/// channel without subclassing [FolderFileMaterializer] itself. The
/// materializer's optional cache-directory override is reserved for
/// unit tests that want to redirect writes to a temp dir; production
/// leaves it `null` and picks up the real app cache directory.
final folderFileMaterializerProvider = Provider<FolderFileMaterializer>(
  (ref) => FolderFileMaterializer(
    channel: ref.watch(nativeLibraryFoldersChannelProvider),
  ),
);
