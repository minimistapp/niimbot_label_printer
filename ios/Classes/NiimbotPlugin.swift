import CoreBluetooth
import Flutter
import NiimbotObjCSDK
import UIKit

// MARK: - Protocol Definitions
protocol BluetoothStateHandling {
  func handleBluetoothState(_ state: CBManagerState, result: FlutterResult?)
}

protocol PrinterOperations {
  func connect(to deviceName: String, result: @escaping FlutterResult)
  func disconnect(result: @escaping FlutterResult)
  func send(printData: PrintData, result: @escaping FlutterResult)
}

// MARK: - PrintData Structure
struct PrintData {
  let bytes: Data
  let width: Double
  let height: Double
  let imagePixelWidth: Int
  let imagePixelHeight: Int
  let density: Int
  let labelType: Int
  let quantity: Int
  let rotate: Bool
  let invertColor: Bool
  let imageProcessingType: Int
  let imageProcessingValue: Float
}

// MARK: - Main Plugin Class
public class NiimbotPlugin: NSObject, FlutterPlugin, FlutterStreamHandler, CBCentralManagerDelegate
{
  private var channel: FlutterMethodChannel!
  private var eventChannel: FlutterEventChannel!
  private var eventSink: FlutterEventSink?
  private var pluginLogger: PluginLogger?
  private var connectedPrinterName: String?
  private var centralManager: CBCentralManager?
  private var pendingScanResult: FlutterResult?
  private var pendingResult: FlutterResult?
  private var isBluetoothEnabled = false

  // --- Logging Helper ---
  private func log(_ message: String, level: String = "info", props: [String: Any]? = nil) {
    if let logger = pluginLogger {
      logger.log(message, level: level, props: props)
    } else {
      // Fallback to print if logger is not yet initialized (e.g., during early registration)
      let propString =
        props?.map { element in "\(element.key): \(String(describing: element.value))" }.joined(
          separator: ", ") ?? ""
      var logMessage = "[NiimbotPlugin:\(level.uppercased())] \(message)"
      if !propString.isEmpty {
        logMessage += " | Props: \(propString)"
      }
      print(logMessage)
    }
  }

  // --- Event Sending Helper ---
  private func sendEvent(type: PluginEventType, data: Any?) {
    if type == .log || type == .error {
      log(
        "Log/Error event sent via sendEvent. Type: {type}", level: "warn",
        props: ["type": type.rawValue])
      return
    }
    guard let sink = eventSink else {
      log(
        "EventSink is nil, cannot send event ({eventType}). Data: {eventData}", level: "warn",
        props: ["eventType": type.rawValue, "eventData": String(describing: data)])
      return
    }
    let eventMap: [String: Any?] = [
      "type": type.rawValue,
      "data": data,
    ]
    sink(eventMap)
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let methodChannel = FlutterMethodChannel(
      name: "st.mnm.niimbot/printer", binaryMessenger: registrar.messenger())
    let eventChannel = FlutterEventChannel(
      name: "st.mnm.niimbot/printer_events", binaryMessenger: registrar.messenger())

    let instance = NiimbotPlugin()
    instance.channel = methodChannel
    instance.eventChannel = eventChannel
    eventChannel.setStreamHandler(instance)

    instance.centralManager = CBCentralManager(delegate: instance, queue: nil)

    // SDK Initialization: initImageProcessing - Attempt with ZT025.ttf as we have it
    // Use direct print() for these critical initial logs to ensure they appear in Xcode console
    print("[NiimbotPlugin_REGISTER] Attempting JCAPI.initImageProcessing with ZT025.ttf...")
    if let fontPath = Bundle(for: NiimbotPlugin.self).path(
      forResource: "ZT025", ofType: "ttf")  // Use ZT025.ttf
    {
      var initError: NSError?
      JCAPI.initImageProcessing(fontPath, error: &initError)
      if let error = initError {
        print(
          "[NiimbotPlugin_REGISTER:CRITICAL] SDK initImageProcessing error (with ZT025.ttf): \(error.localizedDescription)"
        )
      } else {
        print("[NiimbotPlugin_REGISTER:INFO] SDK initImageProcessing successful (with ZT025.ttf).")
      }
    } else {
      print(
        "[NiimbotPlugin_REGISTER:CRITICAL] Font ZT025.ttf (for initImageProcessing) NOT FOUND in plugin bundle. SDK may be unstable."
      )
    }

    // Font loading from FONT.json is now handled in handleSend before initDrawingBoard

    registrar.addMethodCallDelegate(instance, channel: methodChannel)
    // Use print for this final registration log too, to see it relative to initImageProcessing
    print(
      "[NiimbotPlugin_REGISTER] Plugin registration complete. Logger will initialize in onListen.")
  }

