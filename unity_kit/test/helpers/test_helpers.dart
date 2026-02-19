import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sets up a fake MethodChannel for testing platform calls.
///
/// Returns the list of logged method calls for verification.
List<MethodCall> setupFakeMethodChannel(
  String channelName, {
  dynamic Function(MethodCall)? handler,
}) {
  final log = <MethodCall>[];

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    MethodChannel(channelName),
    (call) async {
      log.add(call);
      return handler?.call(call);
    },
  );

  return log;
}

/// Tears down a fake MethodChannel after testing.
void tearDownFakeMethodChannel(String channelName) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    MethodChannel(channelName),
    null,
  );
}
