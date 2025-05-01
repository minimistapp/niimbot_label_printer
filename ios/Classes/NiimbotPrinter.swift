import CoreBluetooth
import CoreGraphics  // For CGImage later
import Foundation
import UIKit  // For UIImage later

// Placeholder UUIDs - Replace with actual Niimbot Service/Characteristic UUIDs
let niimbotServiceUUID = CBUUID(string: "000018F0-0000-1000-8000-00805F9B34FB")  // Example Service UUID
let niimbotWriteCharacteristicUUID = CBUUID(string: "00002AF1-0000-1000-8000-00805F9B34FB")  // Example Write Characteristic UUID
let niimbotNotifyCharacteristicUUID = CBUUID(string: "00002AF0-0000-1000-8000-00805F9B34FB")  // Example Notify Characteristic UUID

protocol NiimbotPrinterDelegate: AnyObject {
  func printerDidRespond(data: Data?, error: Error?)
  func printerDidSend(error: Error?)
  // Add other delegate methods as needed for state changes, etc.
}

class NiimbotPrinter: NSObject {

  private var peripheral: CBPeripheral?
  private var writeCharacteristic: CBCharacteristic?
  private var notifyCharacteristic: CBCharacteristic?

  weak var delegate: NiimbotPrinterDelegate?

  // Queue for handling responses sequentially if needed
  private var commandQueue: [(requestCode: UInt8, data: Data)] = []
  private var isSending: Bool = false
  private var responseBuffer = Data()

  init(peripheral: CBPeripheral) {
    super.init()
    self.peripheral = peripheral
    self.peripheral?.delegate = self  // Set delegate to handle peripheral events
  }

  // MARK: - Public Methods (Placeholder Implementations)

  func discoverServices() {
    print("NiimbotPrinter: Discovering services...")
    peripheral?.discoverServices([niimbotServiceUUID])
  }

  func printBitmap(
    _ bitmap: UIImage, density: Int = 3, labelType: Int = 1, quantity: Int = 1,
    rotate: Bool = false, invertColor: Bool = false
  ) async throws {
    // TODO: Implement image processing and command sequence
    print("NiimbotPrinter: printBitmap called (not implemented)")

    guard writeCharacteristic != nil else {
      print("Write characteristic not available")
      throw NiimbotError.characteristicNotFound
    }

    // 1. Set Density
    try await setLabelDensity(density)
    // 2. Set Label Type
    try await setLabelType(labelType)
    // 3. Start Print
    try await startPrint()
    // 4. Start Page Print
    try await startPagePrint()
    // 5. Set Dimension
    let imageToPrint = processImage(bitmap, rotate: rotate, invertColor: invertColor)
    guard let cgImage = imageToPrint.cgImage else {
      throw NiimbotError.imageProcessingFailed
    }
    try await setDimension(width: cgImage.height, height: cgImage.width)  // Note: Width/Height swapped as in Kotlin? Check printer expectation
    // 6. Set Quantity
    try await setQuantity(quantity)

    // 7. Encode and Send Image Data
    let imagePackets = encodeImage(imageToPrint)
    print("NiimbotPrinter: Sending \(imagePackets.count) image packets...")
    for packet in imagePackets {
      // Send packet without waiting for specific response for each image line
      await sendRawCommand(packet: packet, requiresResponse: false)
      // Small delay might still be needed depending on printer buffer
      try await Task.sleep(nanoseconds: 10_000_000)  // 10ms delay
    }
    print("NiimbotPrinter: Finished sending image packets.")

    // 8. End Page Print (Wait for response confirming page end processing)
    _ = try await endPagePrint()  // Await the response

    // 9. Poll Status until printing is done (More complex - requires waiting for notifications)
    print("NiimbotPrinter: Waiting for print completion (polling not implemented)...")
    // This part needs careful implementation using notifications from getPrintStatus
    // For now, just add a delay.
    try await Task.sleep(nanoseconds: 2_000_000_000)  // 2 second delay

    // 10. End Print
    try await endPrint()
    print("NiimbotPrinter: Print sequence completed.")
  }

  // MARK: - Command Sending

