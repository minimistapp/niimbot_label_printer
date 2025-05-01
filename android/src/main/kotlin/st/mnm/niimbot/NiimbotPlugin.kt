package st.mnm.niimbot

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothSocket
import androidx.annotation.NonNull
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.IOException
import java.io.OutputStream
import java.nio.ByteBuffer
import java.util.UUID
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import st.mnm.niimbot.PluginEventType // Add import for the moved enum


class NiimbotPlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {
    /// The MethodChannel that will the communication between Flutter and native Android
    ///
    /// This local reference serves to register the plugin with the Flutter Engine and unregister it
    /// when the Flutter Engine is detached from the Activity
    private val TAG = "====> NiimbotPlugin:"
    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    private lateinit var context: Context
    private var bluetoothAdapter: BluetoothAdapter? = null
    private var niimbotPrinter: NiimbotPrinter? = null
    private var bluetoothSocket: BluetoothSocket? = null
    private var connectedDeviceAddress: String? = null

    // Coroutine scope for background tasks
    private val coroutineScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val mainHandler = Handler(Looper.getMainLooper())

    //val pluginActivity: Activity = activity
    //private val application: Application = activity.application
    private val myPermissionCode = 34264
    private var activeResult: Result? = null
    private var permissionGranted: Boolean = false

    // --- Logging Helper ---
    private fun log(message: String, level: String = "info") {
        when (level) {
            "error" -> Log.e(TAG, message)
            "warn" -> Log.w(TAG, message)
            else -> Log.i(TAG, message)
        }
        val logData = mapOf("level" to level, "message" to message)
        sendEvent(PluginEventType.LOG, logData)
    }

