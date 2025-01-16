package com.shivam.otp_pin_field

import android.app.Activity
import android.app.PendingIntent
import android.content.*
import android.os.Bundle
import android.telephony.TelephonyManager
import android.util.Log
import com.google.android.gms.auth.api.phone.SmsRetriever
import com.google.android.gms.auth.api.phone.SmsRetrieverClient
import com.google.android.gms.common.api.CommonStatusCodes
import com.google.android.gms.common.api.Status
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import java.lang.ref.WeakReference
import java.util.regex.Matcher
import java.util.regex.Pattern


/**
 * OtpPinFieldPlugin
 */
class OtpPinFieldPlugin : FlutterPlugin, ActivityAware, MethodCallHandler {
    private var activity: Activity? = null
    private var pendingHintResult: Result? = null
    private var channel: MethodChannel? = null
    private var broadcastReceiver: SmsBroadcastReceiver? = null

    private val activityResultListener: PluginRegistry.ActivityResultListener =
        object : PluginRegistry.ActivityResultListener {
            override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
                return false
            }
        }

    constructor()

    private constructor(registrar: PluginRegistry.Registrar) {
        activity = registrar.activity()
        setupChannel(registrar.messenger())
        registrar.addActivityResultListener(activityResultListener)
    }

    fun setCode(code: String?) {
        channel?.invokeMethod("smsCode", code)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "requestPhoneHint" -> {
                pendingHintResult = result
                // No longer using deprecated HintRequest, so we skip this for now
                result.success(null)
            }
            "listenForCode" -> {
                val smsCodeRegexPattern: String? = call.argument("smsCodeRegexPattern")
                val client: SmsRetrieverClient? = activity?.let { SmsRetriever.getClient(it) }
                client?.startSmsUserConsent(null)
                client?.startSmsRetriever()

                broadcastReceiver =
                    smsCodeRegexPattern?.let {
                        SmsBroadcastReceiver(
                            WeakReference(this@OtpPinFieldPlugin),
                            it
                        )
                    }
                activity?.registerReceiver(
                    broadcastReceiver,
                    IntentFilter(SmsRetriever.SMS_RETRIEVED_ACTION)
                )
                result.success(null)
            }
            "unregisterListener" -> {
                unregisterReceiver()
                result.success("successfully unregister receiver")
            }
            "getAppSignature" -> {
                val signatureHelper = AppSignatureHelper(activity?.applicationContext)
                val appSignature: String = signatureHelper.appSignature
                result.success(appSignature)
            }
            else -> result.notImplemented()
        }
    }

    private fun setupChannel(messenger: BinaryMessenger) {
        channel = MethodChannel(
            messenger,
            channelName
        )
        channel?.setMethodCallHandler(this)
    }

    private fun unregisterReceiver() {
        broadcastReceiver?.let {
            try {
                activity?.unregisterReceiver(it)
            } catch (ex: Exception) {
                // Silent catch to avoid crash if receiver is not registered
            }
            broadcastReceiver = null
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        setupChannel(binding.binaryMessenger)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        unregisterReceiver()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(activityResultListener)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        unregisterReceiver()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(activityResultListener)
    }

    override fun onDetachedFromActivity() {
        unregisterReceiver()
    }

    class SmsBroadcastReceiver(
        plugin: WeakReference<OtpPinFieldPlugin>,
        smsCodeRegexPattern: String
    ) : BroadcastReceiver() {

        val plugin: WeakReference<OtpPinFieldPlugin> = plugin
        val smsCodeRegexPattern: String = smsCodeRegexPattern

        override fun onReceive(context: Context?, intent: Intent) {
            if (SmsRetriever.SMS_RETRIEVED_ACTION == intent.action) {
                if (plugin.get() == null) {
                    return
                }

                val extras: Bundle? = intent.extras
                val status: Status
                if (extras != null) {
                    status = extras.get(SmsRetriever.EXTRA_STATUS) as Status
                    if (status.statusCode == CommonStatusCodes.SUCCESS) {
                        // Get SMS message contents
                        val message = extras?.getString(SmsRetriever.EXTRA_SMS_MESSAGE)?:""
                        try {
                            val pattern: Pattern = Pattern.compile(smsCodeRegexPattern)
                            val matcher: Matcher = pattern.matcher(message)
                            if (matcher.find()) {
                                plugin.get()!!.setCode(matcher.group(0))
                            } else {
                                plugin.get()!!.setCode(message)
                            }
                        } catch (e: Exception) {
                            e.printStackTrace()
                        }
                    }
                }
            }
        }
    }

    companion object {
        private const val channelName = "otp_pin_field"

        fun registerWith(registrar: PluginRegistry.Registrar) {
            OtpPinFieldPlugin(registrar)
        }
    }
}
