import 'package:go_router/go_router.dart';
import 'package:markdown_viewer/features/library/library.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'router.g.dart';

@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  return GoRouter(
    initialLocation: LibraryRoute.path,
    routes: [
      GoRoute(
        path: LibraryRoute.path,
        name: LibraryRoute.name,
        builder: (context, state) => const LibraryScreen(),
      ),
    ],
  );
}

abstract final class LibraryRoute {
  static const String path = '/';
  static const String name = 'library';
}
