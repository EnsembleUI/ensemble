package com.ensembleui.smart_wifi_connect

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.WifiNetworkSpecifier
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry

class SmartWifiConnectPlugin : FlutterPlugin, MethodCallHandler, ActivityAware,
    PluginRegistry.RequestPermissionsResultListener {

    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var context: Context? = null
    private var pendingResult: Result? = null
    private var pendingCall: MethodCall? = null

    companion object {
        private const val PERMISSION_REQUEST_CODE = 9571
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "smart_wifi_connect")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        context = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "connect" -> handleConnect(call, result)
            else -> result.notImplemented()
        }
    }

    private fun handleConnect(call: MethodCall, result: Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            result.success(mapOf(
                "success" to false,
                "status" to "unsupported",
                "message" to "Wi-Fi connect requires Android 10 (API 29) or higher"
            ))
            return
        }

        if (!hasRequiredPermissions()) {
            pendingResult = result
            pendingCall = call
            requestPermissions()
            return
        }

        performConnect(call, result)
    }

    private fun hasRequiredPermissions(): Boolean {
        val act = activity ?: return false

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(act, Manifest.permission.NEARBY_WIFI_DEVICES) ==
                    PackageManager.PERMISSION_GRANTED
        } else {
            ContextCompat.checkSelfPermission(act, Manifest.permission.ACCESS_FINE_LOCATION) ==
                    PackageManager.PERMISSION_GRANTED &&
            ContextCompat.checkSelfPermission(act, Manifest.permission.CHANGE_WIFI_STATE) ==
                    PackageManager.PERMISSION_GRANTED
        }
    }

    private fun requestPermissions() {
        val act = activity ?: run {
            pendingResult?.success(mapOf(
                "success" to false,
                "status" to "failed",
                "message" to "No activity available to request permissions"
            ))
            pendingResult = null
            pendingCall = null
            return
        }

        val permissions = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            arrayOf(Manifest.permission.NEARBY_WIFI_DEVICES)
        } else {
            arrayOf(
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.CHANGE_WIFI_STATE
            )
        }

        ActivityCompat.requestPermissions(act, permissions, PERMISSION_REQUEST_CODE)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int, permissions: Array<out String>, grantResults: IntArray
    ): Boolean {
        if (requestCode != PERMISSION_REQUEST_CODE) return false

        val result = pendingResult ?: return true
        val call = pendingCall ?: return true

        pendingResult = null
        pendingCall = null

        val allGranted = grantResults.isNotEmpty() && grantResults.all {
            it == PackageManager.PERMISSION_GRANTED
        }

        if (allGranted) {
            performConnect(call, result)
        } else {
            result.success(mapOf(
                "success" to false,
                "status" to "permissionDenied",
                "message" to "Required Wi-Fi permissions were denied"
            ))
        }

        return true
    }

    private fun performConnect(call: MethodCall, result: Result) {
        val ssid = call.argument<String>("ssid") ?: run {
            result.success(mapOf(
                "success" to false,
                "status" to "invalidArguments",
                "message" to "SSID is required"
            ))
            return
        }
        val password = call.argument<String>("password") ?: ""

        val ctx = context ?: run {
            result.success(mapOf(
                "success" to false,
                "status" to "failed",
                "message" to "Context not available"
            ))
            return
        }

        try {
            val specifierBuilder = WifiNetworkSpecifier.Builder()
                .setSsid(ssid)

            if (password.isNotEmpty()) {
                specifierBuilder.setWpa2Passphrase(password)
            }

            val specifier = specifierBuilder.build()

            val networkRequest = NetworkRequest.Builder()
                .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
                .setNetworkSpecifier(specifier)
                .build()

            val connectivityManager = ctx.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

            val callback = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    connectivityManager.bindProcessToNetwork(network)
                    result.success(mapOf(
                        "success" to true,
                        "status" to "connected",
                        "message" to "Connected to $ssid"
                    ))
                    connectivityManager.unregisterNetworkCallback(this)
                }

                override fun onUnavailable() {
                    result.success(mapOf(
                        "success" to false,
                        "status" to "userCancelled",
                        "message" to "Connection request was cancelled or network unavailable"
                    ))
                }
            }

            connectivityManager.requestNetwork(networkRequest, callback)
        } catch (e: Exception) {
            result.success(mapOf(
                "success" to false,
                "status" to "failed",
                "message" to "Failed to connect: ${e.message}",
                "platformCode" to (e::class.simpleName ?: "unknown")
            ))
        }
    }
}
