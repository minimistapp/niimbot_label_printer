import 'package:niimbot/niimbot_plugin_platform_interface.dart';

class NiimbotPlugin {
  Future<String?> getPlatformVersion() async {
    return await NiimbotPluginPlatform.instance.getPlatformVersion();
  }

  Future<bool> isBluetoothEnabled() async {
    return await NiimbotPluginPlatform.instance.isBluetoothEnabled();
  }

  Future<bool> isBluetoothPermissionGranted() async {
    return await NiimbotPluginPlatform.instance.isBluetoothPermissionGranted();
  }

  Future<bool> isConnected() async {
    return await NiimbotPluginPlatform.instance.isConnected();
  }

  /// Returns bluetooths paired devices
  Future<List<BluetoothDevice>> getPairedDevices() async {
    return await NiimbotPluginPlatform.instance.getPairedDevices();
  }

  Future<bool> connect(BluetoothDevice device) async {
    return await NiimbotPluginPlatform.instance.connect(device);
  }

  Future<bool> disconnect() async {
    return await NiimbotPluginPlatform.instance.disconnect();
  }

  Future<bool> send(PrintData data) async {
    return await NiimbotPluginPlatform.instance.send(data);
  }

  /// Returns a stream of events from the native plugin.
  ///
  /// This can include log messages, Bluetooth status updates, etc.
  /// Listen to this stream to get real-time updates.
  Stream<dynamic> get events {
    return NiimbotPluginPlatform.instance.events;
  }
}
