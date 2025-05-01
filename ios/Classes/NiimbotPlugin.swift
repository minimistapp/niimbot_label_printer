import CoreBluetooth
import Flutter
import UIKit

public class NiimbotPlugin: NSObject, FlutterPlugin, CBCentralManagerDelegate,
  NiimbotPrinterDelegate, FlutterStreamHandler
{
  private var centralManager: CBCentralManager!
  private var discoveredPeripherals: [UUID: CBPeripheral] = [:]
  private var connectedPeripheral: CBPeripheral?
  private var niimbotPrinter: NiimbotPrinter?

  // Store Flutter results for async operations
  private var pendingConnectResult: FlutterResult?
  private var pendingScanResult: FlutterResult?
  private var pendingSendResult: FlutterResult?

  // Method channel & Event Channel
  private var channel: FlutterMethodChannel!
  private var eventChannel: FlutterEventChannel!  // Add event channel
  private var eventSink: FlutterEventSink?  // Add event sink

  // --- Logging Helper ---
  private func log(_ message: String, level: String = "info") {
    print("NiimbotPlugin (\(level)): \(message)")
    let logData = ["level": level, "message": message]
    sendEvent(type: .log, data: logData)
  }

  // --- Event Sending Helper ---
  private func sendEvent(type: PluginEventType, data: Any?) {
    guard let sink = eventSink else {
      print("WARN: EventSink is nil, cannot send event.")
      return
    }
    // EventChannel expects Any? so we send the dictionary directly.
    // The PluginEvent struct/toMap was primarily for organization/potential JSON use.
    let eventMap: [String: Any?] = [
      "type": type.rawValue,
      "data": data,  // Pass the data directly
    ]
    sink(eventMap)
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    print(">>>> NiimbotPlugin REGISTERING WITH REGISTRAR <<<<")
    let methodChannel = FlutterMethodChannel(
      name: "st.mnm.niimbot/printer", binaryMessenger: registrar.messenger())
    // Define Event Channel Name (ensure matches Dart constant)
    let eventChannel = FlutterEventChannel(
      name: "st.mnm.niimbot/printer_events", binaryMessenger: registrar.messenger())

    let instance = NiimbotPlugin()
    instance.channel = methodChannel  // Store the method channel

    // Set the stream handler for the event channel
    instance.eventChannel = eventChannel
    eventChannel.setStreamHandler(instance)  // `instance` conforms to FlutterStreamHandler

    // Initialize CBCentralManager here. The queue should ideally be a background queue.
    instance.centralManager = CBCentralManager(delegate: instance, queue: nil)  // Use nil for main queue or specify a background queue
    registrar.addMethodCallDelegate(instance, channel: methodChannel)

    // Initial log
    instance.log("Plugin registration complete.")
  }

  // MARK: - FlutterStreamHandler Methods

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    log("EventChannel: onListen called.")
    self.eventSink = events
    // Optionally send an initial state event
    sendBluetoothStateEvent()
    return nil  // Success
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    log("EventChannel: onCancel called.")
    self.eventSink = nil
    return nil  // Success
  }

  // MARK: - Method Call Handler
  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    log("Handling method call: \(call.method)")  // Use helper
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)

    case "isBluetoothPermissionGranted":
      let authorized: Bool
      let status: CBManagerAuthorization
      if #available(iOS 13.1, *) {
        status = CBCentralManager.authorization  // Use CBManagerAuthorization
      } else {
        // Fallback for older iOS versions if needed, though 13.1+ is common now
        status =
          CBPeripheralManager.authorizationStatus() == .authorized ? .allowedAlways : .denied  // Approximate
      }

      switch status {
      case .allowedAlways:
        authorized = true
      case .notDetermined:
        authorized = false  // Or handle asking for permission
        log("Bluetooth permission not determined.", level: "warn")
      case .restricted:
        authorized = false
        log("Bluetooth permission restricted.", level: "warn")
      case .denied:
        authorized = false
        log("Bluetooth permission denied.", level: "error")
      @unknown default:
        authorized = false
        log("Unknown Bluetooth authorization status: \(status.rawValue)", level: "error")
      }
      log("Bluetooth permission authorized: \(authorized)")
      result(authorized)

    case "isBluetoothEnabled":
      let enabled = centralManager.state == .poweredOn
      log("Bluetooth enabled: \(enabled)")  // Use helper
      result(enabled)

    case "isConnected":
      let connected = connectedPeripheral != nil && connectedPeripheral?.state == .connected
      log("Is Connected check: \(connected)")  // Use helper
      result(connected)

    case "getPairedDevices":  // iOS equivalent: Scan for nearby devices
      guard centralManager.state == .poweredOn else {
        let errorMsg = "Bluetooth is not enabled"
        log(errorMsg, level: "error")
        sendEvent(type: .error, data: ["code": "BLUETOOTH_DISABLED", "message": errorMsg])
        result(FlutterError(code: "BLUETOOTH_DISABLED", message: errorMsg, details: nil))
        return
      }
      log("Starting scan for peripherals...")  // Use helper
      pendingScanResult = result  // Store result callback
      discoveredPeripherals.removeAll()
      // Scan for peripherals advertising the Niimbot service UUID
      log("Central Manager State before scan: \(centralManager.state.rawValue)")  // Log state
      if centralManager.state == .poweredOn {
        centralManager.scanForPeripherals(
          withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])  // NEW: Scan for all devices, don't spam duplicates
        log("Called scanForPeripherals(withServices: nil)")  // Log call success
      } else {
        log("Skipping scan because Bluetooth is not powered on.", level: "warn")
      }
      // Set a timer to stop scanning after a few seconds
      // TODO: Implement a better timeout/stopScan mechanism
      DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
        self?.stopScanAndReturnResults()
      }

    case "connect":
      guard centralManager.state == .poweredOn else {
        let errorMsg = "Bluetooth is not enabled"
        log(errorMsg, level: "error")
        sendEvent(type: .error, data: ["code": "BLUETOOTH_DISABLED", "message": errorMsg])
        result(FlutterError(code: "BLUETOOTH_DISABLED", message: errorMsg, details: nil))
        return
      }

      // Expecting map like {'name': ..., 'address': ...} from Dart's device.toMap()
      guard let args = call.arguments as? [String: Any],
        let deviceIdentifierString = args["address"] as? String,  // Extract the 'address' key
        let deviceUUID = UUID(uuidString: deviceIdentifierString)
      else {
        let errorMsg = "Invalid arguments: Expected map with 'address' (UUID string)"
        log(errorMsg, level: "error")
        sendEvent(type: .error, data: ["code": "INVALID_ARGUMENT", "message": errorMsg])
        result(FlutterError(code: "INVALID_ARGUMENT", message: errorMsg, details: nil))
        return
      }

      log("Attempting to connect to peripheral with UUID: \(deviceUUID)")
      pendingConnectResult = result  // Store result callback
      sendEvent(
        type: .connectionState, data: ["status": "connecting", "deviceId": deviceUUID.uuidString])

      // Stop scanning before connecting
      if centralManager.isScanning {
        log("Stopping scan before connecting.")
        centralManager.stopScan()
      }

      // Try to retrieve the peripheral if known
      let knownPeripherals = centralManager.retrievePeripherals(withIdentifiers: [deviceUUID])
      if let peripheral = knownPeripherals.first {
        log("Found known peripheral. Connecting...")
        connectToPeripheral(peripheral)
      } else {
        // If not known (e.g., after app restart), try finding it in discovered list
        if let peripheral = discoveredPeripherals[deviceUUID] {
          log("Found peripheral in discovered list. Connecting...")
          connectToPeripheral(peripheral)
        } else {
          // Might need to scan first if the peripheral isn't known or discovered
          let errorMsg = "Peripheral not found. Scan first."
          log(errorMsg, level: "warn")
          sendEvent(
            type: .connectionState,
            data: ["status": "error", "deviceId": deviceUUID.uuidString, "message": errorMsg])
          pendingConnectResult?(
            FlutterError(code: "NOT_FOUND", message: errorMsg, details: nil))
          pendingConnectResult = nil
        }
      }

    case "send":
      guard let printer = niimbotPrinter, let peripheral = connectedPeripheral,
        peripheral.state == .connected
      else {
        let errorMsg = "Printer not connected"
        log(errorMsg, level: "error")
        sendEvent(type: .error, data: ["code": "NOT_CONNECTED", "message": errorMsg])
        result(FlutterError(code: "NOT_CONNECTED", message: errorMsg, details: nil))
        return
      }
      guard let args = call.arguments as? [String: Any],
        let bytesFlutter = args["bytes"] as? FlutterStandardTypedData,
        let width = args["width"] as? Int,
        let height = args["height"] as? Int
      else {
        let errorMsg = "Invalid arguments for send"
        log(errorMsg, level: "error")
        sendEvent(type: .error, data: ["code": "INVALID_ARGUMENT", "message": errorMsg])
        result(FlutterError(code: "INVALID_ARGUMENT", message: errorMsg, details: nil))
        return
      }

      let bytes = bytesFlutter.data
      let rotate = args["rotate"] as? Bool ?? false
      let invertColor = args["invertColor"] as? Bool ?? false
      let density = args["density"] as? Int ?? 3
      let labelType = args["labelType"] as? Int ?? 1

      log(
        "Received image data: \(width)x\(height), \(bytes.count) bytes. Density: \(density), LabelType: \(labelType), Rotate: \(rotate), Invert: \(invertColor)"
      )

      guard let image = createImageFromBytes(bytes: bytes, width: width, height: height) else {
        let errorMsg = "Could not create image from provided bytes"
        log(errorMsg, level: "error")
        sendEvent(type: .error, data: ["code": "IMAGE_CREATION_FAILED", "message": errorMsg])
        result(FlutterError(code: "IMAGE_CREATION_FAILED", message: errorMsg, details: nil))
        return
      }

      pendingSendResult = result  // Store result callback

      Task {
        do {
          log("Starting printBitmap task...")
          try await printer.printBitmap(
            image, density: density, labelType: labelType, quantity: 1, rotate: rotate,
            invertColor: invertColor)
          log("printBitmap task finished successfully.")
          // Send success event maybe?
          self.pendingSendResult?(true)
        } catch {
          let errorMsg = "Print failed: \(error.localizedDescription)"
          self.log(errorMsg, level: "error")
          self.sendEvent(
            type: .error,
            data: [
              "code": "PRINT_FAILED", "message": errorMsg, "details": error.localizedDescription,
            ])
          self.pendingSendResult?(
            FlutterError(code: "PRINT_FAILED", message: errorMsg, details: nil))
        }
        self.pendingSendResult = nil  // Clear callback
      }

    case "disconnect":
      if let peripheral = connectedPeripheral {
        log("Disconnecting from peripheral \(peripheral.identifier)")  // Use helper
        centralManager.cancelPeripheralConnection(peripheral)
        // Cleanup happens in didDisconnectPeripheral delegate method
        // Send disconnecting event immediately
        sendEvent(
          type: .connectionState,
          data: ["status": "disconnecting", "deviceId": peripheral.identifier.uuidString])
      } else {
        log("No peripheral connected to disconnect.")  // Use helper
      }
      result(true)  // Assume success, actual disconnect is async

    default:
      log("Method not implemented: \(call.method)", level: "warn")  // Use helper
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Scan Stop Helper
  private func stopScanAndReturnResults() {
    guard centralManager.isScanning else { return }  // Only stop if scanning

    log("Stopping scan...")
    centralManager.stopScan()

    if let resultCallback = pendingScanResult {
      log("Returning scan results.")
      let deviceList = discoveredPeripherals.values.map { p in
        return ["name": p.name ?? "Unknown", "address": p.identifier.uuidString]  // Return map
      }
      resultCallback(deviceList)
      pendingScanResult = nil  // Clear callback
    } else {
      log("Scan finished, but no pending result callback.", level: "warn")
    }
    // Send scan finished event?
    sendEvent(type: .scanResult, data: ["status": "finished"])
  }

  // MARK: - Helper Functions

  private func connectToPeripheral(_ peripheral: CBPeripheral) {
    // Disconnect from any currently connected peripheral first
    if let currentPeripheral = connectedPeripheral, currentPeripheral != peripheral {
      log(
        "Disconnecting from previous peripheral \(currentPeripheral.identifier) before connecting to \(peripheral.identifier)"
      )
      centralManager.cancelPeripheralConnection(currentPeripheral)
      // The actual cleanup and state update happens in didDisconnect delegate
    }

    log("Connecting to \(peripheral.identifier)...")
    // Don't set connectedPeripheral here, wait for didConnect
    centralManager.connect(peripheral, options: nil)
  }

  private func cleanupConnection(peripheralId: UUID? = nil, reason: String = "Unknown") {
    log("Cleaning up connection for \(peripheralId?.uuidString ?? "N/A"). Reason: \(reason)")

    // Only fully cleanup if it's the currently connected one or if no specific ID given
    if peripheralId == nil || connectedPeripheral?.identifier == peripheralId {
      if connectedPeripheral != nil {
        sendEvent(
          type: .connectionState,
          data: [
            "status": "disconnected", "deviceId": connectedPeripheral!.identifier.uuidString,
            "reason": reason,
          ])
      }
      connectedPeripheral?.delegate = nil
      // niimbotPrinter?.cleanup()  // Ensure NiimbotPrinter cleans up its resources << NEEDS AWAIT
      Task { await niimbotPrinter?.cleanup() }  // Wrap in Task
      niimbotPrinter = nil
      connectedPeripheral = nil  // Clear the main reference LAST
    } else {
      log(
        "Cleanup called for peripheral \(peripheralId?.uuidString ?? "N/A") but it wasn't the active connectedPeripheral (\(connectedPeripheral?.identifier.uuidString ?? "None")). Ignoring full cleanup.",
        level: "warn")
    }

    // Clear any pending results that depended on the connection, regardless of which peripheral it was for
    // It might be safer to check if the error is related to the specific peripheral before failing.
    if let connectResult = pendingConnectResult {
      let errorMsg = "Operation cancelled due to disconnection (Reason: \(reason))"
      log("Failing pending connect result: \(errorMsg)", level: "warn")
      // Check if the failed connection attempt was for the peripheral being cleaned up.
      // This requires storing the target UUID for the pendingConnectResult.
      // For now, we fail any pending connect.
      connectResult(FlutterError(code: "DISCONNECTED", message: errorMsg, details: nil))
      pendingConnectResult = nil
    }
    if let sendResult = pendingSendResult {
      let errorMsg = "Send operation cancelled due to disconnection (Reason: \(reason))"
      log("Failing pending send result: \(errorMsg)", level: "warn")
      sendResult(FlutterError(code: "DISCONNECTED", message: errorMsg, details: nil))
      pendingSendResult = nil
    }
    if let scanResult = pendingScanResult {
      let errorMsg = "Scan operation cancelled due to disconnection (Reason: \(reason))"
      log("Failing pending scan result: \(errorMsg)", level: "warn")
      scanResult(FlutterError(code: "DISCONNECTED", message: errorMsg, details: nil))
      pendingScanResult = nil
    }
  }

  private func createImageFromBytes(bytes: Data, width: Int, height: Int) -> UIImage? {
    log("Creating UIImage from \(bytes.count) bytes, \(width)x\(height)")
    let bitsPerComponent = 8
    let bitsPerPixel = 32  // Assuming ARGB_8888 from Flutter/Kotlin
    let bytesPerRow = width * (bitsPerPixel / 8)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    // Ensure the bitmap info matches ARGB_8888 format from Dart/Kotlin
    // CGBitmapInfo.byteOrder32Big corresponds to ARGB on big-endian systems,
    // but on little-endian iOS, it's BGRA. We need alpha last.
    // CGImageAlphaInfo.premultipliedLast indicates RGBA (or BGRA depending on byte order)
    // Let's explicitly use RGBA order (alpha last) as it's more common for CGImage.
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

    guard bytes.count >= height * bytesPerRow else {
      log(
        "Error: Provided data size (\(bytes.count)) is smaller than calculated required size (\(height * bytesPerRow)) for \(width)x\(height) image.",
        level: "error")
      return nil
    }

    guard let providerRef = CGDataProvider(data: bytes as CFData) else {
      log("Error: Could not create CGDataProvider", level: "error")
      return nil
    }

    guard
      let cgImage = CGImage(
        width: width,
        height: height,
        bitsPerComponent: bitsPerComponent,
        bitsPerPixel: bitsPerPixel,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: bitmapInfo,  // Use RGBA format
        provider: providerRef,
        decode: nil,
        shouldInterpolate: false,  // Use false for pixel data
        intent: .defaultIntent)
    else {
      log("Error: Could not create CGImage", level: "error")
      return nil
    }

    log("CGImage created successfully.")
    return UIImage(cgImage: cgImage)
  }

  // MARK: - CBCentralManagerDelegate

  // Helper to send Bluetooth state events
  private func sendBluetoothStateEvent() {
    let stateString: String
    switch centralManager.state {
    case .poweredOn: stateString = "poweredOn"
    case .poweredOff: stateString = "poweredOff"
    case .resetting: stateString = "resetting"
    case .unauthorized: stateString = "unauthorized"
    case .unknown: stateString = "unknown"
    case .unsupported: stateString = "unsupported"
    @unknown default: stateString = "unknown_default"
    }
    log("Bluetooth State Updated: \(stateString)")
    sendEvent(type: .bluetoothState, data: ["state": stateString])
  }

  public func centralManagerDidUpdateState(_ central: CBCentralManager) {
    sendBluetoothStateEvent()  // Send event

    if central.state != .poweredOn {
      cleanupConnection(reason: "Bluetooth state changed to \(central.state)")
      // Also stop scanning if it was active
      if centralManager.isScanning {
        log("Stopping scan due to Bluetooth state change.", level: "warn")
        centralManager.stopScan()
        // Fail pending scan result if any
        if let scanCallback = pendingScanResult {
          let errorMsg = "Scan stopped: Bluetooth state changed"
          scanCallback(FlutterError(code: "BLUETOOTH_OFF", message: errorMsg, details: nil))
          pendingScanResult = nil
        }
        sendEvent(
          type: .scanResult, data: ["status": "stopped", "reason": "Bluetooth not powered on"])
      }
    }
    // Optional: Start scanning automatically if needed when powered on?
    // else { startScanImplicitlyIfNeeded() }
  }

  public func centralManager(
    _ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
    advertisementData: [String: Any], rssi RSSI: NSNumber
  ) {
    let name = peripheral.name ?? "Unknown"
    log("Discovered peripheral: \(name) (\(peripheral.identifier)), RSSI: \(RSSI)")
    // Log advertisement data for debugging
    log("Advertisement Data: \(advertisementData)")
    discoveredPeripherals[peripheral.identifier] = peripheral

    // Send scan result update via EventChannel
    let deviceData: [String: Any] = [
      "name": name,
      "address": peripheral.identifier.uuidString,  // Use 'address' for consistency
      "rssi": RSSI.intValue,
    ]
    sendEvent(type: .scanResult, data: ["status": "discovered", "device": deviceData])

    // Don't resolve pendingScanResult here; wait for timeout or stopScan.
  }

  public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    let deviceId = peripheral.identifier.uuidString
    log("Successfully connected to peripheral: \(peripheral.name ?? "Unknown") (\(deviceId))")

    // Stop scanning if we were (connect usually implies intent)
    if centralManager.isScanning {
      log("Stopping scan because connection established.")
      centralManager.stopScan()
      // Don't necessarily fail pendingScanResult, connection might have been the goal
      // If scan result was explicitly requested, handle it separately maybe?
      sendEvent(
        type: .scanResult, data: ["status": "stopped", "reason": "Connected to peripheral"])
    }

    // Clear discovered list? Optional.
    // discoveredPeripherals.removeAll()

    connectedPeripheral = peripheral  // Confirm connection *now*
    niimbotPrinter = NiimbotPrinter(peripheral: peripheral)
    // niimbotPrinter?.delegate = self  // <<< REMOVE THIS LINE (Actor has no delegate)

    // Discover services and characteristics (asynchronously)
    log("Discovering services for \(deviceId)...")
    peripheral.discoverServices([niimbotServiceUUID])

    // Send connected event BEFORE discovery starts
    sendEvent(type: .connectionState, data: ["status": "connected", "deviceId": deviceId])

    // Complete the pending connection result
    pendingConnectResult?(true)
    pendingConnectResult = nil
  }

  public func centralManager(
    _ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?
  ) {
    let errorMsg = error?.localizedDescription ?? "Unknown error"
    let deviceId = peripheral.identifier.uuidString
    log("Failed to connect to peripheral: \(deviceId), error: \(errorMsg)", level: "error")

    // Send failed connection event
    sendEvent(
      type: .connectionState,
      data: ["status": "error", "deviceId": deviceId, "message": "Failed to connect: \(errorMsg)"])

    // Cleanup if we thought we were connecting to *this* specific peripheral
    // (Check based on pendingConnect logic or if connectedPeripheral was tentatively set)
    // cleanupConnection(peripheralId: peripheral.identifier, reason: "Failed to connect: \(errorMsg)") // Careful: might clean up valid connection if called unexpectedly

    pendingConnectResult?(
      FlutterError(
        code: "CONNECTION_FAILED", message: "Failed to connect: \(errorMsg)", details: nil))
    pendingConnectResult = nil
    // Ensure cleanup happens for the specific peripheral we failed to connect to.
    cleanupConnection(peripheralId: peripheral.identifier, reason: "Failed to connect: \(errorMsg)")
  }

  public func centralManager(
    _ central: CBCentralManager,
    didDisconnectPeripheral peripheral: CBPeripheral,
    error: Error?
  ) {
    let reason = error?.localizedDescription ?? "Disconnected by central or peripheral"
    let deviceId = peripheral.identifier.uuidString
    log(
      "Disconnected from peripheral: \(deviceId), Reason: \(reason)",
      level: error == nil ? "info" : "warn")

    // Send disconnect event BEFORE cleanup
    sendEvent(
      type: .connectionState,
      data: ["status": "disconnected", "deviceId": deviceId, "reason": reason])

    // Only clean up if this is the peripheral we *thought* was connected
    if connectedPeripheral?.identifier == peripheral.identifier {
      cleanupConnection(peripheralId: peripheral.identifier, reason: reason)
    } else {
      log(
        "Disconnected from a peripheral (\(deviceId)) that wasn't the tracked 'connectedPeripheral' (\(connectedPeripheral?.identifier.uuidString ?? "None")). Ignoring full cleanup.",
        level: "warn")
      // Should we still clear pending requests related to this peripheralId if possible?
    }
  }

  // MARK: - NiimbotPrinterDelegate

  // Note: These delegate methods might need more context (e.g., which command was it responding to?)
  // For now, just log and forward raw data/errors if needed. A command queue with callbacks/continuations is better.
  func printerDidRespond(data: Data?, error: Error?) {
    // Forward the response data/error to the NiimbotPrinter instance for processing
    // niimbotPrinter?.handleResponse(data: data, error: error) // <<< Incorrect: private method
    niimbotPrinter?.handleResponseFromDelegate(data: data, error: error)  // <<< Correct: Use nonisolated handler
  }

  func printerDidSend(error: Error?) {
    if let error = error {
      log(
        "NiimbotPrinterDelegate: printerDidSend (write) failed: \(error.localizedDescription)",
        level: "error")
      // This might correlate to a sendCommand failure
      sendEvent(
        type: .error,
        data: [
          "source": "printerDelegate", "code": "WRITE_ERROR", "message": error.localizedDescription,
        ])
      // Fail pending send result if active and this error is relevant? Needs correlation.
      // if let sendResult = pendingSendResult { ... }
    } else {
      // This just means the write was accepted by CoreBluetooth, not that the command succeeded.
      // log("NiimbotPrinterDelegate: printerDidSend - Write acknowledged by Bluetooth stack.")
    }
    // <<< ADD THIS LINE: Notify actor's handler >>>
    niimbotPrinter?.handleWriteConfirmationFromDelegate(error: error)
  }
}
