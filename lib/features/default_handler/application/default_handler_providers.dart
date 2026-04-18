import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown_viewer/features/default_handler/domain/default_handler_channel.dart';

/// Holds the [DefaultHandlerChannel] implementation. Overridden in
/// `main.dart` with the real method-channel instance; tests override
/// with a fake.
final defaultHandlerChannelProvider = Provider<DefaultHandlerChannel>((ref) {
  throw UnimplementedError(
    'defaultHandlerChannelProvider must be overridden in main.dart',
  );
});
