import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'method_channel_niimbot_plugin.dart';

import 'src/models.dart';

export 'src/models.dart';
export 'src/constants.dart';

/// Defines WHAT needs to be done (the contract). Uses UnimplementedError as a default/placeholder.
abstract class NiimbotPluginPlatform extends PlatformInterface {
  /// Constructs a NiimbotPluginPlatform.
  NiimbotPluginPlatform() : super(token: _token);

  static final Object _token = Object();

  static NiimbotPluginPlatform _instance = MethodChannelNiimbotPlugin();

  /// The default instance of [NiimbotPluginPlatform] to use.
  ///
  /// Defaults to [MethodChannelNiimbotPlugin].
  static NiimbotPluginPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [NiimbotPluginPlatform] when
  /// they register themselves.
  static set instance(NiimbotPluginPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<bool> isBluetoothEnabled() {
    throw UnimplementedError('isBluetoothEnabled() has not been implemented.');
  }

  Future<bool> isBluetoothPermissionGranted() {
    throw UnimplementedError('isBluetoothPermissionGranted() has not been implemented.');
  }

  Future<bool> isConnected() {
    throw UnimplementedError('isConnected() has not been implemented.');
  }

  Future<List<BluetoothDevice>> getPairedDevices() {
    throw UnimplementedError('getPairedDevices() has not been implemented.');
  }

  Future<bool> connect(BluetoothDevice device) {
    throw UnimplementedError('connect() has not been implemented.');
  }

  Future<bool> disconnect() {
    throw UnimplementedError('disconnect() has not been implemented.');
  }

  Future<bool> send(PrintData data) {
    throw UnimplementedError('send() has not been implemented.');
  }
}
