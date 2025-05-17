import CoreBluetooth  // Needed for CBUUID
import Flutter
import Foundation

// Class responsible for sending log and error events to Flutter
class PluginLogger {
  // Sink for sending events to Flutter
  private let eventSink: FlutterEventSink
  // Name of the logger
  private let name: String

  init(name: String, eventSink: @escaping FlutterEventSink) {
    self.name = name  // Store the name
    self.eventSink = eventSink
  }

  // MARK: - Serialization Helpers

  // Attempts to serialize a single value into a basic type or collection thereof
  private func _serialize(_ value: Any) -> Any? {
    switch value {
    case let num as NSNumber:
      // Handle Bool specifically, otherwise return the number
      // CFBoolean is toll-free bridged to NSNumber but compares via objCType
      if String(cString: num.objCType) == "c" {
        return num.boolValue
      } else {
        return num  // Includes Int, Double, etc.
      }
    case let str as String:
      return str
    case let uuid as CBUUID:
      return uuid.uuidString
    case let data as Data:
      return data.base64EncodedString()  // Represent Data as Base64
    case let array as NSArray:  // Use NSArray to catch Swift arrays bridged to Objective-C
      // Recursively serialize array elements
      var serializableArray: [Any?] = []
      for element in array {
        serializableArray.append(_serialize(element))
      }
      return serializableArray
    case let dict as NSDictionary:  // Use NSDictionary to catch Swift dicts bridged to Objective-C
      // Recursively serialize dictionary values (keys must be strings)
      var serializableDict: [String: Any?] = [:]
      for (key, val) in dict {
        if let stringKey = key as? String {
          serializableDict[stringKey] = _serialize(val)
        } else {
          // Log key type if not string, discard entry
          print(
            "PluginLogger Warning: Dictionary key is not a String: \(String(describing: type(of: key)))"
          )
        }
      }
      return serializableDict
    case is NSNull:
      return nil  // Represent NSNull as nil
    default:
      // If not a known serializable type, return its description
      print(
        "PluginLogger Warning: Attempting to serialize unknown type using description: \(String(describing: type(of: value)))"
      )
      return String(describing: value)  // Use description of the value itself
    }
  }

  // Serializes the entire props dictionary
  private func _serializeProps(_ props: [String: Any]?) -> [String: Any]? {
    guard let props = props else { return nil }
    var serializableProps: [String: Any] = [:]
    for (key, value) in props {
      if let serializedValue = _serialize(value) {
        serializableProps[key] = serializedValue
      } else {
        // Optionally handle nil values, e.g., include them or omit them
        // serializableProps[key] = nil // Or just omit
      }
    }
    return serializableProps
  }

  // MARK: - Public Logging Methods

  // Log general messages
  func log(_ message: String, level: String = "info", props: [String: Any]? = nil) {
    var logData: [String: Any] = [
      "level": level,
      "message": message,
      "loggerName": self.name,
    ]
    // Serialize props before adding
    if let serializedProps = _serializeProps(props) {
      logData["props"] = serializedProps
    }
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
  func error(
    _ message: String, code: String? = nil, details: String? = nil, props: [String: Any]? = nil
  ) {
    var errorData: [String: Any] = [
      "message": message,
      "loggerName": self.name,
    ]
    if let code = code { errorData["code"] = code }
    if let details = details { errorData["details"] = details }
    // Serialize props before adding
    if let serializedProps = _serializeProps(props) {
      errorData["props"] = serializedProps
    }

    let eventMap: [String: Any?] = [
      "type": "error",
      "data": errorData,
    ]
    DispatchQueue.main.async {
      self.eventSink(eventMap)
    }
  }
}
