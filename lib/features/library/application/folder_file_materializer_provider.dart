import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown_viewer/features/library/domain/services/folder_file_materializer.dart';
import 'package:markdown_viewer/features/library/domain/services/native_library_folders_channel.dart';

/// Application-layer binding for [NativeLibraryFoldersChannel].
///
/// Overridden in `main.dart` with a `NativeLibraryFoldersChannelImpl`
/// (data layer); unit / widget tests swap in a fake that records
/// channel calls without subclassing the widget tree. Throws by
/// default so a missing composition-root override fails loudly
/// instead of silently calling into a method channel that may not
/// exist in the test environment.
final nativeLibraryFoldersChannelProvider =
    Provider<NativeLibraryFoldersChannel>((ref) {
      throw UnimplementedError(
        'nativeLibraryFoldersChannelProvider must be overridden in the '
        'composition root (lib/main.dart) with '
        'NativeLibraryFoldersChannelImpl, or in tests with a fake.',
      );
    });

/// Application-layer binding for [FolderFileMaterializer].
///
/// Overridden in `main.dart` with a `FolderFileMaterializerImpl` that
/// pulls its channel from [nativeLibraryFoldersChannelProvider]; tests
/// that don't exercise materialization leave this untouched.
final folderFileMaterializerProvider = Provider<FolderFileMaterializer>((ref) {
  throw UnimplementedError(
    'folderFileMaterializerProvider must be overridden in the composition '
    'root (lib/main.dart) with FolderFileMaterializerImpl, or in tests.',
  );
});
