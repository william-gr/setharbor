import 'package:flutter/services.dart';

/// The small native boundary: durable atomic IO and OS document/share/link UI.
class PlatformGateway {
  static const channel = MethodChannel('com.william.treino/platform');
  Future<String?> readState() => channel.invokeMethod<String>('readState');
  Future<String> readLegacy() async =>
      await channel.invokeMethod<String>('readLegacy') ?? '{}';
  Future<void> writeState(String json) =>
      channel.invokeMethod<void>('writeState', json);
  Future<String?> pickDocument(int maxBytes) =>
      channel.invokeMethod<String>('pickDocument', maxBytes);
  Future<bool> exportDocument(String json) async =>
      await channel.invokeMethod<bool>('exportDocument', json) ?? false;
  Future<void> share(String text) => channel.invokeMethod<void>('share', text);
  Future<void> openUrl(String url) =>
      channel.invokeMethod<void>('openUrl', url);
  Future<void> linkSettings() => channel.invokeMethod<void>('linkSettings');
  Future<String?> initialLink() => channel.invokeMethod<String>('initialLink');
  Future<String> fetchPlan(String url) async =>
      (await channel.invokeMethod<String>('fetchPlan', url))!;
  void listenLinks(void Function(String) receive) {
    channel.setMethodCallHandler((call) async {
      if (call.method == 'link' && call.arguments is String) {
        receive(call.arguments as String);
      }
    });
  }

  void stopListening() {
    channel.setMethodCallHandler(null);
  }
}