  private func sendCommand(requestCode: UInt8, data: Data = Data(), requiresResponse: Bool = true)
    async throws -> Data?
  {
    guard let peripheral = peripheral, let characteristic = writeCharacteristic else {
      throw NiimbotError.notConnected
    }

    let packet = createPacket(type: requestCode, data: data)
    //print("Sending packet: \(packet.hexEncodedString())")

    return try await withCheckedThrowingContinuation { continuation in
      // Store continuation to be resumed when response arrives or write confirms
      // Simple approach for now: write and hope for the best or handle confirmation in delegate
      peripheral.writeValue(
        packet, for: characteristic, type: requiresResponse ? .withResponse : .withoutResponse)

      if requiresResponse {
        // TODO: Need a mechanism to match responses to requests
        // For now, we'll rely on the delegate getting *some* response
        // A proper implementation needs request IDs or a queue with continuations.
        // This simple version just returns nil for now after write.
        // A more robust version would store the continuation and resume it
        // in the peripheral(_:didUpdateValueFor:error:) delegate method.
        print(
          "WARN: Response handling not fully implemented for command 0x\(String(requestCode, radix: 16))"
        )
        continuation.resume(returning: nil)  // Placeholder
      } else {
        continuation.resume(returning: nil)  // No response expected
      }
      // TODO: Handle write errors in peripheral(_:didWriteValueFor:error:)
    }
  }

  // Simplified sender for image data where we don't expect specific responses per packet
  private func sendRawCommand(packet: Data, requiresResponse: Bool = false) async {
    guard let peripheral = peripheral, let characteristic = writeCharacteristic else {
      print("Error: Cannot send raw command, peripheral or characteristic unavailable.")
      return
    }
    // print("Sending raw packet: \(packet.hexEncodedString())")
    peripheral.writeValue(
      packet, for: characteristic, type: requiresResponse ? .withResponse : .withoutResponse)
    // We might need a small delay even for .withoutResponse if the buffer fills up
    // try? await Task.sleep(nanoseconds: 5_000_000) // 5ms
  }

  private func createPacket(type: UInt8, data: Data) -> Data {
    var packetData = Data()
    packetData.append(0x55)  // Header
    packetData.append(0x55)
    packetData.append(type)
    packetData.append(UInt8(data.count & 0xFF))  // Size (assuming max 255)
    packetData.append(data)

    var checksum = Int32(type) ^ Int32(data.count & 0xFF)
    data.forEach { checksum ^= Int32($0) }

    packetData.append(UInt8(checksum & 0xFF))
    packetData.append(0xAA)  // Footer
    packetData.append(0xAA)

    return packetData
  }

  // MARK: - Image Processing

  private func processImage(_ image: UIImage, rotate: Bool, invertColor: Bool) -> UIImage {
    var processedImage = image
    if rotate {
      processedImage = rotateImage(image: processedImage, degrees: 90) ?? processedImage
    }
    if invertColor {
      processedImage = invertImageColors(image: processedImage) ?? processedImage
    }
    // Convert to monochrome bitmap format suitable for the printer
    // This might involve dithering or thresholding. Let's start simple.
    guard let cgImage = processedImage.cgImage else { return image }  // Should not happen if rotation/inversion worked

    // Convert to a format suitable for getPixelColor (e.g., ARGB)
    guard let finalImage = convertToARGB(cgImage: cgImage) else { return image }

    return finalImage
  }

  private func convertToARGB(cgImage: CGImage) -> UIImage? {
    let width = cgImage.width
    let height = cgImage.height
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bytesPerRow = width * 4
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue).union(
      .byteOrder32Big)  // Use ARGB_8888 equivalent

