import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:markdown_viewer/features/library/library.dart';

final routerProvider = Provider<GoRouter>((ref) {
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
});

abstract final class LibraryRoute {
  static const String path = '/';
  static const String name = 'library';
}
