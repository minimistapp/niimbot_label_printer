import Flutter
import Foundation

// Class responsible for sending log and error events to Flutter
class PluginLogger {
  // Make sink private and non-optional, required at init
  private let eventSink: FlutterEventSink

  init(eventSink: @escaping FlutterEventSink) {
    self.eventSink = eventSink
    // Log initialization automatically
    self.log("PluginLogger initialized.", level: "debug")
  }

  // Log general messages
  func log(_ message: String, level: String = "info") {
    let logData: [String: String] = ["level": level, "message": message]
    let eventMap: [String: Any?] = [
      "type": "log",
      "data": logData,
    ]
    // Ensure sink calls happen on the main thread
    DispatchQueue.main.async {
      self.eventSink(eventMap)
    }
  }

  // Log specific errors
  func error(_ message: String, code: String? = nil, details: String? = nil) {
    var errorData: [String: Any] = ["message": message]
    if let code = code { errorData["code"] = code }
    if let details = details { errorData["details"] = details }

    let eventMap: [String: Any?] = [
      "type": "error",
      "data": errorData,
    ]
    DispatchQueue.main.async {
      self.eventSink(eventMap)
    }
  }
}
