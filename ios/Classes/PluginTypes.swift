import Foundation

// Define event types for clarity
enum PluginEventType: String {
  case log = "log"
  case bluetoothState = "bluetoothState"
  case connectionState = "connectionState"
  case scanResult = "scanResult"
  case error = "error"
  // Add more specific event types if needed
  // case printerStatus = "printerStatus"
  // case printProgress = "printProgress"
}

// Structure for event data sent to Flutter
struct PluginEvent: Encodable {
  let type: String  // Use PluginEventType.rawValue
  let data: AnyCodable  // Flexible data payload

  // Helper to create a dictionary representation suitable for Flutter EventChannel
  // Note: EventChannel typically sends Any?, so direct dictionary is often easiest.
  func toMap() -> [String: Any?] {
    // Attempt to handle basic types and nested structures reasonably
    let encodedData: Any?
    if let encodableValue = data.value as? Encodable {
      // Try encoding standard Codable types first
      // This is complex to get right universally for 'Any'.
      // A simpler approach is often to pass primitive types or basic collections directly.
      encodedData = data.value  // Pass the underlying value directly for simpler types
    } else {
      encodedData = data.value  // Pass non-Codable types as is (best effort)
    }

    return [
      "type": type,
      "data": encodedData,
    ]
  }
}

// Wrapper to make Any Codable for structured event data.
// WARNING: This is a simplified version for encoding basic types.
// Robustly encoding/decoding 'Any' is complex. Consider using more specific types
// or JSON serialization/deserialization if complex data structures are needed.
struct AnyCodable: Encodable {
  let value: Any

  init<T>(_ value: T?) {
    // Store nil as NSNull for better JSON compatibility if needed,
    // but keeping it simple for direct Flutter channel passing.
    self.value = value ?? ()  // Use Void/() for nil representation
  }

  // Encoding logic (Simplified)
  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()

    // Handle basic types explicitly
    if let stringValue = value as? String {
      try container.encode(stringValue)
    } else if let intValue = value as? Int {
      try container.encode(intValue)
    } else if let boolValue = value as? Bool {
      try container.encode(boolValue)
    } else if let doubleValue = value as? Double {
      try container.encode(doubleValue)
    } else if value is Void || value is () {
      try container.encodeNil()
    }  // Encode our nil representation
    // Handle simple arrays of primitives
    else if let arrayValue = value as? [String] {
      try container.encode(arrayValue)
    } else if let arrayValue = value as? [Int] {
      try container.encode(arrayValue)
    } else if let arrayValue = value as? [Bool] {
      try container.encode(arrayValue)
    } else if let arrayValue = value as? [Double] {
      try container.encode(arrayValue)
    }
    // Handle simple dictionaries of primitives
    else if let dictValue = value as? [String: String] {
      try container.encode(dictValue)
    } else if let dictValue = value as? [String: Int] {
      try container.encode(dictValue)
    } else if let dictValue = value as? [String: Bool] {
      try container.encode(dictValue)
    } else if let dictValue = value as? [String: Double] {
      try container.encode(dictValue)
    }
    // Fallback for dictionaries with Any value (best effort, might fail for complex nested types)
    else if let dictValue = value as? [String: Any] {
      // Requires custom encoding logic or JSONSerialization
      // For simplicity, we'll try encoding as a string representation or fail
      print("Warning: Encoding [String: Any] in AnyCodable is limited. Consider JSON.")
      try container.encode("Dictionary: \(dictValue.count) items")  // Placeholder
    }
    // Fallback for arrays with Any value
    else if let arrayValue = value as? [Any] {
      print("Warning: Encoding [Any] in AnyCodable is limited. Consider JSON.")
      try container.encode("Array: \(arrayValue.count) items")  // Placeholder
    }
    // TODO: Add more types or use JSONSerialization for robust encoding
    else {
      // Attempt to encode nil if it's an actual nil or unsupported type
      print(
        "Warning: AnyCodable encountered an unsupported type: \(type(of: value)). Encoding as nil.")
      try container.encodeNil()
    }
  }
}
