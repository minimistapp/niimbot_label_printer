import CoreBluetooth
import CoreGraphics  // For CGImage later
import Foundation
import UIKit  // For UIImage later

// Placeholder UUIDs - Replace with actual Niimbot Service/Characteristic UUIDs
let niimbotServiceUUID = CBUUID(string: "000018F0-0000-1000-8000-00805F9B34FB")  // Example Service UUID
let niimbotWriteCharacteristicUUID = CBUUID(string: "00002AF1-0000-1000-8000-00805F9B34FB")  // Example Write Characteristic UUID
let niimbotNotifyCharacteristicUUID = CBUUID(string: "00002AF0-0000-1000-8000-00805F9B34FB")  // Example Notify Characteristic UUID

// Enum for Niimbot command codes (matching Python reference where possible)
enum RequestCode: UInt8 {
  case getInfo = 0x40  // 64
  case getRfid = 0x1A  // 26
  case heartbeat = 0xDC  // 220
  case setLabelType = 0x23  // 35
  case setLabelDensity = 0x21  // 33
  case startPrint = 0x01  // 1
  case endPrint = 0xF3  // 243
  case startPagePrint = 0x03  // 3
  case endPagePrint = 0xE3  // 227
  case allowPrintClear = 0x20  // 32 - Note: Commented out in Python ref for B21
  case setDimension = 0x13  // 19
  case setQuantity = 0x15  // 21 - Note: Commented out in Python ref for B21
  case getPrintStatus = 0xA3  // 163
  case printImageData = 0x85  // Custom type for image data, not a request expecting response
  // Add other codes if needed
}

// Enum for Info keys (matching Python reference)
enum InfoKey: UInt8 {
  case density = 1
  case printSpeed = 2
  case labelType = 3
  case languageType = 6
  case autoShutdownTime = 7
  case deviceType = 8
  case softVersion = 9
  case battery = 10
  case deviceSerial = 11
  case hardVersion = 12
}

// Basic struct for parsing Niimbot packets
struct NiimbotPacket {
  let type: UInt8
  let data: Data

  // Basic validation based on Python ref
  static func fromBytes(data: Data) -> NiimbotPacket? {
    guard data.count >= 7 else { return nil }  // Min length: header(2)+type(1)+len(1)+checksum(1)+footer(2)
    guard data.starts(with: [0x55, 0x55]) else { return nil }  // Check header
    guard data.suffix(2) == Data([0xAA, 0xAA]) else { return nil }  // Check footer

    let type = data[2]
    let len = Int(data[3])
    let expectedPacketLength = len + 7

    guard data.count == expectedPacketLength else { return nil }  // Check full length

    let payload = data.subdata(in: 4..<(4 + len))
    let checksumByte = data[4 + len]

    // Verify checksum
    var calculatedChecksum = Int32(type) ^ Int32(len)
    payload.forEach { calculatedChecksum ^= Int32($0) }
    guard checksumByte == UInt8(calculatedChecksum & 0xFF) else { return nil }  // Checksum mismatch

    return NiimbotPacket(type: type, data: payload)
  }
}

protocol NiimbotPrinterDelegate: AnyObject {
  func printerDidRespond(data: Data?, error: Error?)
  func printerDidSend(error: Error?)
  // Add other delegate methods as needed for state changes, etc.
}

// MARK: - Command Queue Types
private struct QueuedCommand {
  let id = UUID()  // For potential future debugging/cancellation
  let requestCode: RequestCode
  let data: Data
  let responseOffset: Int
  let continuation: CheckedContinuation<Data, Error>
  var timeoutTask: Task<Void, Never>?
}

// MARK: - Printer Actor

