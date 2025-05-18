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
  late Uint8List bytes;
  late int imagePixelWidth;
  late int imagePixelHeight;
  late double labelWidthMm;
  late double labelHeightMm;
  late bool rotate;
  late bool invertColor;
  late int density;
  late int labelType;
  late int quantity;

  PrintData({
    required this.bytes,
    required this.imagePixelWidth,
    required this.imagePixelHeight,
    required this.labelWidthMm,
    required this.labelHeightMm,
    required this.rotate,
    required this.invertColor,
    required this.density,
    required this.labelType,
    this.quantity = 1,
  });

  PrintData.fromMap(Map<String, dynamic> map) {
    bytes = map['bytes'];
    imagePixelWidth = map['imagePixelWidth'] ?? map['width'];
    imagePixelHeight = map['imagePixelHeight'] ?? map['height'];
    labelWidthMm = map['labelWidthMm']?.toDouble() ?? (map['width'] as num?)?.toDouble() ?? 0.0;
    labelHeightMm = map['labelHeightMm']?.toDouble() ?? (map['height'] as num?)?.toDouble() ?? 0.0;
    rotate = map['rotate'];
    invertColor = map['invertColor'];
    density = map['density'];
    labelType = map['labelType'];
    quantity = map['quantity'] ?? 1;
  }

  Map<String, dynamic> toMap() {
    return {
      'bytes': bytes,
      'width': labelWidthMm,
      'height': labelHeightMm,
      'imagePixelWidth': imagePixelWidth,
      'imagePixelHeight': imagePixelHeight,
      'rotate': rotate,
      'invertColor': invertColor,
      'density': density,
      'labelType': labelType,
      'quantity': quantity,
    };
  }
}
