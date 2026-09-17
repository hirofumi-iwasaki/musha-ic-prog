import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mushagaeshi_ic_programmer/platform/desktop_host.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'native close is blocked while busy; drops retain their payload',
    () async {
      var busy = true;
      final events = <MethodCall>[];
      final host = DesktopHost(
        canClose: () => !busy,
        onFileEvent: (call) async => events.add(call),
      )..attach();
      addTearDown(host.dispose);
      Future<dynamic> send(String method, [dynamic args]) async {
        final response = Completer<dynamic>();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
              'mushagaeshi/programmer_files',
              const StandardMethodCodec().encodeMethodCall(
                MethodCall(method, args),
              ),
              (bytes) => response.complete(
                const StandardMethodCodec().decodeEnvelope(bytes!),
              ),
            );
        return response.future;
      }

      expect(await send('closeRequested'), false);
      busy = false;
      expect(await send('closeRequested'), true);
      await send('fileDropped', {
        'path': 'C:\\Test\\日本語.bin',
        'x': 50.0,
        'y': 90.0,
      });
      expect(events.single.arguments['path'], 'C:\\Test\\日本語.bin');
    },
  );
}
