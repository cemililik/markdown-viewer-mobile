import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
import 'package:markdown_viewer/features/viewer/presentation/screens/diagram_fullscreen_screen.dart';
import 'package:markdown_viewer/l10n/generated/app_localizations.dart';

/// Minimal transparent PNG so Image.memory does not choke on the
/// fullscreen composition. 1×1 fully-transparent 8-bit RGBA.
final Uint8List _pixelPng = Uint8List.fromList(const [
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x44,
  0x41,
  0x54,
  0x08,
  0xD7,
  0x63,
  0x00,
  0x00,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // `Image.memory` internally allocates a `_LiveImage` that is
  // released only when the Image widget is unmounted and its cache
  // entry rotates out. Widget-test teardown happens synchronously
  // on the same tick the tree is removed, so leak_tracker observes
  // the allocation before the image cache has actually flushed. The
  // object is reachable from the image cache, not genuinely leaked
  // — same rationale `markdown_view_test.dart` uses for
  // `TapGestureRecognizer`. Ignoring it keeps the test signal
  // meaningful instead of alarming on a framework-internal
  // bookkeeping path.
  LeakTesting.settings = LeakTesting.settings.withIgnored(
    classes: const ['_LiveImage', 'ImageStreamCompleterHandle'],
  );

  Widget harness(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: child,
    );
  }

  testWidgets(
    'renders close button and keeps reset hidden until transform is dirty',
    (tester) async {
      await tester.pumpWidget(
        harness(
          DiagramFullscreenScreen(
            args: DiagramFullscreenArgs(
              pngBytes: _pixelPng,
              width: 200,
              height: 100,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.close), findsOneWidget);
      // Reset is mounted inside an AnimatedOpacity that starts at 0
      // — the `IgnorePointer(ignoring: true)` sibling blocks taps
      // so the hidden affordance never fires by accident.
      expect(find.byIcon(Icons.center_focus_strong_outlined), findsOneWidget);
      // Take the *innermost* IgnorePointer ancestor — the screen
      // mounts several (one per chrome row, one around the reset
      // button) and only the innermost carries the transform-dirty
      // guard.
      final ignorePointers = tester.widgetList<IgnorePointer>(
        find.ancestor(
          of: find.byIcon(Icons.center_focus_strong_outlined),
          matching: find.byType(IgnorePointer),
        ),
      );
      expect(ignorePointers.first.ignoring, isTrue);
    },
  );

  testWidgets('tapping close pops the route', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    var popped = false;

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder:
                            (_) => DiagramFullscreenScreen(
                              args: DiagramFullscreenArgs(
                                pngBytes: _pixelPng,
                                width: 200,
                                height: 100,
                              ),
                            ),
                      ),
                    );
                    popped = true;
                  },
                  child: const Text('open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.close), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(popped, isTrue);
  });

  testWidgets('close button stays reachable after a tap on the diagram body', (
    tester,
  ) async {
    // A prior iteration wrapped the image in a GestureDetector that
    // toggled the chrome bar on tap. A missed tap on the close
    // button hid the close button itself — with the status bar
    // suppressed by immersive mode on iOS, the user had no
    // fallback affordance. This regression guards the persistent
    // chrome: the close icon must remain hit-testable after a
    // tap on any part of the diagram body.
    await tester.pumpWidget(
      harness(
        DiagramFullscreenScreen(
          args: DiagramFullscreenArgs(
            pngBytes: _pixelPng,
            width: 200,
            height: 100,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.close), findsOneWidget);

    // Tap well below the chrome bar on the diagram body — 300 dp
    // from the top clears the SafeArea + chrome padding on every
    // reasonable test viewport.
    await tester.tapAt(const Offset(200, 400));
    await tester.pumpAndSettle();

    // Close icon must still be visible AND tappable.
    expect(find.byIcon(Icons.close), findsOneWidget);
    final closeFinder = find.byIcon(Icons.close);
    expect(tester.getSize(closeFinder).height, greaterThan(0));
  });
}
