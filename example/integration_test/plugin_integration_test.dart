// This is a basic Flutter integration test.
//
// Since integration tests run in a full Flutter application, they can interact
// with the host side of a plugin implementation, unlike Dart unit tests.
//
// For more information about Flutter integration tests, please see
// https://docs.flutter.dev/cookbook/testing/integration/introduction

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:niimbot/niimbot.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final NiimbotPlugin plugin = NiimbotPlugin();

  testWidgets('getPlatformVersion test', (WidgetTester tester) async {
    final String? version = await plugin.getPlatformVersion();
    // The version string depends on the host platform running the test, so
    // just assert that some non-empty string is returned.
    expect(version?.isNotEmpty, true);
  });

  testWidgets('isBluetoothEnabled test', (WidgetTester tester) async {
    final bool isEnabled = await plugin.isBluetoothEnabled();
    expect(isEnabled, false);
  });

  testWidgets('isBluetoothPermissionGranted test', (WidgetTester tester) async {
    final bool isGranted = await plugin.isBluetoothPermissionGranted();
    expect(isGranted, true);
  });

  testWidgets('isConnected test', (WidgetTester tester) async {
    final bool isConnected = await plugin.isConnected();
    expect(isConnected, false);
  });

  // PlatformException(BLUETOOTH_DISABLED, Bluetooth is not enabled, null, null)
  // testWidgets('getPairedDevices test', (WidgetTester tester) async {
  //   final List<BluetoothDevice> devices = await plugin.getPairedDevices();
  //   expect(devices.isNotEmpty, true);
  // });

  // PlatformException(BLUETOOTH_DISABLED, Bluetooth is not enabled, null, null)
  // testWidgets('connect test', (WidgetTester tester) async {
  //   final List<BluetoothDevice> devices = await plugin.getPairedDevices();
  //   if (devices.isEmpty) {
  //     return;
  //   }
  //   final bool isConnected = await plugin.connect(devices[0]);
  //   expect(isConnected, true);
  // });

  testWidgets('disconnect test', (WidgetTester tester) async {
    final bool isDisconnected = await plugin.disconnect();
    expect(isDisconnected, true);
  });

  // PlatformException(NOT_CONNECTED, Printer not connected, null, null)
  // testWidgets('send test', (WidgetTester tester) async {
  //   final Uint8List data = Uint8List.fromList([1, 2, 3]);
  //   final PrintData printData = PrintData(
  //     data: data,
  //     width: 100,
  //     height: 100,
  //     rotate: false,
  //     invertColor: false,
  //     density: 1,
  //     labelType: 1,
  //   );
  //   final bool isSent = await plugin.send(printData);
  //   expect(isSent, true);
  // });
}
