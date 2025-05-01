package st.mnm.niimbot

// Define event types consistently with Swift
enum class PluginEventType(val rawValue: String) {
    LOG("log"),
    BLUETOOTH_STATE("bluetoothState"),
    CONNECTION_STATE("connectionState"),
    SCAN_RESULT("scanResult"), // Note: Android doesn't really scan this way, but keep for consistency?
    ERROR("error")
}