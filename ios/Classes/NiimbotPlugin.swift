import CoreBluetooth
import Flutter
import NiimbotObjCSDK
import UIKit

public class NiimbotPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var channel: FlutterMethodChannel!
  private var eventChannel: FlutterEventChannel!
  private var eventSink: FlutterEventSink?
  private var pluginLogger: PluginLogger?
  private var connectedPrinterName: String?

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

    // SDK Initialization: initImageProcessing
    // Ensure "SourceHanSans-Regular.ttc" (or your chosen font) is in ios/Assets/
    // and s.resources in podspec points to it.
    // The Bundle(for: NiimbotPlugin.self) ensures we are looking in the plugin's bundle.
    if let fontPath = Bundle(for: NiimbotPlugin.self).path(
      forResource: "SourceHanSans-Regular", ofType: "ttc")
    {
      var initError: NSError?
      JCAPI.initImageProcessing(fontPath, error: &initError)
      if let error = initError {
        // Use instance.log once logger is initialized in onListen, or print for now
        instance.log(
          "SDK initImageProcessing error: {errorDescription}", level: "error",
          props: ["errorDescription": error.localizedDescription])
      } else {
        instance.log("SDK initImageProcessing successful.")
      }
    } else {
      instance.log(
        "Default font for SDK (SourceHanSans-Regular.ttc) not found in plugin bundle.",
        level: "error")
    }

    registrar.addMethodCallDelegate(instance, channel: methodChannel)
    instance.log("Plugin registration complete (logger will init in onListen).")
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
    // Use a temporary CBCentralManager to check state. Requires CoreBluetooth import.
    // Note: This is synchronous and might not be ideal if called frequently,
    // but for a one-off check it's generally acceptable.
    // We can't store the manager easily without becoming its delegate and handling its lifecycle.
    let tempManager = CBCentralManager(
      delegate: nil, queue: nil,
      options: [CBCentralManagerOptionShowPowerAlertKey: NSNumber(value: false)])
    let isEnabled = tempManager.state == .poweredOn
    log(
      "Bluetooth enabled check: {isEnabled}, state: {stateRawValue}",
      props: ["isEnabled": isEnabled, "stateRawValue": tempManager.state.rawValue])
    result(isEnabled)
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
    log("Starting scan for peripherals using SDK...")

    // Before scanning, ensure BT permission is granted. The SDK might handle this, but good practice.
    // Also check if Bluetooth is powered on.
    let tempManager = CBCentralManager(
      delegate: nil, queue: nil,
      options: [CBCentralManagerOptionShowPowerAlertKey: NSNumber(value: false)])
    guard tempManager.state == .poweredOn else {
      let errorMsg = "Bluetooth is not powered on."
      log(errorMsg, level: "error")
      result(FlutterError(code: "BLUETOOTH_OFF", message: errorMsg, details: nil))
      return
    }

    guard
      CBCentralManager.authorization == .allowedAlways
    else {
      let errorMsg = "Bluetooth permission not granted for scanning."
      log(errorMsg, level: "error")
      result(FlutterError(code: "BLUETOOTH_PERMISSION_DENIED", message: errorMsg, details: nil))
      return
    }

    JCAPI.scanBluetoothPrinter { [weak self] scannedPrinters in
      guard let self = self else { return }
      if let names = scannedPrinters as? [String] {
        let deviceList = names.map { name_in -> [String: String] in
          return ["name": name_in, "address": name_in]
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
    log("Starting handleSend with SDK drawing methods...")

    guard JCAPI.isConnectingState() == 1 || JCAPI.isConnectingState() == 2 else {
      log("Printer not connected for send operation.", level: "error")
      result(FlutterError(code: "NOT_CONNECTED", message: "Printer not connected", details: nil))
      return
    }

    guard let args = call.arguments as? [String: Any],
      let bytesFlutter = args["bytes"] as? FlutterStandardTypedData,
      let widthNum = args["width"] as? NSNumber,
      let heightNum = args["height"] as? NSNumber,
      let imagePixelWidthNum = args["imagePixelWidth"] as? NSNumber,
      let imagePixelHeightNum = args["imagePixelHeight"] as? NSNumber
    else {
      log(
        "Invalid arguments for send. Ensure bytes, width (mm), height (mm), imagePixelWidth, imagePixelHeight are provided and are numbers.",
        level: "error",
        props: ["argsReceived": args]
      )
      result(
        FlutterError(
          code: "INVALID_ARGUMENT",
          message: "Invalid arguments for send. Check types and presence.", details: nil))
      return
    }

    let widthMillimeters = widthNum.doubleValue
    let heightMillimeters = heightNum.doubleValue
    let imagePixelWidth = imagePixelWidthNum.intValue
    let imagePixelHeight = imagePixelHeightNum.intValue

    let imageDataBytes = bytesFlutter.data

    let blackRules = (args["density"] as? NSNumber)?.intValue ?? 3
    let paperStyle = (args["labelType"] as? NSNumber)?.intValue ?? 1
    let quantity = (args["quantity"] as? NSNumber)?.intValue ?? 1
    let performRotate = (args["rotate"] as? NSNumber)?.boolValue ?? false
    let performInvert = (args["invertColor"] as? NSNumber)?.boolValue ?? false

    let imageProcessingType = (args["imageProcessingType"] as? NSNumber)?.intValue ?? 1
    let imageProcessingValue = (args["imageProcessingValue"] as? NSNumber)?.floatValue ?? 127.0

    log(
      "Send params: LabelElementWidthMM={widthMm}, LabelElementHeightMM={heightMm}, ImagePixelWidth={imgPxW}, ImagePixelHeight={imgPxH}, Density={density}, LabelType={labelType}, Quantity={quantity}, Rotate={rotate}, Invert={invert}, imageProcessingType={imgProcType}, imageProcessingValue={imgProcVal}",
      props: [
        "widthMm": widthMillimeters,
        "heightMm": heightMillimeters,
        "imgPxW": imagePixelWidth,
        "imgPxH": imagePixelHeight,
        "density": blackRules,
        "labelType": paperStyle,
        "quantity": quantity,
        "rotate": performRotate,
        "invert": performInvert,
        "imgProcType": imageProcessingType,
        "imgProcVal": imageProcessingValue,
      ]
    )

    guard
      var uiImage = createImageFromBytes(  // Make uiImage mutable
        bytes: imageDataBytes, width: imagePixelWidth, height: imagePixelHeight)
    else {
      log("Could not create UIImage from provided bytes.", level: "error")
      result(
        FlutterError(
          code: "IMAGE_CREATION_FAILED", message: "Could not create UIImage from bytes",
          details: nil))
      return
    }

    // Handle inversion if requested
    if performInvert {
      if let invertedImage = self.invertImageColors(image: uiImage) {
        uiImage = invertedImage
        log("Image colors inverted successfully.")
      } else {
        log("Failed to invert image colors. Proceeding with original image.", level: "warn")
        // Optionally, one could choose to fail here if inversion is critical:
        // result(FlutterError(code: "IMAGE_INVERSION_FAILED", message: "Could not invert image colors", details: nil))
        // return
      }
    }

    // Convert UIImage to PNG Base64 string for DrawLableImage
    guard let pngData = uiImage.pngData(), !pngData.isEmpty else {
      log("Could not get PNG data from UIImage.", level: "error")
      result(
        FlutterError(
          code: "IMAGE_CONVERSION_FAILED", message: "Could not get PNG data from UIImage",
          details: nil))
      return
    }
    let base64ImageData = pngData.base64EncodedString()
    if base64ImageData.isEmpty {
      log("Base64 image data string is empty.", level: "error")
      result(
        FlutterError(
          code: "IMAGE_CONVERSION_FAILED", message: "Base64 image data string is empty",
          details: nil))
      return
    }

    log("Image converted to Base64, size: {size} chars.", props: ["size": base64ImageData.count])

    // Determine rotation angle for SDK (0 or 90 degrees)
    let rotationAngleForSDK: Int32 = performRotate ? 90 : 0
    log("Rotation angle for SDK: {angle} degrees", props: ["angle": rotationAngleForSDK])

    // SDK Printing Sequence:
    log(
      "Calling SDK: startJob (density: {density}, paperStyle: {paperStyle})",
      props: ["density": blackRules, "paperStyle": paperStyle])
    JCAPI.startJob(Int32(blackRules), withPaperStyle: Int32(paperStyle)) {
      [weak self] startSuccess in
      guard let self = self else { return }
      if startSuccess {
        self.log("SDK: startJob successful. Initializing drawing board...")

        // Initialize drawing board - dimensions should match the label or desired print area in mm
        // For simplicity, using the passed width/height, assuming they are for the entire label.
        // The image will be placed at (0,0) on this board and scaled to fit widthMillimeters, heightMillimeters
        JCAPI.initDrawingBoard(
          Float(widthMillimeters), withHeight: Float(heightMillimeters), withHorizontalShift: 0,
          withVerticalShift: 0, rotate: 0, fontArray: [])  // Board rotation is 0, image rotation is separate
        self.log(
          "SDK: Drawing board initialized. Drawing image... WidthMM: {widthMm}, HeightMM: {heightMm}",
          props: ["widthMm": widthMillimeters, "heightMm": heightMillimeters])

        // Draw the image onto the board.
        // x, y, w, h for DrawLableImage are in mm on the drawing board.
        // We'll draw the image to fill the specified width/height in mm.
        let drawSuccess = JCAPI.drawLableImage(
          0, withY: 0, withWidth: Float(widthMillimeters), withHeight: Float(heightMillimeters),
          withImageData: base64ImageData,
          withRotate: rotationAngleForSDK,  // Use the determined rotation angle
          withImageProcessingType: Int32(imageProcessingType),
          withImageProcessingValue: imageProcessingValue)

        if !drawSuccess {
          self.log(
            "SDK: DrawLableImage failed. ImageProcessingType: {type}, Value: {value}",
            level: "error", props: ["type": imageProcessingType, "value": imageProcessingValue])
          result(
            FlutterError(
              code: "DRAW_IMAGE_FAILED", message: "SDK: DrawLableImage failed", details: nil))
          // It might be good to call endJob here if startJob was successful but drawing failed.
          // JCAPI.endPrint { _ in } // Or cancelJob
          return
        }
        self.log("SDK: DrawLableImage successful. Generating JSON...")

        guard let jsonPrintData = JCAPI.generateLableJson(), !jsonPrintData.isEmpty else {
          self.log("SDK: Failed to generate JSON print data or JSON is empty.", level: "error")
          result(
            FlutterError(
              code: "JSON_GENERATION_FAILED", message: "SDK: Failed to generate JSON", details: nil)
          )
          return
        }
        self.log(
          "SDK: JSON generated. Size: {size}. Calling commit...",
          props: ["size": jsonPrintData.count])

        JCAPI.commit(jsonPrintData, withOnePageNumbers: Int32(quantity)) { commitSuccess in
          if commitSuccess {
            self.log(
              "SDK: commit command successful for {quantity} page(s). Will monitor via getPrintingCountInfo and then call endPrint.",
              props: ["quantity": quantity]
            )
            // Simplified: Assume endPrint is called after a delay or count info.
            // This needs robust handling as before.
            var printCheckAttempts = 0
            var timer: Timer?
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] t in
              guard let self = self else {
                t.invalidate()
                return
              }
              printCheckAttempts += 1
              if printCheckAttempts >= 5 {
                t.invalidate()
                self.log(
                  "Placeholder for print completion check timed out after {attempts} attempts. Calling endPrint...",
                  props: ["attempts": printCheckAttempts]
                )
                JCAPI.endPrint { endSuccess in
                  if endSuccess {
                    self.log("SDK: endPrint successful.")
                    result(true)
                  } else {
                    self.log("SDK: endPrint failed.", level: "error")
                    result(
                      FlutterError(
                        code: "PRINT_END_FAILED", message: "SDK: Failed to end print job",
                        details: nil))
                  }
                }
              }
            }
            RunLoop.main.add(timer!, forMode: .common)

          } else {
            self.log("SDK: commit command failed.", level: "error")
            result(
              FlutterError(
                code: "PRINT_CMD_FAILED", message: "SDK: Commit command failed", details: nil))
          }
        }
      } else {
        self.log("SDK: startJob failed.", level: "error")
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
}