  // Method to load fonts from FONT.json into Documents/font directory
  // Returns an array of font filenames that were successfully processed/found in Documents/font
  private func loadCustomFontsFromBundle() -> [String] {
    log("Attempting to load custom fonts from plugin bundle...")
    var successfullyProcessedFontFiles: [String] = []

    guard
      let fontJsonPath = Bundle(for: NiimbotPlugin.self).path(forResource: "FONT", ofType: "json")
    else {
      log("FONT.json not found in plugin bundle.", level: "warn")
      return successfullyProcessedFontFiles
    }

    do {
      let fontJsonData = try Data(contentsOf: URL(fileURLWithPath: fontJsonPath))
      guard
        let jsonResult = try JSONSerialization.jsonObject(
          with: fontJsonData, options: .mutableContainers) as? [String: Any],
        let fontsArray = jsonResult["fonts"] as? [[String: String]]
      else {
        log("Failed to parse FONT.json or 'fonts' array not found.", level: "error")
        return successfullyProcessedFontFiles
      }

      let fileManager = FileManager.default
      guard
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
          .first
      else {
        log("Could not get documents directory.", level: "error")
        return successfullyProcessedFontFiles
      }

      let fontDestinationParentDir = documentsDirectory.appendingPathComponent("font")

      if !fileManager.fileExists(atPath: fontDestinationParentDir.path) {
        try fileManager.createDirectory(
          at: fontDestinationParentDir, withIntermediateDirectories: true, attributes: nil)
        log("Created Documents/font directory.")
      }

      for fontInfo in fontsArray {
        guard let fontFileName = fontInfo["url"], let fontCode = fontInfo["fontCode"] else {
          log(
            "Missing 'url' or 'fontCode' in FONT.json entry.", level: "warn",
            props: ["entry": fontInfo])
          continue
        }

        guard
          let sourceFontPath = Bundle(for: NiimbotPlugin.self).path(
            forResource: fontFileName, ofType: nil)  // Use fontFileName directly as it includes extension
        else {
          log(
            "Font file '\(fontFileName)' not found in plugin bundle for code '\(fontCode)'.",
            level: "warn")
          continue
        }

        let destinationFontPath = fontDestinationParentDir.appendingPathComponent(fontFileName)

        if !fileManager.fileExists(atPath: destinationFontPath.path) {
          try fileManager.copyItem(
            at: URL(fileURLWithPath: sourceFontPath), to: destinationFontPath)
          log("Copied '\(fontFileName)' to Documents/font/ for code '\(fontCode)'.")
        }
        // Add to list regardless of whether it was copied now or existed before
        successfullyProcessedFontFiles.append(fontFileName)
      }
      log(
        "Custom font loading process completed. Available in Documents/font: \(successfullyProcessedFontFiles)"
      )
    } catch {
      log(
        "Error during custom font loading: \(error.localizedDescription)", level: "error",
        props: ["errorObj": error])
    }
    return successfullyProcessedFontFiles
  }

