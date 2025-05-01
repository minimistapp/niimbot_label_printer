import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'niimbot_plugin_platform_interface.dart';

/// An implementation of [NiimbotPluginPlatform] that uses method channels.
class MethodChannelNiimbotPlugin extends NiimbotPluginPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel(Constants.niimbotPluginChannelName);

  /// The event channel used to receive events from the native platform.
  @visibleForTesting
  final eventChannel = const EventChannel(Constants.niimbotPluginEventChannelName);

  // Cached stream
  Stream<dynamic>? _eventStream;

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<bool> isBluetoothEnabled() async {
    final result = await methodChannel.invokeMethod<bool>('isBluetoothEnabled');
    return result ?? false;
  }

  @override
  Future<bool> isBluetoothPermissionGranted() async {
    final result = await methodChannel.invokeMethod<bool>('isBluetoothPermissionGranted');
    return result ?? false;
  }

  @override
  Future<bool> isConnected() async {
    final result = await methodChannel.invokeMethod<bool>('isConnected');
    return result ?? false;
  }

  @override
  Future<List<BluetoothDevice>> getPairedDevices() async {
    final result = await methodChannel.invokeMethod<List<Object?>>('getPairedDevices');
    return result?.map((deviceMap) => BluetoothDevice.fromMap(Map<String, dynamic>.from(deviceMap as Map))).toList() ?? [];
  }

  @override
  Future<bool> connect(BluetoothDevice device) async {
    final result = await methodChannel.invokeMethod<bool>('connect', device.toMap());
    return result ?? false;
  }

  @override
  Future<bool> disconnect() async {
    final result = await methodChannel.invokeMethod<bool>('disconnect');
    return result ?? false;
  }

  @override
  Future<bool> send(PrintData data) async {
    final result = await methodChannel.invokeMethod<bool>('send', data.toMap());
    return result ?? false;
  }

  @override
  Stream<dynamic> get events {
    _eventStream ??= eventChannel.receiveBroadcastStream();
    return _eventStream!;
  }
}