    guard
      let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow,
        space: colorSpace, bitmapInfo: bitmapInfo.rawValue)
    else {
      print("Error: Could not create CGContext for ARGB conversion")
      return nil
    }

    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

    guard let outputCGImage = context.makeImage() else {
      print("Error: Could not make image from context")
      return nil
    }

    return UIImage(cgImage: outputCGImage)
  }

  private func rotateImage(image: UIImage, degrees: CGFloat) -> UIImage? {
    guard let cgImage = image.cgImage else { return nil }

    let rotatedSize = CGRect(origin: .zero, size: image.size)
      .applying(CGAffineTransform(rotationAngle: degrees * .pi / 180))
      .integral.size

    UIGraphicsBeginImageContextWithOptions(rotatedSize, false, image.scale)
    guard let context = UIGraphicsGetCurrentContext() else { return nil }

    // Move origin to center
    context.translateBy(x: rotatedSize.width / 2, y: rotatedSize.height / 2)
    // Rotate
    context.rotate(by: degrees * .pi / 180)
    // Draw the image centered
    context.scaleBy(x: 1.0, y: -1.0)  // Correct for flipped coordinate system
    context.draw(
      cgImage,
      in: CGRect(
        x: -image.size.width / 2, y: -image.size.height / 2, width: image.size.width,
        height: image.size.height))

    let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()

    return rotatedImage
  }

  private func invertImageColors(image: UIImage) -> UIImage? {
    guard let cgImage = image.cgImage else { return nil }
    let ciImage = CIImage(cgImage: cgImage)

    guard let filter = CIFilter(name: "CIColorInvert") else { return nil }
    filter.setValue(ciImage, forKey: kCIInputImageKey)

    guard let outputCIImage = filter.outputImage else { return nil }
    let context = CIContext(options: nil)

    guard let outputCGImage = context.createCGImage(outputCIImage, from: outputCIImage.extent)
    else { return nil }
    return UIImage(cgImage: outputCGImage, scale: image.scale, orientation: image.imageOrientation)
  }

  private func encodeImage(_ bitmap: UIImage) -> [Data] {
    guard let cgImage = bitmap.cgImage else { return [] }
    let width = cgImage.width
    let height = cgImage.height

    guard let pixelData = cgImage.dataProvider?.data,
      let dataPtr = CFDataGetBytePtr(pixelData)
    else {
      print("Error: Could not get pixel data")
      return []
    }

    let bytesPerPixel = cgImage.bitsPerPixel / 8
    let bytesPerRow = cgImage.bytesPerRow

    var packets: [Data] = []

    print("Encoding image: \(width)x\(height), bpp: \(bytesPerPixel), stride: \(bytesPerRow)")

    // Iterate through each row (y)
    for y in 0..<height {
      var lineData = Data(repeating: 0, count: (width + 7) / 8)  // Ceiling division

      // Iterate through each pixel in the row (x)
      for x in 0..<width {
        let pixelOffset = y * bytesPerRow + x * bytesPerPixel

        // Extract pixel color - Assuming ARGB or RGBA based on context creation
        // We need the alpha channel to decide if it's "on" or "off".
        // Let's assume black (or opaque) pixels are "on".
        // Adjust based on the actual format from convertToARGB
        let alphaComponent: UInt8
        // Check bitmap info from cgImage or assume based on convertToARGB
        let alphaInfo = cgImage.alphaInfo
        if alphaInfo == .premultipliedLast || alphaInfo == .last {  // RGBA
          alphaComponent = dataPtr[pixelOffset + 3]
        } else if alphaInfo == .premultipliedFirst || alphaInfo == .first {  // ARGB
          alphaComponent = dataPtr[pixelOffset]
        } else {
          // Assume opaque if no alpha or unknown format
          alphaComponent = 255
        }

        // For monochrome: treat any sufficiently opaque pixel as "black" (on)
        // The Kotlin code checks for 0xFF000000 which is opaque black in ARGB.
        // Let's consider opaque pixels as "on"
        let isPixelOn = alphaComponent > 128  // Threshold alpha

        if isPixelOn {
          // Set the corresponding bit in lineData
          let byteIndex = x / 8
          let bitIndex = 7 - (x % 8)  // High bit first
          lineData[byteIndex] |= (1 << bitIndex)
        }
      }

      // Create the packet for this line (Type 0x85)
      var packetPayload = Data()
      // Add header: y-coordinate (2 bytes), counts (3 bytes), 1 (1 byte)
      packetPayload.append(UInt16(y).bigEndianData)  // y (Short)
      packetPayload.append(contentsOf: [0x00, 0x00, 0x00])  // counts
      packetPayload.append(0x01)  // type?
      packetPayload.append(lineData)  // The actual bitmap line data

      let linePacket = createPacket(type: 0x85, data: packetPayload)
      packets.append(linePacket)
    }

    return packets
  }

  // MARK: - Specific Commands (Ported from Kotlin)

  func setLabelDensity(_ n: Int) async throws -> Bool {
    guard (1...5).contains(n) else {
      throw NiimbotError.invalidArgument("Density must be between 1 and 5")
    }
    _ = try await sendCommand(requestCode: 0x21, data: Data([UInt8(n)]))
    // TODO: Parse response data to confirm success (Kotlin checked response[4])
    return true  // Placeholder
  }

  func setLabelType(_ n: Int) async throws -> Bool {
    guard (1...3).contains(n) else {
      throw NiimbotError.invalidArgument("Label type must be between 1 and 3")
    }
    _ = try await sendCommand(requestCode: 0x23, data: Data([UInt8(n)]))
    // TODO: Parse response
    return true  // Placeholder
  }

  func startPrint() async throws -> Bool {
    _ = try await sendCommand(requestCode: 0x01, data: Data([1]))
    // TODO: Parse response
    return true  // Placeholder
  }

  func endPrint() async throws -> Bool {
    _ = try await sendCommand(requestCode: 0xF3, data: Data([1]))
    // TODO: Parse response
    return true  // Placeholder
  }

  func startPagePrint() async throws -> Bool {
    _ = try await sendCommand(requestCode: 0x03, data: Data([1]))
    // TODO: Parse response
    return true  // Placeholder
  }

  func endPagePrint() async throws -> Bool {
    print("Sending endPagePrint (0xE3)...")
    _ = try await sendCommand(requestCode: 0xE3, data: Data([1]))
    print("endPagePrint sent, awaiting response/confirmation...")
    // TODO: Parse response - this one might be important for flow control
    return true  // Placeholder
  }

  func allowPrintClear() async throws -> Bool {
    _ = try await sendCommand(requestCode: 0x20, data: Data([1]))
    // TODO: Parse response
    return true  // Placeholder
  }

  func setDimension(width: Int, height: Int) async throws -> Bool {
    var data = Data()
    data.append(UInt16(width).bigEndianData)
    data.append(UInt16(height).bigEndianData)
    _ = try await sendCommand(requestCode: 0x13, data: data)
    // TODO: Parse response
    return true  // Placeholder
  }

  func setQuantity(_ n: Int) async throws -> Bool {
    let data = UInt16(n).bigEndianData
    _ = try await sendCommand(requestCode: 0x15, data: data)
    // TODO: Parse response
    return true  // Placeholder
  }

  func getPrintStatus() async throws -> [String: Int] {
    _ = try await sendCommand(requestCode: 0xA3, data: Data([1]))
    // TODO: Parse response data based on Kotlin implementation
    print("WARN: getPrintStatus response parsing not implemented")
    return ["page": 0, "progress1": 0, "progress2": 0]  // Placeholder
  }

  func getInfo(key: UInt8) async throws -> Any {
    _ = try await sendCommand(requestCode: 0x40, data: Data([key]))
    // TODO: Parse response data based on Kotlin implementation for different keys
    print("WARN: getInfo response parsing not implemented")
    return 0  // Placeholder
  }

  func getRfid() async throws -> [String: Any]? {
    _ = try await sendCommand(requestCode: 0x1A, data: Data([1]))
    // TODO: Parse response data based on Kotlin implementation
    print("WARN: getRfid response parsing not implemented")
    return nil  // Placeholder
  }

  func heartbeat() async throws -> [String: Int?] {
    _ = try await sendCommand(requestCode: 0xDC, data: Data([1]))
    // TODO: Parse response data based on Kotlin implementation (handle different lengths)
    print("WARN: heartbeat response parsing not implemented")
    return [:]  // Placeholder
  }

  // MARK: - Disconnect
  func cleanup() {
    // Cancel pending commands, clear buffer, etc.
    peripheral?.delegate = nil  // Prevent further delegate calls
    peripheral = nil
    writeCharacteristic = nil
    notifyCharacteristic = nil
    // Clear queue, reset state vars
    print("NiimbotPrinter cleaned up.")
  }

}

