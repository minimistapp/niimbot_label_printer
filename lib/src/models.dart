import 'dart:typed_data';

class BluetoothDevice {
  late String name;
  late String address;

  BluetoothDevice({
    required this.name,
    required this.address,
  });

  BluetoothDevice.fromString(String string) {
    List<String> list = string.split('#');
    name = list[0];
    address = list[1];
  }

  BluetoothDevice.fromMap(Map<String, dynamic> map) {
    name = map['name'];
    address = map['address'];
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
    };
  }
}

class PrintData {
  late List<int> data;
  late int width;
  late int height;
  late bool rotate;
  late bool invertColor;
  late int density;
  late int labelType;

  PrintData({
    required this.data,
    required this.width,
    required this.height,
    required this.rotate,
    required this.invertColor,
    required this.density,
    required this.labelType,
  });

  PrintData.fromMap(Map<String, dynamic> map) {
    data = map['bytes'];
    width = map['width'];
    height = map['height'];
    rotate = map['rotate'];
    invertColor = map['invertColor'];
    density = map['density'];
    labelType = map['labelType'];
  }

  Map<String, dynamic> toMap() {
    List<int> bytes = data;
    // Trasform bytes to Uint8List if necessary
    if (bytes.runtimeType == Uint8List) {
      bytes = bytes.toList();
    }
    return {
      'bytes': bytes,
      'width': width,
      'height': height,
      'rotate': rotate,
      'invertColor': invertColor,
      'density': density,
      'labelType': labelType,
    };
  }
}
