package ar.com.digipad

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.location.LocationManager
import android.bluetooth.BluetoothAdapter
import android.net.wifi.WifiManager


class MainActivity : FlutterActivity() {

    private var multicastLock: WifiManager.MulticastLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        flutterEngine
            .platformViewsController
            .registry
            .registerViewFactory(
                "native-left-view",
                NativeYoloViewFactory(flutterEngine.dartExecutor.binaryMessenger)
            )
        // Note: HotspotPlugin and NetworkBindingPlugin have been removed.
        // Networking is now handled by the Nearby Connections Flutter plugin
        // (nearby_connections package) which registers itself automatically.
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ar.com.digipad.photosync/capabilities").setMethodCallHandler { call, result ->
            when (call.method) {
                "getCapabilities" -> {
                    val pm = context.packageManager
                    val isAndroidTV = pm.hasSystemFeature("android.software.leanback")
                    val hasBluetooth = pm.hasSystemFeature("android.hardware.bluetooth")
                    val hasBle = pm.hasSystemFeature("android.hardware.bluetooth_le")
                    val hasWifiDirect = pm.hasSystemFeature("android.hardware.wifi.direct")
                    
                    result.success(mapOf(
                        "isAndroidTV" to isAndroidTV,
                        "hasBluetooth" to hasBluetooth,
                        "hasBle" to hasBle,
                        "hasWifiDirect" to hasWifiDirect
                    ))
                }
                "startForegroundService" -> {
                    val intent = Intent(context, NearbyForegroundService::class.java)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        context.startForegroundService(intent)
                    } else {
                        context.startService(intent)
                    }
                    result.success(true)
                }
                "stopForegroundService" -> {
                    val intent = Intent(context, NearbyForegroundService::class.java)
                    context.stopService(intent)
                    result.success(true)
                }
                "isLocationEnabled" -> {
                    val locationManager = context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager
                    val enabled = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                        locationManager?.isLocationEnabled ?: false
                    } else {
                        val mode = Settings.Secure.getInt(
                            context.contentResolver, 
                            Settings.Secure.LOCATION_MODE, 
                            Settings.Secure.LOCATION_MODE_OFF
                        )
                        mode != Settings.Secure.LOCATION_MODE_OFF
                    }
                    result.success(enabled)
                }
                "isBluetoothEnabled" -> {
                    val adapter = BluetoothAdapter.getDefaultAdapter()
                    result.success(adapter?.isEnabled == true)
                }
                "isWifiEnabled" -> {
                    val wifiManager = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
                    result.success(wifiManager?.isWifiEnabled == true)
                }
                "acquireMulticastLock" -> {
                    try {
                        if (multicastLock == null) {
                            val wm = context.applicationContext
                                .getSystemService(Context.WIFI_SERVICE) as WifiManager
                            multicastLock = wm.createMulticastLock("digipad-photosync").apply {
                                setReferenceCounted(false)
                            }
                        }
                        multicastLock?.acquire()
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "releaseMulticastLock" -> {
                    try {
                        if (multicastLock?.isHeld == true) multicastLock?.release()
                    } catch (_: Exception) {}
                    result.success(true)
                }
                "openLocationSettings", "openWifiSettings", "openBluetoothSettings" -> {
                    val action = when (call.method) {
                        "openWifiSettings" -> Settings.ACTION_WIFI_SETTINGS
                        "openBluetoothSettings" -> Settings.ACTION_BLUETOOTH_SETTINGS
                        else -> Settings.ACTION_LOCATION_SOURCE_SETTINGS
                    }
                    try {
                        context.startActivity(
                            Intent(action).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        )
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            context.startActivity(
                                Intent(Settings.ACTION_SETTINGS)
                                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            )
                        } catch (_: Exception) {}
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}