  // MARK: - FlutterStreamHandler Methods

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    self.eventSink = events
    self.pluginLogger = PluginLogger(name: "niimbot.NiimbotPlugin", eventSink: events)
    log("EventChannel: onListen called, PluginLogger initialized.")
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    log("EventChannel: onCancel called.")
    self.eventSink = nil
    self.pluginLogger = nil
    return nil
  }

  // MARK: - Method Call Handler
  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    log("Handling method call: {method}", props: ["method": call.method])
    switch call.method {
    case "getPlatformVersion":
      handleGetPlatformVersion(call: call, result: result)

    case "isBluetoothPermissionGranted":
      handleIsBluetoothPermissionGranted(call: call, result: result)

    case "isBluetoothEnabled":
      handleIsBluetoothEnabled(call: call, result: result)

    case "isConnected":
      handleIsConnected(call: call, result: result)

    case "getPairedDevices":
      handleScanForPeripherals(call: call, result: result)

    case "connect":
      handleConnect(call: call, result: result)

    case "send":
      handleSend(call: call, result: result)

    case "disconnect":
      handleDisconnect(call: call, result: result)

    default:
      log("Method not implemented: {method}", level: "warn", props: ["method": call.method])
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Method Call Handlers (Refactored for SDK)

  private func handleGetPlatformVersion(call: FlutterMethodCall, result: @escaping FlutterResult) {
    result("iOS " + UIDevice.current.systemVersion)
  }

  private func handleIsBluetoothPermissionGranted(
    call: FlutterMethodCall, result: @escaping FlutterResult
  ) {
    let authorized: Bool
    let status: CBManagerAuthorization
    if #available(iOS 13.1, *) {
      status = CBCentralManager.authorization
    } else {
      status = CBPeripheralManager.authorizationStatus() == .authorized ? .allowedAlways : .denied
    }

    switch status {
    case .allowedAlways:
      authorized = true
    case .notDetermined:
      authorized = false
      log("Bluetooth permission not determined.", level: "warn")
    case .restricted:
      authorized = false
      log("Bluetooth permission restricted.", level: "warn")
    case .denied:
      authorized = false
      log("Bluetooth permission denied.", level: "error")
    @unknown default:
      authorized = false
      log(
        "Unknown Bluetooth authorization status: {status}", level: "error",
        props: ["status": status.rawValue])
    }
    log("Bluetooth permission authorized: {authorized}", props: ["authorized": authorized])
    result(authorized)
  }

  private func handleIsBluetoothEnabled(call: FlutterMethodCall, result: @escaping FlutterResult) {
    if let centralManager = centralManager {
      switch centralManager.state {
      case .poweredOn:
        result(true)
      case .poweredOff, .unauthorized, .unsupported, .resetting:
        result(false)
      default:
        pendingResult = result
      }
    } else {
      centralManager = CBCentralManager(delegate: self, queue: nil)
      pendingResult = result
    }
  }

  private func handleIsConnected(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let sdkStatus = JCAPI.isConnectingState()
    let connected = (sdkStatus == 1 || sdkStatus == 2)
    log(
      "Is Connected check (SDK): {connected}, SDK status code: {statusCode}",
      props: ["connected": connected, "statusCode": sdkStatus])
    if connected && self.connectedPrinterName == nil {
      self.connectedPrinterName = JCAPI.connectingPrinterName()
    } else if !connected {
      self.connectedPrinterName = nil
    }
    result(connected)
  }

  private func handleScanForPeripherals(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let centralManager = centralManager else {
      result(
        FlutterError(
          code: "BLUETOOTH_NOT_INITIALIZED",
          message: "Bluetooth manager not initialized",
          details: nil))
      return
    }

    switch centralManager.state {
    case .poweredOn:
      _performScan(result: result)
    case .poweredOff:
      result(
        FlutterError(
          code: "BLUETOOTH_OFF",
          message: "Bluetooth is not powered on",
          details: nil))
    case .unauthorized:
      result(
        FlutterError(
          code: "BLUETOOTH_UNAUTHORIZED",
          message: "Bluetooth permission not granted",
          details: nil))
    case .unsupported:
      result(
        FlutterError(
          code: "BLUETOOTH_UNSUPPORTED",
          message: "Bluetooth is not supported on this device",
          details: nil))
    default:
      result(
        FlutterError(
          code: "BLUETOOTH_STATE_UNKNOWN",
          message: "Bluetooth state is unknown",
          details: nil))
    }
  }

  private func _performScan(result: @escaping FlutterResult) {
    guard let manager = centralManager, manager.state == .poweredOn else {
      let errorMsg = "Bluetooth is not powered on."
      log(errorMsg, level: "error")
      result(FlutterError(code: "BLUETOOTH_OFF", message: errorMsg, details: nil))
      return
    }

    guard CBCentralManager.authorization == .allowedAlways else {
      let errorMsg = "Bluetooth permission not granted for scanning."
      log(errorMsg, level: "error")
      result(
        FlutterError(code: "BLUETOOTH_PERMISSION_DENIED", message: errorMsg, details: nil))
      return
    }

    JCAPI.scanBluetoothPrinter { [weak self] scannedPrinters in
      guard let self = self else { return }
      if let names = scannedPrinters as? [String] {
        let deviceList = names.map { name_in -> [String: String] in
          // Check if the name looks like a UUID (36 characters with hyphens)
          let isUUID = name_in.count == 36 && name_in.contains("-")
          return [
            "name": isUUID ? "" : name_in,
            "address": name_in,
          ]
        }
        self.log("SDK Scan found: {count} devices.", props: ["count": deviceList.count])
        result(deviceList)
      } else {
        self.log("SDK Scan found no devices or failed to cast to [String].", level: "warn")
        result([])
      }
    }
  }

  private func handleConnect(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
      let deviceIdentifierString = args["address"] as? String
    else {
      log("Invalid arguments for connect.", level: "error")
      result(
        FlutterError(
          code: "INVALID_ARGUMENT", message: "Missing or invalid 'address' (printer name)",
          details: nil))
      return
    }

    let printerName = deviceIdentifierString
    log(
      "Attempting to connect to peripheral with Name: {name} using SDK",
      props: ["name": printerName])
    sendEvent(type: .connectionState, data: ["status": "connecting", "deviceId": printerName])

    JCAPI.openPrinter(printerName) { [weak self] isSuccess in
      guard let self = self else { return }
      if isSuccess {
        self.connectedPrinterName = printerName
        self.log("SDK: Successfully connected to {name}", props: ["name": printerName])
        self.sendEvent(
          type: .connectionState, data: ["status": "connected", "deviceId": printerName])

        self.setupSDKCallbacks(printerName: printerName)
        result(true)
      } else {
        self.log("SDK: Failed to connect to {name}", level: "error", props: ["name": printerName])
        self.sendEvent(
          type: .connectionState,
          data: [
            "status": "error", "deviceId": printerName, "message": "Failed to connect via SDK",
          ])
        result(
          FlutterError(
            code: "CONNECTION_FAILED", message: "SDK: Failed to connect to \(printerName)",
            details: nil))
      }
    }
  }

  private func setupSDKCallbacks(printerName: String) {
    JCAPI.getPrintingErrorInfo { [weak self] printInfo in
      guard let self = self, let infoStr = printInfo else { return }
      self.log(
        "SDK Print Error Info: {info}", level: "error",
        props: ["info": infoStr, "printerName": printerName])
      self.sendEvent(
        type: .error, data: ["code": "PRINTER_ERROR", "message": infoStr, "deviceId": printerName])
    }

    JCAPI.getPrintingCountInfo { [weak self] printDicInfo in
      guard let self = self, let infoDict = printDicInfo as? [String: Any] else { return }
      self.log(
        "SDK Print Count Info: {info}", props: ["info": infoDict, "printerName": printerName])
      self.sendEvent(
        type: .printerStatus,
        data: ["statusType": "printCount", "data": infoDict, "deviceId": printerName])
    }

    let _ = JCAPI.getPrintStatusChange { [weak self] statusDicInfo in
      guard let self = self, let statusDict = statusDicInfo as? [String: Any] else { return }
      self.log(
        "SDK Printer Status Change: {status}",
        props: ["status": statusDict, "printerName": printerName])
      self.sendEvent(
        type: .printerStatus,
        data: ["statusType": "statusChange", "data": statusDict, "deviceId": printerName])
    }
  }

  private func handleSend(call: FlutterMethodCall, result: @escaping FlutterResult) {
    log("Starting handleSend - REPLICATING NATIVE DEMO (TEXT & QR) - SIMPLIFIED FONT HANDLING...")

    // Ensure fonts are loaded/copied to Documents/font and get the list of font filenames
    let availableFontFiles = loadCustomFontsFromBundle()
    log("Available font files in Documents/font after load attempt: \(availableFontFiles)")

    guard JCAPI.isConnectingState() == 1 || JCAPI.isConnectingState() == 2 else {
      log("Printer not connected for send operation.", level: "error")
      result(FlutterError(code: "NOT_CONNECTED", message: "Printer not connected", details: nil))
      return
    }

    guard let args = call.arguments as? [String: Any],
      let density = (args["density"] as? NSNumber)?.intValue,
      let paperStyle = (args["labelType"] as? NSNumber)?.intValue,
      let quantity = (args["quantity"] as? NSNumber)?.intValue
    else {
      log(
        "Invalid/missing arguments for send (density, labelType, quantity needed).", level: "error",
        props: ["argsReceived": call.arguments])
      result(
        FlutterError(
          code: "INVALID_ARGUMENT", message: "Missing density, labelType, or quantity.",
          details: nil))
      return
    }

    // --- Parameters from the successful native demo log ---
    let boardWidth: Float = 50.0
    let boardHeight: Float = 30.0
    let boardRotate: Int32 = 0

    // Text element from demo
    let textX: Float = 7.5
    let textY: Float = 5.0
    let textWidth: Float = 40.5
    let textHeight: Float = 6.5
    let textRotate: Int32 = 0
    let textValue: String = "ABC"  // TEST WITH SIMPLE ASCII
    let textFontFamily: String = "ZT025"  // From demo, ensure this font is available
    let textFontSize: Float = 3.5
    let textAlignHorizontal: Int32 = 0  // 0: Left
    let textAlignVertical: Int32 = 1  // 1: Center
    let textLineMode: Int32 = 1
    let textLetterSpacing: Float = 0.0
    let textLineSpacing: Float = 1.0
    let textFontStyles: [NSNumber] = [
      NSNumber(value: 0), NSNumber(value: 0), NSNumber(value: 0), NSNumber(value: 0),
    ]

    // QR Code element from demo
    let qrX: Float = 3.0
    let qrY: Float = 12.0
    let qrWidth: Float = 10.0
    let qrHeight: Float = 10.0
    let qrRotate: Int32 = 0
    let qrValue: String = "123456"  // From demo
    let qrCodeType: Int32 = 31  // 31: QR_CODE
    // --- End parameters from demo ---

    log(
      String(
        format: "DEMO REPLICATION - Board: %.1fx%.1f, Rotate:%d. Density:%d, LabelType:%d, Qty:%d",
        boardWidth, boardHeight, boardRotate, density, paperStyle, quantity),
      props: [
        "textValue": textValue,
        "qrValue": qrValue,
      ]
    )

    log("Calling SDK: startJob (density: \(density), paperStyle: \(paperStyle))")
    JCAPI.startJob(Int32(density), withPaperStyle: Int32(paperStyle)) {
      [weak self] startSuccess in
      guard let self = self else { return }
      if startSuccess {
        self.log("SDK: startJob successful. Initializing drawing board...")

        // Prepare font array for initDrawingBoard
        // The SDK demo passes an array of font filenames, e.g., @[@"ZT008.ttf", @"ZT025.ttf"]
        // loadCustomFontsFromBundle() returns filenames like "MyFont.ttf"
        let sdkFontArray = availableFontFiles  // <<<<<<< CORRECTED: Use filenames directly
        self.log("Prepared fontArray for initDrawingBoard: \(sdkFontArray)")

        // Initialize drawing board based on demo parameters, using the loaded font files
        JCAPI.initDrawingBoard(
          boardWidth,
          withHeight: boardHeight,
          withHorizontalShift: 0,
          withVerticalShift: 0,
          rotate: boardRotate,
          fontArray: sdkFontArray
        )
        self.log(
          "SDK: Drawing board initialized (W:\(boardWidth), H:\(boardHeight), FontArray: \(sdkFontArray)). Drawing text and QR code..."
        )

        // 1. Draw Text Element - Enhanced Logging
        self.log(
          "Preparing to call drawLableText with parameters:",
          props: [
            "x": textX,
            "y": textY,
            "width": textWidth,
            "height": textHeight,
            "text": textValue,
            "fontFamily": textFontFamily,
            "fontSize": textFontSize,
            "rotate": textRotate,
            "textAlignHorizontal": textAlignHorizontal,
            "textAlignVertical": textAlignVertical,
            "lineMode": textLineMode,
            "letterSpacing": textLetterSpacing,
            "lineSpacing": textLineSpacing,
            "fontStyle (count)": textFontStyles.count,  // Log count to verify array structure
          ])

        let textDrawSuccess = JCAPI.drawLableText(
          textX,
          withY: textY,
          withWidth: textWidth,
          withHeight: textHeight,
          with: textValue,
          withFontFamily: textFontFamily,
          withFontSize: textFontSize,
          withRotate: textRotate,
          withTextAlignHorizonral: textAlignHorizontal,
          withTextAlignVertical: textAlignVertical,
          withLineMode: textLineMode,
          withLetterSpacing: textLetterSpacing,
          withLineSpacing: textLineSpacing,
          withFontStyle: textFontStyles
        )

        if !textDrawSuccess {
          self.log(
            "SDK: drawLableText FAILED.", level: "error",
            props: ["text": textValue, "font": textFontFamily])
          result(
            FlutterError(
              code: "DRAW_TEXT_FAILED", message: "SDK: drawLableText failed", details: nil))
          return
        }
        self.log("SDK: drawLableText successful for demo text.")

        // 2. Draw QR Code Element
        let qrDrawSuccess = JCAPI.drawLableQrCode(
          qrX,
          withY: qrY,
          withWidth: qrWidth,
          withHeight: qrHeight,
          with: qrValue,
          withRotate: qrRotate,
          withCodeType: qrCodeType
        )

        if !qrDrawSuccess {
          self.log("SDK: drawLableQrCode FAILED.", level: "error", props: ["qrContent": qrValue])
          result(
            FlutterError(
              code: "DRAW_QR_FAILED", message: "SDK: drawLableQrCode failed", details: nil))
          return
        }
        self.log("SDK: drawLableQrCode successful for demo QR.")

        // 3. Generate JSON and Print
        guard let jsonPrintData = JCAPI.generateLableJson(), !jsonPrintData.isEmpty else {
          self.log("SDK: Failed to generate JSON print data or JSON is empty.", level: "error")
          result(
            FlutterError(
              code: "JSON_GENERATION_FAILED", message: "SDK: Failed to generate JSON", details: nil)
          )
          return
        }
        self.log("SDK: JSON generated (Size: \(jsonPrintData.count)). Committing print job...")

        JCAPI.commit(jsonPrintData, withOnePageNumbers: Int32(quantity)) { commitSuccess in
          if commitSuccess {
            self.log("SDK: commit successful for \(quantity) page(s).")
            JCAPI.endPrint { endSuccess in
              if endSuccess {
                self.log("SDK: endPrint successful for demo replication.")
                result(true)
              } else {
                self.log("SDK: endPrint FAILED for demo replication.", level: "error")
                result(
                  FlutterError(
                    code: "PRINT_END_FAILED", message: "SDK: endPrint failed for demo replication",
                    details: nil))
              }
            }
          } else {
            self.log("SDK: commit FAILED.", level: "error")
            result(
              FlutterError(
                code: "PRINT_CMD_FAILED", message: "SDK: Commit command failed", details: nil))
          }
        }
      } else {
        self.log("SDK: startJob FAILED.", level: "error")
        result(
          FlutterError(
            code: "PRINT_START_FAILED", message: "SDK: Failed to start print job", details: nil))
      }
    }
  }

  private func handleDisconnect(call: FlutterMethodCall, result: @escaping FlutterResult) {
    log("Attempting to disconnect using SDK...")
    let previouslyConnectedName = self.connectedPrinterName ?? JCAPI.connectingPrinterName()

    JCAPI.closePrinter()

    if let name = previouslyConnectedName, !name.isEmpty {
      log("SDK: Disconnected from {name}.", props: ["name": name])
      sendEvent(type: .connectionState, data: ["status": "disconnected", "deviceId": name])
    } else {
      log(
        "SDK: Disconnect called, no specific printer name was tracked or returned by SDK post-disconnect."
      )
    }
    self.connectedPrinterName = nil
    result(true)
  }

  private func createImageFromBytes(bytes: Data, width: Int, height: Int) -> UIImage? {
    log(
      "Creating UIImage from {byteCount} bytes, {width}x{height}",
      props: ["byteCount": bytes.count, "width": width, "height": height]
    )
    let bitsPerComponent = 8
    let bitsPerPixel = 32
    let bytesPerRow = width * (bitsPerPixel / 8)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

    guard bytes.count >= height * bytesPerRow else {
      log(
        "Error: Provided data size ({dataSize}) is smaller than calculated required size ({requiredSize}) for {width}x{height} image.",
        level: "error",
        props: [
          "dataSize": bytes.count, "requiredSize": height * bytesPerRow, "width": width,
          "height": height,
        ]
      )
      return nil
    }

    guard let providerRef = CGDataProvider(data: bytes as CFData) else {
      log(
        "Error: Could not create CGDataProvider for image {width}x{height}", level: "error",
        props: ["width": width, "height": height])
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
        shouldInterpolate: false,
        intent: .defaultIntent)
    else {
      log(
        "Error: Could not create CGImage for image {width}x{height}", level: "error",
        props: ["width": width, "height": height])
      return nil
    }

    log(
      "CGImage {width}x{height} created successfully.", props: ["width": width, "height": height])
    return UIImage(cgImage: cgImage)
  }

  // MARK: - Image Utility Helpers (Moved from NiimbotPrinter.swift or adapted)

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

  // MARK: - CBCentralManagerDelegate

  public func centralManagerDidUpdateState(_ central: CBCentralManager) {
    switch central.state {
    case .poweredOn:
      isBluetoothEnabled = true
      if let result = pendingResult {
        result(true)
        pendingResult = nil
      }
    case .poweredOff, .unauthorized, .unsupported, .resetting:
      isBluetoothEnabled = false
      if let result = pendingResult {
        result(false)
        pendingResult = nil
      }
    default:
      break
    }
  }
}