// MARK: - CBPeripheralDelegate
extension NiimbotPrinter: CBPeripheralDelegate {

  func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
    if let error = error {
      print("Error discovering services: \(error.localizedDescription)")
      // TODO: Handle error (e.g., notify delegate/plugin)
      return
    }

    guard let services = peripheral.services else { return }

    for service in services {
      if service.uuid == niimbotServiceUUID {
        print("Niimbot service found. Discovering characteristics...")
        // Discover specific characteristics we need
        peripheral.discoverCharacteristics(
          [niimbotWriteCharacteristicUUID, niimbotNotifyCharacteristicUUID], for: service)
        return
      }
    }
    print("Error: Niimbot service not found.")
    // TODO: Handle error
  }

  func peripheral(
    _ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?
  ) {
    if let error = error {
      print("Error discovering characteristics: \(error.localizedDescription)")
      // TODO: Handle error
      return
    }

    guard let characteristics = service.characteristics else { return }
    var foundWrite = false
    var foundNotify = false

    print("Found characteristics for service \(service.uuid):")
    for characteristic in characteristics {
      print("- \(characteristic.uuid)")
      if characteristic.uuid == niimbotWriteCharacteristicUUID {
        print("  -> Write characteristic found.")
        self.writeCharacteristic = characteristic
        foundWrite = true
      } else if characteristic.uuid == niimbotNotifyCharacteristicUUID {
        print("  -> Notify characteristic found.")
        self.notifyCharacteristic = characteristic
        foundNotify = true
        // Subscribe to notifications
        peripheral.setNotifyValue(true, for: characteristic)
      }
    }

    if foundWrite && foundNotify {
      print("Required characteristics found.")
      // TODO: Notify plugin/delegate that the printer is ready
    } else {
      print(
        "Error: Required characteristics not found. Write: \(foundWrite), Notify: \(foundNotify)")
      // TODO: Handle error
    }
  }

  // Called when peripheral.writeValue is used with .withResponse
  func peripheral(
    _ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?
  ) {
    if let error = error {
      print("Error writing value to \(characteristic.uuid): \(error.localizedDescription)")
      delegate?.printerDidSend(error: error)
    } else {
      //print("Successfully wrote value to \(characteristic.uuid)")
      delegate?.printerDidSend(error: nil)
      // If using a command queue/continuation system, resume the continuation here
    }
  }

  // Called when peripheral.writeValue is used with .withoutResponse (confirmation isn't guaranteed)
  // Or just indicates the peripheral is ready for more data.
  func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
    // print("Peripheral ready to send write without response.")
    // If managing flow control for writes without response, send next chunk here.
  }

  // Called when the peripheral sends data (if notifications/indications are enabled)
  func peripheral(
    _ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?
  ) {
    if let error = error {
      print(
        "Error receiving notification for \(characteristic.uuid): \(error.localizedDescription)")
      delegate?.printerDidRespond(data: nil, error: error)
      return
    }

    guard let data = characteristic.value else {
      print("Received notification with no data for \(characteristic.uuid)")
      delegate?.printerDidRespond(data: nil, error: nil)  // Or perhaps an error?
      return
    }

    print(
      "Received data (\(data.count) bytes) on \(characteristic.uuid): \(data.hexEncodedString())")
    // TODO: Process the received data
    // - Check if it's a complete packet (using header/footer/checksum)
    // - If using continuations, find the matching request and resume it.
    // - Otherwise, notify the delegate.
    delegate?.printerDidRespond(data: data, error: nil)
  }

  func peripheral(
    _ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic,
    error: Error?
  ) {
    if let error = error {
      print(
        "Error changing notification state for \(characteristic.uuid): \(error.localizedDescription)"
      )
      return
    }

    if characteristic.isNotifying {
      print("Notifications enabled for \(characteristic.uuid)")
    } else {
      print("Notifications disabled for \(characteristic.uuid)")
    }
  }
}

// MARK: - Helper Extensions
extension Data {
  func hexEncodedString() -> String {
    return map { String(format: "%02hhx", $0) }.joined()
  }
}

extension UInt16 {
  var bigEndianData: Data {
    var be = self.bigEndian
    return Data(bytes: &be, count: MemoryLayout<UInt16>.size)
  }
}

// MARK: - Custom Error
enum NiimbotError: LocalizedError {
  case notConnected
  case characteristicNotFound
  case invalidArgument(String)
  case commandFailed(String)
  case imageProcessingFailed
  case responseTimeout  // TODO: Implement timeout logic
  case unexpectedResponse

  var errorDescription: String? {
    switch self {
    case .notConnected: return "Not connected to a printer."
    case .characteristicNotFound: return "Required Bluetooth characteristic not found."
    case .invalidArgument(let msg): return "Invalid argument: \(msg)"
    case .commandFailed(let msg): return "Command failed: \(msg)"
    case .imageProcessingFailed: return "Failed to process image."
    case .responseTimeout: return "Timeout waiting for printer response."
    case .unexpectedResponse: return "Received unexpected response from printer."

    }
  }
}
