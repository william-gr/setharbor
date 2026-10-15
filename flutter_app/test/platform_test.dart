import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setharbor/data/platform_gateway.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'native boundary forwards documents URLs sharing state and link events',
    () async {
      final calls = <MethodCall>[];
      final platform = PlatformGateway();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(PlatformGateway.channel, (call) async {
        calls.add(call);
        return switch (call.method) {
          'readState' => '{}',
          'readLegacy' => '{}',
          'pickDocument' => '{"file":true}',
          'exportDocument' => true,
          'initialLink' => 'setharbor://workout#v1.x',
          'fetchPlan' => '{"plan":true}',
          _ => null,
        };
      });
      expect(await platform.readState(), '{}');
      expect(await platform.readLegacy(), '{}');
      await platform.writeState('state');
      expect(await platform.pickDocument(123), ' {"file":true}'.trim());
      expect(await platform.exportDocument('backup'), true);
      await platform.share('prompt');
      await platform.openUrl('https://example.com');
      await platform.linkSettings();
      expect(await platform.initialLink(), 'setharbor://workout#v1.x');
      expect(
        await platform.fetchPlan('https://example.com'),
        ' {"plan":true}'.trim(),
      );
      final received = <String>[];
      platform.listenLinks(received.add);
      Future<void> event(String method, Object? value) async {
        final data = const StandardMethodCodec().encodeMethodCall(
          MethodCall(method, value),
        );
        await messenger.handlePlatformMessage(
          PlatformGateway.channel.name,
          data,
          (ByteData? response) {},
        );
      }

      await event('link', 'one');
      await event('other', 'two');
      await event('link', 1);
      expect(received, ['one']);
      platform.stopListening();
      expect(
        calls.map((c) => c.method),
        containsAll([
          'writeState',
          'pickDocument',
          'exportDocument',
          'share',
          'openUrl',
          'linkSettings',
        ]),
      );
      messenger.setMockMethodCallHandler(
        PlatformGateway.channel,
        (call) async => null,
      );
      expect(await platform.readLegacy(), '{}');
      expect(await platform.exportDocument('backup'), false);
      messenger.setMockMethodCallHandler(PlatformGateway.channel, null);
    },
  );
}