    // --- Event Sending Helper ---
    private fun sendEvent(type: PluginEventType, data: Any?) {
        // Ensure events are sent on the main thread
        mainHandler.post {
            val eventMap = mapOf(
                "type" to type.rawValue, // Use enum rawValue
                "data" to data
            )
            eventSink?.success(eventMap)
        }
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "st.mnm.niimbot/printer")
        channel.setMethodCallHandler(this)

        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "st.mnm.niimbot/printer_events")
        eventChannel.setStreamHandler(this)

        val bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager?
        bluetoothAdapter = bluetoothManager?.adapter

        log("Plugin attached to engine. Bluetooth Adapter exists: ${bluetoothAdapter != null}")
    }

    // --- EventChannel.StreamHandler ---    
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        log("EventChannel: onListen called.")
        eventSink = events
        // Send initial state if possible
        sendBluetoothStateEvent()
    }

    override fun onCancel(arguments: Any?) {
        log("EventChannel: onCancel called.")
        eventSink = null
    }

    // --- MethodCallHandler ---
    @SuppressLint("MissingPermission") // Permissions checked before use
    override fun onMethodCall(call: MethodCall, result: Result) {
        log("Handling method call: ${call.method}")

        if (!hasBluetoothPermissions()) {
            val errorMsg = "Missing required Bluetooth permissions (CONNECT and/or SCAN depending on SDK)"
            log(errorMsg, level = "error")
            result.error("MISSING_PERMISSION", errorMsg, null)
            return
        }

        when (call.method) {
            "getPlatformVersion" -> {
                result.success("Android ${Build.VERSION.RELEASE}")
            }
            "isBluetoothPermissionGranted" -> {
                 // This check is now done at the start of onMethodCall
                 result.success(hasBluetoothPermissions())
             }
            "isBluetoothEnabled" -> {
                val isEnabled = bluetoothAdapter?.isEnabled == true
                log("Bluetooth enabled check: $isEnabled")
                result.success(isEnabled)
                sendBluetoothStateEvent() // Send current state too
            }
            "isConnected" -> {
                val connected = bluetoothSocket?.isConnected == true
                log("isConnected check: $connected, Socket: ${bluetoothSocket != null}")
                result.success(connected)
                // Optionally, send connection state event if different from last known
                sendConnectionStateEvent()
            }
            "getPairedDevices" -> {
                if (bluetoothAdapter == null) {
                    log("Bluetooth adapter is null", level = "error")
                    result.error("BLUETOOTH_UNAVAILABLE", "Bluetooth adapter is null", null)
                    return
                }
                if (!bluetoothAdapter!!.isEnabled) {
                     log("Bluetooth not enabled for getPairedDevices", level="warn")
                     result.success(listOf<Map<String, String>>()) // Return empty list if BT off
                     return
                 }

                try {
                    val pairedDevices: Set<BluetoothDevice>? = bluetoothAdapter?.bondedDevices
                    val deviceList = pairedDevices?.mapNotNull { device ->
                        // Sometimes name can be null, handle it
                        val deviceName = device.name ?: "Unknown Device"
                         mapOf("name" to deviceName, "address" to device.address)
                    } ?: listOf()
                    log("Found ${deviceList.size} paired devices.")
                    result.success(deviceList)
                } catch (e: SecurityException) {
                     log("SecurityException getting paired devices: ${e.message}", level = "error")
                     sendEvent(PluginEventType.ERROR, mapOf("code" to "PERMISSION_ERROR", "message" to "Permission denied for bonded devices: ${e.message}"))
                     result.error("PERMISSION_ERROR", "Permission denied for bonded devices: ${e.message}", null)
                 } catch (e: Exception) {
                     log("Exception getting paired devices: ${e.message}", level = "error")
                     result.error("UNKNOWN_ERROR", "Failed to get paired devices: ${e.message}", null)
                 }
            }
            "connect" -> {
                if (bluetoothAdapter == null || !bluetoothAdapter!!.isEnabled) {
                    log("Cannot connect: Bluetooth adapter null or disabled.", level = "error")
                    result.success(false) // Consistent with previous logic, but perhaps error is better?
                    return
                }

                val args = call.arguments as? Map<String, Any>
                val macAddress = args?.get("address") as? String

                if (macAddress == null) {
                    log("Connect failed: Missing or invalid 'address' argument.", level = "error")
                    result.error("INVALID_ARGUMENT", "Missing 'address' in arguments", null)
                    return
                }

                log("Attempting to connect to: $macAddress")
                sendEvent(PluginEventType.CONNECTION_STATE, mapOf("status" to "connecting", "deviceId" to macAddress))

                // Disconnect existing connection if trying to connect to a different device
                if (bluetoothSocket?.isConnected == true && connectedDeviceAddress != macAddress) {
                    log("Disconnecting from $connectedDeviceAddress before connecting to $macAddress")
                    disconnect()
                }
                // Avoid reconnecting if already connected to the same device
                 else if (bluetoothSocket?.isConnected == true && connectedDeviceAddress == macAddress) {
                     log("Already connected to $macAddress")
                     result.success(true)
                     return
                 }

                coroutineScope.launch {
                    try {
                        val device = bluetoothAdapter!!.getRemoteDevice(macAddress)
                        // Standard SPP UUID
                        val uuid = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
                        val socket = device.createRfcommSocketToServiceRecord(uuid)
                        socket.connect() // This is a blocking call
                        
                        // Success
                        bluetoothSocket = socket
                        connectedDeviceAddress = macAddress
                        niimbotPrinter = NiimbotPrinter(context, socket)
                        log("Successfully connected to $macAddress")
                        sendEvent(PluginEventType.CONNECTION_STATE, mapOf("status" to "connected", "deviceId" to macAddress))
                        // Ensure result is sent on the main thread
                        mainHandler.post { result.success(true) }

                    } catch (e: IOException) {
                        log("IOException during connect to $macAddress: ${e.message}", level = "error")
                        sendEvent(PluginEventType.ERROR, mapOf("code" to "CONNECTION_IO_ERROR", "message" to "${e.message}"))
                        cleanupConnection(reason = "Connection failed: ${e.message}")
                        mainHandler.post { result.success(false) }
                    } catch (e: SecurityException) {
                        log("SecurityException during connect to $macAddress: ${e.message}", level = "error")
                        sendEvent(PluginEventType.ERROR, mapOf("code" to "PERMISSION_ERROR", "message" to "Permission denied: ${e.message}"))
                        cleanupConnection(reason = "Permission denied: ${e.message}")
                        mainHandler.post { result.error("PERMISSION_ERROR", "Permission denied for connect: ${e.message}", null) }
                     } catch (e: Exception) {
                        log("Generic exception during connect to $macAddress: ${e.message}", level = "error")
                        sendEvent(PluginEventType.ERROR, mapOf("code" to "CONNECTION_UNKNOWN_ERROR", "message" to "Unknown connection error: ${e.message}"))
                        cleanupConnection(reason = "Unknown connection error: ${e.message}")
                        mainHandler.post { result.error("CONNECTION_ERROR", "Unknown connection error: ${e.message}", null) }
                    }
                }
            }
            "send" -> {
                if (niimbotPrinter == null || bluetoothSocket?.isConnected != true) {
                    log("Send failed: Not connected.", level = "error")
                    result.error("NOT_CONNECTED", "Printer not connected", null)
                    return
                }

                val args = call.arguments as? Map<String, Any>
                if (args == null) {
                     log("Send failed: Invalid arguments (null).", level = "error")
                    result.error("INVALID_ARGUMENT", "Arguments cannot be null for send", null)
                     return
                 }

                 try {
                    // Note: Max dimensions vary by printer model based on label size (at ~8 pixels/mm)
                    // B21, B1, B18: max ~384 pixels width
                    // D11: max ~96 pixels width
                    // B1 (example): 400w x 240h for 50mm x 30mm label (50*8=400, 30*8=240)
                    // Extract arguments with type safety and defaults
                    val bytesFlutter = args["bytes"] as? ByteArray // Expect ByteArray directly if possible
                                    ?: (args["bytes"] as? List<*>)?.filterIsInstance<Int>()?.map { it.toByte() }?.toByteArray() // Fallback for List<Int>
                    val width = args["width"] as? Int
                    val height = args["height"] as? Int
                    val rotate = args["rotate"] as? Boolean ?: false
                    val invertColor = args["invertColor"] as? Boolean ?: false
                    val density = args["density"] as? Int ?: 3
                    val labelType = args["labelType"] as? Int ?: 1

                    if (bytesFlutter == null || width == null || height == null || width <= 0 || height <= 0) {
                         log("Send failed: Invalid image data - bytes: ${bytesFlutter?.size}, width: $width, height: $height", level = "error")
                         result.error("INVALID_ARGUMENT", "Invalid image dimensions or byte data", null)
                         return
                    }

                    log("Processing image for send: ${width}x${height}, ${bytesFlutter.size} bytes. Density: $density, LabelType: $labelType, Rotate: $rotate, Invert: $invertColor")

                    // Create Bitmap
                val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                    val buffer = ByteBuffer.wrap(bytesFlutter)

                    // Verify buffer size matches bitmap requirements
                     if (buffer.remaining() < width * height * 4) {
                         val errorMsg = "Buffer size (${buffer.remaining()}) is smaller than required for ${width}x${height} ARGB_8888 bitmap (${width * height * 4})."
                         log(errorMsg, level="error")
                         result.error("INVALID_ARGUMENT", errorMsg, null)
                         return
                     }

                    bitmap.copyPixelsFromBuffer(buffer)

                    log("Bitmap created, launching print job...")
                    coroutineScope.launch {
                        try {
                            niimbotPrinter!!.printBitmap(
                                bitmap,
                                density = density,
                                labelType = labelType,
                                rotate = rotate,
                                invertColor = invertColor
                                // quantity is handled internally by printBitmap loop?
                            )
                            log("Print job submitted successfully.")
                            // Send event for print started/success?
                            mainHandler.post { result.success(true) }
                        } catch (e: Exception) {
                            log("Exception during printBitmap: ${e.message}", level = "error")
                            mainHandler.post { result.error("PRINT_ERROR", "Print failed: ${e.message}", null) }
                        }
                    }

                 } catch (e: ClassCastException) {
                      log("Send failed: Invalid argument types. ${e.message}", level = "error")
                      result.error("INVALID_ARGUMENT", "Type error in arguments: ${e.message}", null)
                 } catch (e: Exception) {
                     log("Send failed: Unexpected error during argument parsing or bitmap creation. ${e.message}", level = "error")
                     result.error("UNKNOWN_ERROR", "Error preparing send data: ${e.message}", null)
                 }
            }
            "disconnect" -> {
                log("Disconnect called.")
                disconnect()
                result.success(true) // Disconnect is fire-and-forget
            }
            else -> {
                log("Method not implemented: ${call.method}", level = "warn")
            result.notImplemented()
            }
        }
    }

    // --- Helper Methods ---
    @SuppressLint("MissingPermission")
    private fun hasBluetoothPermissions(): Boolean {
        val hasConnectPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED
        } else {
            true // Not needed before SDK 31
        }
        
        val hasScanPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED
        } else {
             // Before SDK 31, coarse location was often needed for scans
             ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
             ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        }
        
        // Basic Bluetooth permission (needed pre-SDK 31)
         val hasBluetoothAdminPermission = ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_ADMIN) == PackageManager.PERMISSION_GRANTED
         val hasBluetoothPermission = ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH) == PackageManager.PERMISSION_GRANTED


        // Log detailed permission status
         if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
             log("Permissions check (SDK >= 31): CONNECT=$hasConnectPermission, SCAN=$hasScanPermission")
             return hasConnectPermission && hasScanPermission
         } else {
             log("Permissions check (SDK < 31): BLUETOOTH=$hasBluetoothPermission, ADMIN=$hasBluetoothAdminPermission, LocationForScan=$hasScanPermission")
             // Need basic BT and Admin, plus location for scanning (used by getPairedDevices implicitly sometimes)
              return hasBluetoothPermission && hasBluetoothAdminPermission && hasScanPermission
         }
    }

    private fun sendBluetoothStateEvent() {
        val state = bluetoothAdapter?.state
        val stateString = when (state) {
            BluetoothAdapter.STATE_OFF -> "poweredOff"
            BluetoothAdapter.STATE_TURNING_OFF -> "turningOff"
            BluetoothAdapter.STATE_ON -> "poweredOn"
            BluetoothAdapter.STATE_TURNING_ON -> "turningOn"
            else -> "unknown"
        }
        log("Sending Bluetooth state event: $stateString")
        sendEvent(PluginEventType.BLUETOOTH_STATE, mapOf("state" to stateString))
    }
    
    private fun sendConnectionStateEvent() {
        val status = if (bluetoothSocket?.isConnected == true) "connected" else "disconnected"
        val deviceId = connectedDeviceAddress
        log("Sending connection state event: $status for $deviceId")
        sendEvent(PluginEventType.CONNECTION_STATE, mapOf("status" to status, "deviceId" to deviceId))
    }

    private fun cleanupConnection(reason: String = "Unknown") {
         log("Cleaning up connection. Reason: $reason")
         try {
             bluetoothSocket?.close()
         } catch (e: IOException) {
             log("IOException during socket close: ${e.message}", level = "warn")
         }
         bluetoothSocket = null
         niimbotPrinter = null // Let GC handle the printer object
         val previouslyConnectedId = connectedDeviceAddress
         connectedDeviceAddress = null
         // Send disconnect event if we were connected
          if (previouslyConnectedId != null) {
              sendEvent(PluginEventType.CONNECTION_STATE, mapOf("status" to "disconnected", "deviceId" to previouslyConnectedId, "reason" to reason))
          }
     }

    private fun disconnect() {
        val deviceId = connectedDeviceAddress
        if (bluetoothSocket != null) {
            log("Disconnecting socket for $deviceId")
             sendEvent(PluginEventType.CONNECTION_STATE, mapOf("status" to "disconnecting", "deviceId" to deviceId))
             cleanupConnection(reason = "User requested disconnect")
            } else {
             log("Disconnect called but no active socket.")
             // Ensure state is consistent
             if (connectedDeviceAddress != null) {
                  cleanupConnection(reason = "Cleanup on disconnect call with no socket")
              }
         }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        log("Plugin detached from engine. Cleaning up.")
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        eventSink = null
        disconnect() // Ensure disconnection on detach
        coroutineScope.cancel() // Cancel ongoing coroutines
    }
}


