import 'package:flutter/services.dart';
import 'package:markdown_viewer/features/default_handler/domain/default_handler_channel.dart';

/// Method-channel wrapper around the platform "default handler"
/// settings launcher.
class DefaultHandlerChannelImpl implements DefaultHandlerChannel {
  DefaultHandlerChannelImpl({MethodChannel? channel})
    : _channel =
          channel ??
          const MethodChannel('com.cemililik.markdown_viewer/default_handler');

  final MethodChannel _channel;

  @override
  Future<bool> openDefaultHandlerSettings() async {
    try {
      final ok = await _channel.invokeMethod<bool>(
        'openDefaultHandlerSettings',
      );
      return ok ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
