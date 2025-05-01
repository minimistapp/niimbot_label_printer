import CoreBluetooth
import Flutter
import UIKit

public class NiimbotPlugin: NSObject, FlutterPlugin, CBCentralManagerDelegate,
  NiimbotPrinterDelegate
{
  private var centralManager: CBCentralManager!
  private var discoveredPeripherals: [UUID: CBPeripheral] = [:]
  private var connectedPeripheral: CBPeripheral?
  private var niimbotPrinter: NiimbotPrinter?

  // Store Flutter results for async operations
  private var pendingConnectResult: FlutterResult?
  private var pendingScanResult: FlutterResult?
  private var pendingSendResult: FlutterResult?

  // Method channel
  private var channel: FlutterMethodChannel!

  public static func register(with registrar: FlutterPluginRegistrar) {
    print(">>>> NiimbotPlugin REGISTERING WITH REGISTRAR <<<<")
    let channel = FlutterMethodChannel(
      name: "st.mnm.niimbot/printer", binaryMessenger: registrar.messenger())
    let instance = NiimbotPlugin()
    instance.channel = channel  // Store the channel
    // Initialize CBCentralManager here. The queue should ideally be a background queue.
    instance.centralManager = CBCentralManager(delegate: instance, queue: nil)  // Use nil for main queue or specify a background queue
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    print("iOS handle Method: \(call.method)")
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)

    case "isBluetoothPermissionGranted":
      let authorized: Bool
      if #available(iOS 13.1, *) {
        authorized = CBCentralManager.authorization == .allowedAlways
      } else if #available(iOS 13.0, *) {
        // Prior to 13.1, .authorizedAlways did not exist.
        // .restricted and .denied are clear nos.
        // .notDetermined means the user hasn't been asked.
        // Assume .authorized (deprecated) means allowed.
        authorized = centralManager.authorization == .authorized
      } else {
        authorized = CBPeripheralManager.authorizationStatus() == .authorized
      }
      print("Bluetooth permission authorized: \(authorized)")
      result(authorized)

    case "isBluetoothEnabled":
      let enabled = centralManager.state == .poweredOn
      print("Bluetooth enabled: \(enabled)")
      result(enabled)

    case "isConnected":
      let connected = connectedPeripheral != nil && connectedPeripheral?.state == .connected
      print("Is Connected: \(connected)")
      result(connected)

    case "getPairedDevices":  // iOS equivalent: Scan for nearby devices
      guard centralManager.state == .poweredOn else {
        result(
          FlutterError(
            code: "BLUETOOTH_DISABLED", message: "Bluetooth is not enabled", details: nil))
        return
      }
      print("Starting scan...")
      pendingScanResult = result  // Store result callback
      discoveredPeripherals.removeAll()
      // Scan for peripherals advertising the Niimbot service UUID
      centralManager.scanForPeripherals(withServices: [niimbotServiceUUID], options: nil)
    // Set a timer to stop scanning after a few seconds
    // TODO: Add a timeout mechanism for scan
    // For now, we manually stop and return results after a delay or require a stopScan method.

    case "connect":
      guard centralManager.state == .poweredOn else {
        result(
          FlutterError(
            code: "BLUETOOTH_DISABLED", message: "Bluetooth is not enabled", details: nil))
        return
      }
      guard let deviceIdentifierString = call.arguments as? String,
        let deviceUUID = UUID(uuidString: deviceIdentifierString)
      else {
        result(
          FlutterError(
            code: "INVALID_ARGUMENT", message: "Device identifier (UUID string) required",
            details: nil))
        return
      }

      print("Attempting to connect to peripheral with UUID: \(deviceUUID)")
      pendingConnectResult = result  // Store result callback

      // Try to retrieve the peripheral if known
      let knownPeripherals = centralManager.retrievePeripherals(withIdentifiers: [deviceUUID])
      if let peripheral = knownPeripherals.first {
        print("Found known peripheral. Connecting...")
        connectToPeripheral(peripheral)
      } else {
        // If not known (e.g., after app restart), try finding it in discovered list (if scanning recently)
        if let peripheral = discoveredPeripherals[deviceUUID] {
          print("Found peripheral in discovered list. Connecting...")
          connectToPeripheral(peripheral)
        } else {
          // Might need to scan first if the peripheral isn't known or discovered
          print("Peripheral not found in known or discovered lists. Scan first.")
          pendingConnectResult?(
            FlutterError(
              code: "NOT_FOUND", message: "Peripheral not found. Scan first?", details: nil))
          pendingConnectResult = nil
        }
      }

    case "send":
      guard let printer = niimbotPrinter, connectedPeripheral?.state == .connected else {
        result(FlutterError(code: "NOT_CONNECTED", message: "Printer not connected", details: nil))
        return
      }
      guard let args = call.arguments as? [String: Any],  // Cast to dictionary
        let bytesFlutter = args["bytes"] as? FlutterStandardTypedData,  // Get bytes as Flutter typed data
        let width = args["width"] as? Int,
        let height = args["height"] as? Int
      else {
        result(
          FlutterError(
            code: "INVALID_ARGUMENT", message: "Invalid arguments for send", details: nil))
        return
      }

      let bytes = bytesFlutter.data  // Get Swift Data
      let rotate = args["rotate"] as? Bool ?? false
      let invertColor = args["invertColor"] as? Bool ?? false
      let density = args["density"] as? Int ?? 3
      let labelType = args["labelType"] as? Int ?? 1

      print("Received image data: \(width)x\(height), \(bytes.count) bytes")

      // Create UIImage from bytes (assuming ARGB32 format)
      guard let image = createImageFromBytes(bytes: bytes, width: width, height: height) else {
        result(
          FlutterError(
            code: "IMAGE_CREATION_FAILED", message: "Could not create image from provided bytes",
            details: nil))
        return
      }

      pendingSendResult = result  // Store result callback

      // Launch async task to call the printer's async method
      Task {
        do {
          print("Starting printBitmap task...")
          try await printer.printBitmap(
            image, density: density, labelType: labelType, quantity: 1, rotate: rotate,
            invertColor: invertColor)
          print("printBitmap task finished successfully.")
          self.pendingSendResult?(true)
        } catch {
          print("printBitmap task failed: \(error)")
          self.pendingSendResult?(
            FlutterError(code: "PRINT_FAILED", message: error.localizedDescription, details: nil))
        }
        self.pendingSendResult = nil  // Clear callback
      }

    case "disconnect":
      if let peripheral = connectedPeripheral {
        print("Disconnecting from peripheral \(peripheral.identifier)")
        centralManager.cancelPeripheralConnection(peripheral)
        // Cleanup happens in didDisconnectPeripheral delegate method
      } else {
        print("No peripheral connected.")
      }
      result(true)  // Assume success, actual disconnect is async

    default:
      print(">>>> Method not implemented: \(call.method)")
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Helper Functions

  private func connectToPeripheral(_ peripheral: CBPeripheral) {
    // Ensure not already trying to connect to this one
    // if peripheral.state == .connecting { return }

    // Disconnect from any currently connected peripheral first
    if let currentPeripheral = connectedPeripheral, currentPeripheral != peripheral {
      print("Disconnecting from previous peripheral \(currentPeripheral.identifier)")
      centralManager.cancelPeripheralConnection(currentPeripheral)
    }

    print("Connecting to \(peripheral.identifier)...")
    connectedPeripheral = peripheral  // Tentatively set, confirm on didConnect
    centralManager.connect(peripheral, options: nil)
    // Stop scanning if we were
    // centralManager.stopScan()
  }

  private func cleanupConnection() {
    print("Cleaning up connection...")
    connectedPeripheral?.delegate = nil  // Remove delegate ref
    niimbotPrinter?.cleanup()
    niimbotPrinter = nil
    connectedPeripheral = nil
    // Clear any pending results that depended on the connection
    if let connectResult = pendingConnectResult {
      connectResult(
        FlutterError(
          code: "DISCONNECTED", message: "Peripheral disconnected during operation", details: nil))
      pendingConnectResult = nil
    }
    if let sendResult = pendingSendResult {
      sendResult(
        FlutterError(
          code: "DISCONNECTED", message: "Peripheral disconnected during send", details: nil))
      pendingSendResult = nil
    }
    // TODO: Notify Flutter side about disconnection? Maybe via event channel.
  }

  private func createImageFromBytes(bytes: Data, width: Int, height: Int) -> UIImage? {
    let bitsPerComponent = 8
    let bitsPerPixel = 32  // Assuming ARGB_8888 from Flutter/Kotlin
    let bytesPerRow = width * (bitsPerPixel / 8)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo(
      rawValue: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)

    guard let providerRef = CGDataProvider(data: bytes as CFData) else {
      print("Error: Could not create CGDataProvider")
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
        bitmapInfo: bitmapInfo,
        provider: providerRef,
        decode: nil,
        shouldInterpolate: true,
        intent: .defaultIntent)
    else {
      print("Error: Could not create CGImage")
      return nil
    }

    return UIImage(cgImage: cgImage)
  }

  // MARK: - CBCentralManagerDelegate

  public func centralManagerDidUpdateState(_ central: CBCentralManager) {
    print("Central Manager State Updated: ", terminator: "")
    switch central.state {
    case .poweredOn:
      print("Powered On")
    // Start scanning or notify Flutter that BT is ready
    case .poweredOff:
      print("Powered Off")
      cleanupConnection()
    // Notify Flutter
    case .resetting:
      print("Resetting")
      cleanupConnection()
    case .unauthorized:
      print("Unauthorized")
      cleanupConnection()
    case .unknown:
      print("Unknown")
      cleanupConnection()
    case .unsupported:
      print("Unsupported")
      cleanupConnection()
    @unknown default:
      print("Unknown future state")
      cleanupConnection()
    }
  }

  public func centralManager(
    _ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
    advertisementData: [String: Any], rssi RSSI: NSNumber
  ) {
    // Ignore peripherals without names? Or filter based on advertisement data?
    let name = peripheral.name ?? "Unknown"
    print("Discovered peripheral: \(name) (\(peripheral.identifier)), RSSI: \(RSSI)")
    discoveredPeripherals[peripheral.identifier] = peripheral

    // If scan was triggered by getPairedDevices, update results (needs refinement)
    if pendingScanResult != nil {
      // TODO: Improve scan result handling. Maybe wait for timeout or explicit stopScan call.
      // For now, let's just return the current list.
      let deviceList = discoveredPeripherals.values.map { p in
        "\(p.name ?? "Unknown")#\(p.identifier.uuidString)"  // Format: Name#UUID
      }
      //central.stopScan() // Stop scanning immediately? Or wait?
      //pendingScanResult?(deviceList)
      //pendingScanResult = nil
      // Alternative: Send updates via EventChannel
    }
  }

  public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    print(
      "Successfully connected to peripheral: \(peripheral.name ?? "Unknown") (\(peripheral.identifier))"
    )

    // Stop scanning if we were (though connect usually stops it)
    central.stopScan()

    // Clear discovered list? Optional.
    // discoveredPeripherals.removeAll()

    connectedPeripheral = peripheral  // Confirm connection
    niimbotPrinter = NiimbotPrinter(peripheral: peripheral)
    niimbotPrinter?.delegate = self  // Set delegate

    // Discover services and characteristics
    niimbotPrinter?.discoverServices()

    // Complete the pending connection result
    pendingConnectResult?(true)
    pendingConnectResult = nil
  }

  public func centralManager(
    _ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?
  ) {
    print(
      "Failed to connect to peripheral: \(peripheral.identifier), error: \(error?.localizedDescription ?? "Unknown error")"
    )
    if connectedPeripheral == peripheral {
      cleanupConnection()
    }
    pendingConnectResult?(
      FlutterError(
        code: "CONNECTION_FAILED", message: error?.localizedDescription ?? "Failed to connect",
        details: nil))
    pendingConnectResult = nil
  }

  public func centralManager(
    _ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?
  ) {
    print(
      "Disconnected from peripheral: \(peripheral.identifier), error: \(error?.localizedDescription ?? "None")"
    )
    // Only clean up if this is the peripheral we thought was connected
    if connectedPeripheral == peripheral {
      cleanupConnection()
      // TODO: Notify Flutter via EventChannel?
    } else {
      print(
        "Disconnected from a peripheral that wasn't the 'connectedPeripheral'. Ignoring cleanup.")
    }
  }

  // MARK: - NiimbotPrinterDelegate

  func printerDidRespond(data: Data?, error: Error?) {
    print("NiimbotPrinterDelegate: printerDidRespond")
    // TODO: Handle responses for specific commands, potentially resume continuations
    // This is where data received from the printer via notifications arrives.
  }

  func printerDidSend(error: Error?) {
    print("NiimbotPrinterDelegate: printerDidSend - Write acknowledged (or failed)")
    // TODO: Handle write confirmations/errors, potentially resume continuations
    if let error = error {
      // Handle write error - maybe fail a pending send?
      if let sendResult = pendingSendResult {
        sendResult(
          FlutterError(code: "WRITE_ERROR", message: error.localizedDescription, details: nil))
        pendingSendResult = nil
      }
    }
  }
}