actor NiimbotPrinter {

  private var peripheral: CBPeripheral?
  private var writeCharacteristic: CBCharacteristic?
  private var notifyCharacteristic: CBCharacteristic?

  // Logger instance - non-optional, injected
  private let logger: PluginLogger

  // State for managing command responses - Managed by Command Queue
  private var commandQueue: [QueuedCommand] = []
  private var isProcessingCommand: Bool = false
  private var currentCommand: QueuedCommand?  // Track the command being actively processed
  private let responseTimeoutSeconds: Double = 5.0  // Timeout duration

  weak var delegate: NiimbotPrinterDelegate?

  // MARK: - Initialization & Setup
  init(peripheral: CBPeripheral, logger: PluginLogger) {
    self.peripheral = peripheral
    self.logger = logger
    logger.log("NiimbotPrinter Actor initialized for peripheral \(peripheral.identifier).")
    // Delegate setting and service discovery are handled externally by NiimbotPlugin
  }

  // Call this externally after discovering characteristics
  func setCharacteristics(write: CBCharacteristic, notify: CBCharacteristic) {
    logger.log("NiimbotPrinter Actor: Setting characteristics")
    self.writeCharacteristic = write
    self.notifyCharacteristic = notify
    // TODO: Consider enabling notifications here if not done elsewhere?
    // peripheral?.setNotifyValue(true, for: notify)
  }

  // MARK: - Public Command Methods (Enqueueing)

  func setLabelDensity(_ n: Int) async throws -> Bool {
    guard (1...5).contains(n) else {
      throw NiimbotError.invalidArgument("Density must be between 1 and 5")
    }
    let responseData = try await enqueueCommand(
      requestCode: .setLabelDensity, data: Data([UInt8(n)]), responseOffset: 16)
    guard !responseData.isEmpty else {
      throw NiimbotError.parsingFailed(
        operation: "setLabelDensity", reason: "Empty data in response", data: responseData)
    }
    return responseData[0] != 0
  }

  func setLabelType(_ n: Int) async throws -> Bool {
    guard (1...3).contains(n) else {
      throw NiimbotError.invalidArgument("Label type must be between 1 and 3")
    }
    let responseData = try await enqueueCommand(
      requestCode: .setLabelType, data: Data([UInt8(n)]), responseOffset: 16)
    guard !responseData.isEmpty else {
      throw NiimbotError.parsingFailed(
        operation: "setLabelType", reason: "Empty data in response", data: responseData)
    }
    return responseData[0] != 0
  }

  func startPrint() async throws -> Bool {
    let responseData = try await enqueueCommand(
      requestCode: .startPrint, data: Data([1]), responseOffset: 16)  // Assume default offset
    guard !responseData.isEmpty else {
      throw NiimbotError.parsingFailed(
        operation: "startPrint", reason: "Empty data in response", data: responseData)
    }
    return responseData[0] != 0  // Check first byte based on Python ref
  }

  func endPrint() async throws -> Bool {
    let responseData = try await enqueueCommand(requestCode: .endPrint, data: Data([1]))  // Assume default offset
    guard !responseData.isEmpty else {
      throw NiimbotError.parsingFailed(
        operation: "endPrint", reason: "Empty data in response", data: responseData)
    }
    return responseData[0] != 0
  }

  func startPagePrint() async throws -> Bool {
    let responseData = try await enqueueCommand(requestCode: .startPagePrint, data: Data([1]))  // Assume default offset
    guard !responseData.isEmpty else {
      throw NiimbotError.parsingFailed(
        operation: "startPagePrint", reason: "Empty data in response", data: responseData)
    }
    return responseData[0] != 0
  }

  func endPagePrint() async throws -> Bool {
    logger.log("Queueing endPagePrint (0xE3)...")
    let responseData = try await enqueueCommand(requestCode: .endPagePrint, data: Data([1]))  // Assume default offset
    logger.log("endPagePrint command completed.")
    guard !responseData.isEmpty else {
      throw NiimbotError.parsingFailed(
        operation: "endPagePrint", reason: "Empty data in response", data: responseData)
    }
    return responseData[0] != 0
  }

  func allowPrintClear() async throws -> Bool {
    logger.log(
      "Warning: allowPrintClear might not be supported/needed on all models.", level: "warn")
    let responseData = try await enqueueCommand(
      requestCode: .allowPrintClear, data: Data([1]), responseOffset: 16)
    guard !responseData.isEmpty else {
      throw NiimbotError.parsingFailed(
        operation: "allowPrintClear", reason: "Empty data in response", data: responseData)
    }
    return responseData[0] != 0
  }

  func setDimension(width: Int, height: Int) async throws -> Bool {
    var data = Data()
    data.append(UInt16(width).bigEndianData)
    data.append(UInt16(height).bigEndianData)
    let responseData = try await enqueueCommand(requestCode: .setDimension, data: data)  // Assume default offset
    guard !responseData.isEmpty else {
      throw NiimbotError.parsingFailed(
        operation: "setDimension", reason: "Empty data in response", data: responseData)
    }
    return responseData[0] != 0
  }

  func setQuantity(_ n: Int) async throws -> Bool {
    logger.log("Warning: setQuantity might not be supported/needed on all models.", level: "warn")
    let data = UInt16(n).bigEndianData
    let responseData = try await enqueueCommand(requestCode: .setQuantity, data: data)  // Assume default offset
    guard !responseData.isEmpty else {
      throw NiimbotError.parsingFailed(
        operation: "setQuantity", reason: "Empty data in response", data: responseData)
    }
    return responseData[0] != 0
  }

  func getPrintStatus() async throws -> [String: Int] {
    let responseData = try await enqueueCommand(
      requestCode: .getPrintStatus, data: Data([1]), responseOffset: 16)
    let op = "getPrintStatus"
    guard responseData.count >= 4 else {
      throw NiimbotError.parsingFailed(
        operation: op, reason: "Expected at least 4 bytes, got \(responseData.count)",
        data: responseData)
    }
    let page = UInt16(
      bigEndian: responseData.subdata(in: 0..<2).withUnsafeBytes { $0.load(as: UInt16.self) })
    let progress1 = Int(responseData[2])
    let progress2 = Int(responseData[3])
    return ["page": Int(page), "progress1": progress1, "progress2": progress2]
  }

  func getInfo(key: InfoKey) async throws -> Any {
    // Use explicit offset based on Python ref
    let responseData = try await enqueueCommand(
      requestCode: .getInfo, data: Data([key.rawValue]), responseOffset: Int(key.rawValue) + 1)
    let op = "getInfo(key: \(key))"
    switch key {
    case .deviceSerial:
      guard responseData.count > 0 else {  // Check if data is present at all
        throw NiimbotError.parsingFailed(
          operation: op, reason: "Expected non-empty data for serial", data: responseData)
      }
      return responseData.hexEncodedString()
    case .softVersion, .hardVersion:
      guard responseData.count >= 4 else {
        throw NiimbotError.parsingFailed(
          operation: op, reason: "Expected 4 bytes for version, got \(responseData.count)",
          data: responseData)
      }
      let value = Int32(bigEndian: responseData.withUnsafeBytes { $0.load(as: Int32.self) })
      return Double(value) / 100.0
    default:
      guard responseData.count >= 4 else {
        throw NiimbotError.parsingFailed(
          operation: op, reason: "Expected 4 bytes for key \(key), got \(responseData.count)",
          data: responseData)
      }
      let value = Int32(bigEndian: responseData.withUnsafeBytes { $0.load(as: Int32.self) })
      return Int(value)
    }
  }

  func getRfid() async throws -> [String: Any]? {
    let responseData = try await enqueueCommand(requestCode: .getRfid, data: Data([1]))  // Assume default offset 16
    let op = "getRfid"
    guard !responseData.isEmpty else {
      throw NiimbotError.parsingFailed(
        operation: op, reason: "Received empty data", data: responseData)
    }
    if responseData[0] == 0 {
      return nil  // Indicates no RFID tag detected
    }
    var idx = 0
    let minLengthBeforeUuid = 8
    guard responseData.count >= minLengthBeforeUuid else {
      throw NiimbotError.parsingFailed(
        operation: op,
        reason: "UUID: Expected at least \(minLengthBeforeUuid) bytes, got \(responseData.count)",
        data: responseData)
    }
    let uuid = responseData.subdata(in: idx..<(idx + 8)).hexEncodedString()
    idx += 8
    guard responseData.count > idx else {
      throw NiimbotError.parsingFailed(
        operation: op, reason: "barcodeLen: Index out of bounds (\(idx))", data: responseData)
    }
    let barcodeLen = Int(responseData[idx])
    idx += 1
    guard responseData.count >= idx + barcodeLen else {
      throw NiimbotError.parsingFailed(
        operation: op,
        reason: "barcode: Expected \(barcodeLen) bytes, only \(responseData.count - idx) available",
        data: responseData)
    }
    let barcode =
      String(data: responseData.subdata(in: idx..<(idx + barcodeLen)), encoding: .utf8) ?? ""
    idx += barcodeLen
    guard responseData.count > idx else {
      throw NiimbotError.parsingFailed(
        operation: op, reason: "serialLen: Index out of bounds (\(idx))", data: responseData)
    }
    let serialLen = Int(responseData[idx])
    idx += 1
    guard responseData.count >= idx + serialLen else {
      throw NiimbotError.parsingFailed(
        operation: op,
        reason: "serial: Expected \(serialLen) bytes, only \(responseData.count - idx) available",
        data: responseData)
    }
    let serial =
      String(data: responseData.subdata(in: idx..<(idx + serialLen)), encoding: .utf8) ?? ""
    idx += serialLen
    let minLengthForFooter = 5
    guard responseData.count >= idx + minLengthForFooter else {
      throw NiimbotError.parsingFailed(
        operation: op,
        reason:
          "length/type info: Expected \(minLengthForFooter) bytes, only \(responseData.count - idx) available",
        data: responseData)
    }
    let totalLen = UInt16(
      bigEndian: responseData.subdata(in: idx..<(idx + 2)).withUnsafeBytes {
        $0.load(as: UInt16.self)
      })
    idx += 2
    let usedLen = UInt16(
      bigEndian: responseData.subdata(in: idx..<(idx + 2)).withUnsafeBytes {
        $0.load(as: UInt16.self)
      })
    idx += 2
    let type = Int(responseData[idx])
    return [
      "uuid": uuid,
      "barcode": barcode,
      "serial": serial,
      "used_len": Int(usedLen),
      "total_len": Int(totalLen),
      "type": type,
    ]
  }

  func heartbeat() async throws -> [String: Int?] {
    let responseData = try await enqueueCommand(requestCode: .heartbeat, data: Data([1]))  // Assume default offset 16
    let op = "heartbeat"
    var closingState: Int? = nil
    var powerLevel: Int? = nil
    var paperState: Int? = nil
    var rfidReadState: Int? = nil
    guard responseData.count >= 9 else {
      throw NiimbotError.parsingFailed(
        operation: op,
        reason: "Expected at least 9 bytes for any known format, got \(responseData.count)",
        data: responseData)
    }
    switch responseData.count {
    case 20:
      guard responseData.count >= 20 else {
        throw NiimbotError.parsingFailed(
          operation: op, reason: "Index out of bounds (expected 20)", data: responseData)
      }
      paperState = Int(responseData[18])
      rfidReadState = Int(responseData[19])
    case 13:
      guard responseData.count >= 13 else {
        throw NiimbotError.parsingFailed(
          operation: op, reason: "Index out of bounds (expected 13)", data: responseData)
      }
      closingState = Int(responseData[9])
      powerLevel = Int(responseData[10])
      paperState = Int(responseData[11])
      rfidReadState = Int(responseData[12])
    case 19:
      guard responseData.count >= 19 else {
        throw NiimbotError.parsingFailed(
          operation: op, reason: "Index out of bounds (expected 19)", data: responseData)
      }
      closingState = Int(responseData[15])
      powerLevel = Int(responseData[16])
      paperState = Int(responseData[17])
      rfidReadState = Int(responseData[18])
    case 10:
      guard responseData.count >= 10 else {
        throw NiimbotError.parsingFailed(
          operation: op, reason: "Index out of bounds (expected 10)", data: responseData)
      }
      closingState = Int(responseData[8])
      powerLevel = Int(responseData[9])
      rfidReadState = Int(responseData[8])
    case 9:
      guard responseData.count >= 9 else {
        throw NiimbotError.parsingFailed(
          operation: op, reason: "Index out of bounds (expected 9)", data: responseData)
      }
      closingState = Int(responseData[8])
    default:
      throw NiimbotError.parsingFailed(
        operation: op, reason: "Unexpected data length \(responseData.count)", data: responseData)
    }
    return [
      "closing_state": closingState,
      "power_level": powerLevel,
      "paper_state": paperState,
      "rfid_read_state": rfidReadState,
    ]
  }

  // Special case for printBitmap as it involves multiple packets
  func printBitmap(
    _ bitmap: UIImage, density: Int = 3, labelType: Int = 1, quantity: Int = 1,
    rotate: Bool = false, invertColor: Bool = false
  ) async throws {
    // Enqueue the entire print sequence as a single conceptual operation?
    // Or handle setup commands individually first?
    // Let's enqueue setup commands first, then handle image data sending.

    logger.log("NiimbotPrinter Actor: Queueing printBitmap sequence...")

    // Enqueue setup commands - they will run sequentially due to the queue
    _ = try await setLabelDensity(density)
    _ = try await setLabelType(labelType)
    _ = try await startPrint()
    _ = try await startPagePrint()

    // Process image and set dimensions
    let imageToPrint = processImage(bitmap, rotate: rotate, invertColor: invertColor)
    guard let cgImage = imageToPrint.cgImage else {
      throw NiimbotError.imageProcessingFailed
    }
    let imageWidth = cgImage.width
    let imageHeight = cgImage.height
    _ = try await setDimension(width: imageWidth, height: imageHeight)
    _ = try await setQuantity(quantity)

    // --- Send Image Data (Not part of standard request/response queue) ---
    // Image data packets don't expect individual responses matching the request code
    // We send them using sendRawCommand which uses writeWithoutResponse
    logger.log("NiimbotPrinter Actor: Sending image data (\(imageWidth)x\(imageHeight))...")
    let imagePackets = encodeImage(imageToPrint)
    for packet in imagePackets {
      await sendRawCommand(packet: packet)
    }
    logger.log("NiimbotPrinter Actor: Finished sending image packets.")
    // --- End Image Data ---

    // Enqueue final commands
    _ = try await endPagePrint()  // This expects a response

    // Poll status - this needs to be handled carefully with the actor queue
    // Option 1: Enqueue getPrintStatus repeatedly? Might block queue.
    // Option 2: Perform polling outside the strict command queue?
    // Let's try Option 2 for now, but it breaks strict sequencing guarantee.
    logger.log("NiimbotPrinter Actor: Polling print status (outside strict queue)...")
    try await pollPrintStatus(expectedQuantity: quantity)

    _ = try await endPrint()  // Enqueue final command
    logger.log("NiimbotPrinter Actor: Print sequence fully queued/completed.")
  }

  // Helper for polling status (non-queued)
  private func pollPrintStatus(expectedQuantity: Int) async throws {
    let maxPollingAttempts = 30
    var pollingAttempts = 0
    var printedPages = 0

    while pollingAttempts < maxPollingAttempts {
      pollingAttempts += 1
      logger.log("Polling attempt \(pollingAttempts)/\(maxPollingAttempts)...")
      // We need to call the *public* getPrintStatus which uses the queue
      do {
        let status = try await getPrintStatus()  // This will now queue correctly
        printedPages = status["page"] ?? 0
        logger.log("Current status: page=\(printedPages)/\(expectedQuantity)")
        pollingAttempts += 1  // Increment only on successful status check?
        if printedPages >= expectedQuantity {
          logger.log("Polling: Printing completed.")
          return  // Success
        }
      } catch let error {
        // Use if-case to check for specific error type
        if case NiimbotError.responseTimeout = error {
          logger.log("Warning: Timeout polling print status, retrying...", level: "warn")
          // No increment on timeout? Or increment anyway?
          // Let's increment to avoid infinite loops on persistent timeouts.
          pollingAttempts += 1
        } else {
          logger.log(
            "Error polling print status: \(error.localizedDescription). Aborting wait.",
            level: "error")
          throw error  // Rethrow other errors
        }
      }

      try await Task.sleep(nanoseconds: 500_000_000)  // 0.5 second delay
    }

    // If loop finishes without completion
    logger.log(
      "Warning: Polling finished, but reported pages (\(printedPages)) < requested quantity (\(expectedQuantity)).",
      level: "warn"
    )
    // Consider throwing an error here if strict confirmation is needed
    // throw NiimbotError.commandFailed("Print status polling did not confirm completion")
  }

  // MARK: - Command Queue Logic

  // Public method to enqueue commands and return result via continuation
  private func enqueueCommand(
    requestCode: RequestCode, data: Data = Data(), responseOffset: Int = 16
  ) async throws -> Data {
    return try await withCheckedThrowingContinuation { continuation in
      let command = QueuedCommand(
        requestCode: requestCode,
        data: data,
        responseOffset: responseOffset,
        continuation: continuation
          // timeoutTask is added during processing
      )
      // Add to queue and trigger processing
      commandQueue.append(command)
      logger.log("Command \(requestCode) enqueued. Queue size: \(commandQueue.count)")
      Task { await self._processNextCommand() }  // Trigger processing asynchronously
    }
  }

  private func _processNextCommand() {
    guard !isProcessingCommand else {
      logger.log(
        "Queue: Already processing command \(currentCommand?.requestCode.rawValue ?? 0), skipping.",
        level: "debug")
      return  // Already processing
    }
    guard !commandQueue.isEmpty else {
      logger.log("Queue: Empty, nothing to process.", level: "debug")
      isProcessingCommand = false  // Ensure flag is false if queue is empty
      return  // No commands to process
    }

    isProcessingCommand = true
    var commandToProcess = commandQueue.removeFirst()
    currentCommand = commandToProcess  // Track current command
    logger.log(
      "Queue: Dequeuing command \(commandToProcess.requestCode). Remaining: \(commandQueue.count)")

    guard let peripheral = peripheral, let characteristic = writeCharacteristic else {
      logger.log(
        "Error: Peripheral or characteristic unavailable for processing command \(commandToProcess.requestCode)",
        level: "error")
      commandToProcess.continuation.resume(throwing: NiimbotError.notConnected)
      _finishProcessingCommand(errorOccurred: true)
      return
    }

    let packet = createPacket(type: commandToProcess.requestCode, data: commandToProcess.data)
    let expectedResponseCode =
      commandToProcess.requestCode.rawValue + UInt8(commandToProcess.responseOffset)
    logger.log(
      "Queue: Sending command: \(commandToProcess.requestCode) (0x\(String(commandToProcess.requestCode.rawValue, radix: 16))), expecting response: 0x\(String(expectedResponseCode, radix: 16))"
    )

    // Start timeout task for this specific command
    commandToProcess.timeoutTask = Task {
      await Task.sleep(UInt64(responseTimeoutSeconds * 1_000_000_000))
      if Task.isCancelled { return }  // Task cancelled means response arrived or another error occurred

      // Timeout occurred - check if it's still for the *current* command being processed
      if self.currentCommand?.id == commandToProcess.id {
        logger.log(
          "Error: Timeout waiting for response 0x\(String(expectedResponseCode, radix: 16)) for command \(commandToProcess.requestCode)",
          level: "error")
        commandToProcess.continuation.resume(throwing: NiimbotError.responseTimeout)
        self._finishProcessingCommand(errorOccurred: true)
      } else {
        logger.log(
          "Warning: Timeout fired for command \(commandToProcess.requestCode), but it was no longer the current command. Ignoring timeout.",
          level: "warn")
      }
    }

    // Assign the task back to the command struct (needed for cancellation)
    currentCommand?.timeoutTask = commandToProcess.timeoutTask

    // Send the command
    peripheral.writeValue(packet, for: characteristic, type: .withResponse)
    // Note: We rely on peripheral:didWriteValueFor: *and* peripheral:didUpdateValueFor: (via handleResponse)
    // to know when the operation is truly complete. Using .withResponse might give early ack.
    // If issues arise, consider if write confirmation needs separate handling.
  }

  // Helper to clean up after a command finishes (success, error, or timeout)
  private func _finishProcessingCommand(errorOccurred: Bool) {
    logger.log(
      "Queue: Finishing command \(currentCommand?.requestCode.rawValue ?? 0). Error: \(errorOccurred)",
      level: "debug")
    currentCommand?.timeoutTask?.cancel()  // Cancel timeout if not already fired
    currentCommand = nil
    isProcessingCommand = false
    Task { await self._processNextCommand() }  // Try to process the next one
  }

  // MARK: - External Delegate Call Handlers
  // Called by NiimbotPlugin's delegate methods

  nonisolated func handleResponseFromDelegate(data: Data?, error: Error?) {
    // Run the actual handling within the actor's context
    Task { await self.handleResponse(data: data, error: error) }
  }

  nonisolated func handleWriteConfirmationFromDelegate(error: Error?) {
    Task { await self.handleWriteConfirmation(error: error) }
  }

  // MARK: - Internal State Logic (Actor-Isolated)

  private func handleResponse(data: Data?, error: Error?) {
    guard let commandInProgress = currentCommand else {
      logger.log(
        "Warning: Received response data/error but no command was being processed. Data: \(data?.hexEncodedString() ?? "nil"), Error: \(error?.localizedDescription ?? "nil")",
        level: "warn")
      return
    }

    logger.log(
      "Queue: Handling response for command \(commandInProgress.requestCode). Error: \(error != nil)",
      level: "debug")

    // Cancel the timeout task as we received a response or write error
    // commandInProgress.timeoutTask?.cancel() // This is now done in _finishProcessingCommand

    if let error = error {
      logger.log(
        "Error received in response handler: \(error.localizedDescription)", level: "error")
      commandInProgress.continuation.resume(throwing: error)
      _finishProcessingCommand(errorOccurred: true)
      return
    }

    guard let responseData = data else {
      logger.log("Error: Response handler received nil data and nil error.", level: "error")
      commandInProgress.continuation.resume(
        throwing: NiimbotError.parsingFailed(
          operation: "handleResponse", reason: "Received nil data"))
      _finishProcessingCommand(errorOccurred: true)
      return
    }

    guard let responsePacket = NiimbotPacket.fromBytes(data: responseData) else {
      logger.log(
        "Error: Failed to parse received data into NiimbotPacket. Data: \(responseData.hexEncodedString())",
        level: "error")
      commandInProgress.continuation.resume(
        throwing: NiimbotError.parsingFailed(
          operation: "handleResponse", reason: "Failed to parse packet structure/checksum",
          data: responseData))
      _finishProcessingCommand(errorOccurred: true)
      return
    }

    let expectedResponseCode =
      commandInProgress.requestCode.rawValue + UInt8(commandInProgress.responseOffset)
    logger.log(
      "Received response packet: Type=0x\(String(responsePacket.type, radix: 16)), Expected=0x\(String(expectedResponseCode, radix: 16))",
      level: "debug")

    if responsePacket.type == expectedResponseCode {
      commandInProgress.continuation.resume(returning: responsePacket.data)
      _finishProcessingCommand(errorOccurred: false)
    } else if responsePacket.type == 219 {  // Specific error code 0xDB
      logger.log("Error: Printer returned specific error code 219 (0xDB)", level: "error")
      commandInProgress.continuation.resume(
        throwing: NiimbotError.commandFailed("Printer error code 0xDB"))
      _finishProcessingCommand(errorOccurred: true)
    } else if responsePacket.type == 0 {  // Another potential error/status?
      logger.log("Warning: Received packet type 0", level: "warn")
      commandInProgress.continuation.resume(
        throwing: NiimbotError.parsingFailed(
          operation: "handleResponse", reason: "Received packet type 0", data: responseData))
      _finishProcessingCommand(errorOccurred: true)
    } else {
      logger.log(
        "Error: Received packet type 0x\(String(responsePacket.type, radix: 16)) did not match expected 0x\(String(expectedResponseCode, radix: 16))",
        level: "error")
      commandInProgress.continuation.resume(
        throwing: NiimbotError.parsingFailed(
          operation: "handleResponse",
          reason: "Type mismatch: Got \(responsePacket.type), expected \(expectedResponseCode)",
          data: responseData))
      _finishProcessingCommand(errorOccurred: true)
    }
  }

  private func handleWriteConfirmation(error: Error?) {
    // This is called when peripheral:didWriteValueFor: completes.
    // For commands sent via the queue (using .withResponse), the response
    // via didUpdateValueFor (calling handleResponse) is the primary signal.
    // This confirmation might be useful if we implement flow control for
    // .withoutResponse writes (like image data) in the future.
    if let error = error {
      logger.log(
        "Warning: Received write error confirmation: \(error.localizedDescription)", level: "warn")
      // Should we fail the current command here too?
      if let commandInProgress = currentCommand {
        // Maybe only fail if the primary response hasn't arrived yet?
        // This needs careful consideration of CoreBluetooth timing.
        logger.log(
          "Error during write confirmation for command \(commandInProgress.requestCode). Failing command.",
          level: "error")
        commandInProgress.continuation.resume(throwing: error)
        _finishProcessingCommand(errorOccurred: true)
      }
    } else {
      // Write acknowledged by BLE stack. Doesn't mean command succeeded.
      logger.log("Write acknowledged for characteristic.", level: "debug")
    }
  }

  // MARK: - Image Processing & Helpers (Actor-Isolated)

  private func processImage(_ image: UIImage, rotate: Bool, invertColor: Bool) -> UIImage {
    var processedImage = image
    if rotate {
      processedImage = rotateImage(image: processedImage, degrees: 90) ?? processedImage
    }
    if invertColor {
      processedImage = invertImageColors(image: processedImage) ?? processedImage
    }
    guard let cgImage = processedImage.cgImage else { return image }
    guard let finalImage = convertToARGB(cgImage: cgImage) else { return image }
    return finalImage
  }

  private func convertToARGB(cgImage: CGImage) -> UIImage? {
    let width = cgImage.width
    let height = cgImage.height
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bytesPerRow = width * 4
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue).union(
      .byteOrder32Big)
    guard
      let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow,
        space: colorSpace, bitmapInfo: bitmapInfo.rawValue)
    else {
      logger.log("Error: Could not create CGContext for ARGB conversion", level: "error")
      return nil
    }
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
    guard let outputCGImage = context.makeImage() else {
      logger.log("Error: Could not make image from context", level: "error")
      return nil
    }
    return UIImage(cgImage: outputCGImage)
  }

  private func rotateImage(image: UIImage, degrees: CGFloat) -> UIImage? {
    guard let cgImage = image.cgImage else { return nil }
    let rotatedSize = CGRect(origin: .zero, size: image.size).applying(
      CGAffineTransform(rotationAngle: degrees * .pi / 180)
    ).integral.size
    UIGraphicsBeginImageContextWithOptions(rotatedSize, false, image.scale)
    guard let context = UIGraphicsGetCurrentContext() else { return nil }
    context.translateBy(x: rotatedSize.width / 2, y: rotatedSize.height / 2)
    context.rotate(by: degrees * .pi / 180)
    context.scaleBy(x: 1.0, y: -1.0)
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
    guard let pixelData = cgImage.dataProvider?.data, let dataPtr = CFDataGetBytePtr(pixelData)
    else {
      logger.log("Error: Could not get pixel data", level: "error")
      return []
    }
    let bytesPerPixel = cgImage.bitsPerPixel / 8
    let bytesPerRow = cgImage.bytesPerRow
    var packets: [Data] = []
    logger.log(
      "Encoding image: \(width)x\(height), bpp: \(bytesPerPixel), stride: \(bytesPerRow)",
      level: "debug")
    for y in 0..<height {
      var lineData = Data(repeating: 0, count: (width + 7) / 8)
      for x in 0..<width {
        let pixelOffset = y * bytesPerRow + x * bytesPerPixel
        let alphaComponent: UInt8
        let alphaInfo = cgImage.alphaInfo
        if alphaInfo == .premultipliedLast || alphaInfo == .last {
          alphaComponent = dataPtr[pixelOffset + 3]
        } else if alphaInfo == .premultipliedFirst || alphaInfo == .first {
          alphaComponent = dataPtr[pixelOffset]
        } else {
          alphaComponent = 255
        }
        let isPixelOn = alphaComponent > 128
        if isPixelOn {
          let byteIndex = x / 8
          let bitIndex = 7 - (x % 8)
          lineData[byteIndex] |= (1 << bitIndex)
        }
      }
      var packetPayload = Data()
      packetPayload.append(UInt16(y).bigEndianData)
      packetPayload.append(contentsOf: [0x00, 0x00, 0x00])
      packetPayload.append(0x01)
      packetPayload.append(lineData)
      let linePacket = createPacket(type: .printImageData, data: packetPayload)
      packets.append(linePacket)
    }
    return packets
  }

  // MARK: - Disconnect & Cleanup
  // Needs to be callable externally, potentially nonisolated
  func cleanup() {
    logger.log("NiimbotPrinter Actor: Cleaning up...")
    // Cancel all pending commands
    for command in commandQueue {
      command.timeoutTask?.cancel()
      command.continuation.resume(
        throwing: NiimbotError.commandFailed("Printer disconnected or cleaned up"))
    }
    commandQueue.removeAll()

    // Cancel the currently processing command if any
    if let current = currentCommand {
      current.timeoutTask?.cancel()
      current.continuation.resume(
        throwing: NiimbotError.commandFailed("Printer disconnected or cleaned up"))
      currentCommand = nil
    }

    isProcessingCommand = false
    peripheral = nil
    writeCharacteristic = nil
    notifyCharacteristic = nil
    logger.log("NiimbotPrinter Actor cleaned up.")
  }

  // Define sendRawCommand within the actor
  private func sendRawCommand(packet: Data) {  // Not async needed if just writing
    guard let peripheral = peripheral, let characteristic = writeCharacteristic else {
      logger.log(
        "Error: Cannot send raw command, peripheral or characteristic unavailable.", level: "error")
      return
    }
    // logger.log("Sending raw packet: \(packet.hexEncodedString())", level: "debug") // Optional verbose log
    peripheral.writeValue(packet, for: characteristic, type: .withoutResponse)
    // Note: No explicit delay here now. Rely on BLE stack backpressure or implement
    // peripheralIsReady(toSendWriteWithoutResponse:) handling if needed.
  }

  // Define createPacket within the actor
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
  // Overload for using RequestCode enum
  private func createPacket(type: RequestCode, data: Data) -> Data {
    return createPacket(type: type.rawValue, data: data)
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
  case parsingFailed(operation: String, reason: String, data: Data? = nil)
  case commandInProgress

  var errorDescription: String? {
    switch self {
    case .notConnected: return "Not connected to a printer."
    case .characteristicNotFound: return "Required Bluetooth characteristic not found."
    case .invalidArgument(let msg): return "Invalid argument: \(msg)"
    case .commandFailed(let msg): return "Command failed: \(msg)"
    case .imageProcessingFailed: return "Failed to process image."
    case .responseTimeout: return "Timeout waiting for printer response."
    case .parsingFailed(let op, let reason, let data):
      return "Parsing failed: \(op), \(reason), \(data?.hexEncodedString() ?? "nil")"
    case .commandInProgress: return "Command already in progress."
    }
  }
}
