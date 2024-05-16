package com.shivam.otp_pin_field

import android.app.Activity
import android.app.PendingIntent
import android.content.*
import android.os.Bundle
import android.telephony.TelephonyManager
import android.util.Log
import com.google.android.gms.auth.api.Auth
import com.google.android.gms.auth.api.credentials.Credential
import com.google.android.gms.auth.api.credentials.HintRequest
import com.google.android.gms.auth.api.phone.SmsRetriever
import com.google.android.gms.auth.api.phone.SmsRetrieverClient
import com.google.android.gms.common.api.CommonStatusCodes
import com.google.android.gms.common.api.GoogleApiClient
import com.google.android.gms.common.api.Status
import com.google.android.gms.tasks.Task
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
        if (requestCode == PHONE_HINT_REQUEST && pendingHintResult != null) {
          if (resultCode == Activity.RESULT_OK && data != null) {
            val credential: Credential? = data.getParcelableExtra(Credential.EXTRA_KEY)
            val phoneNumber: String? = credential?.id
            pendingHintResult!!.success(phoneNumber)
          } else {
            pendingHintResult!!.success(null)
          }
          return true
        }
        return false
      }
    }

  constructor() {}
  private constructor(registrar: PluginRegistry.Registrar) {
    activity = registrar.activity()
    setupChannel(registrar.messenger())
    registrar.addActivityResultListener(activityResultListener)
  }

  fun setCode(code: String?) {
    channel?.invokeMethod("smsCode", code)
  }

  override fun onMethodCall(call: MethodCall,  result: Result) {
    when (call.method) {
      "requestPhoneHint" -> {
        pendingHintResult = result
        requestHint()
      }
      "listenForCode" -> {
        val smsCodeRegexPattern: String? = call.argument("smsCodeRegexPattern")
        val client: SmsRetrieverClient? = activity?.let { SmsRetriever.getClient(it) }
        client?.startSmsUserConsent(null);
        client!!.startSmsRetriever()

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

  private fun requestHint() {
    if (!isSimSupport) {
      if (pendingHintResult != null) {
        pendingHintResult!!.success(null)
      }
      return
    }
    val hintRequest: HintRequest = HintRequest.Builder()
      .setPhoneNumberIdentifierSupported(true)
      .build()
    val mCredentialsClient: GoogleApiClient = activity?.let {
      GoogleApiClient.Builder(it)
        .addApi(Auth.CREDENTIALS_API)
        .build()
    }!!
    val intent: PendingIntent = Auth.CredentialsApi.getHintPickerIntent(
      mCredentialsClient, hintRequest
    )
    try {
      activity?.startIntentSenderForResult(
        intent.intentSender,
        PHONE_HINT_REQUEST,
        null,
        0,
        0,
        0
      )
    } catch (e: IntentSender.SendIntentException) {
      e.printStackTrace()
    }
  }

  private val isSimSupport: Boolean
    get() {
      val telephonyManager: TelephonyManager =
        activity?.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
      return telephonyManager.simState != TelephonyManager.SIM_STATE_ABSENT
    }

  private fun setupChannel(messenger: BinaryMessenger) {
    channel = MethodChannel(
      messenger,
      channelName
    )
    channel?.setMethodCallHandler(this)
  }

  private fun unregisterReceiver() {
    if (broadcastReceiver != null) {
      try {
        activity?.unregisterReceiver(broadcastReceiver)
      } catch (ex: Exception) {

        // silent catch to avoir crash if receiver is not registered
      }
      broadcastReceiver = null
    }
  }

  /**
   * This `FlutterPlugin` has been associated with a [FlutterEngine] instance.
   *
   *
   * Relevant resources that this `FlutterPlugin` may need are provided via the `binding`. The `binding` may be cached and referenced until [.onDetachedFromEngine]
   * is invoked and returns.
   */

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    setupChannel(binding.binaryMessenger)
  }

  /**
   * This `FlutterPlugin` has been removed from a [FlutterEngine] instance.
   *
   *
   * The `binding` passed to this method is the same instance that was passed in [ ][.onAttachedToEngine]. It is provided again in this method as a convenience. The `binding` may be referenced during the execution of this method, but it must not be cached or referenced after
   * this method returns.
   *
   *
   * `FlutterPlugin`s should release all resources in this method.
   */

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    unregisterReceiver()
  }

  /**
   * This `ActivityAware` [FlutterPlugin] is now associated with an [Activity].
   *
   *
   * This method can be invoked in 1 of 2 situations:
   *
   *
   *  * This `ActivityAware` [FlutterPlugin] was
   * just added to a [FlutterEngine] that was already
   * connected to a running [Activity].
   *  * This `ActivityAware` [FlutterPlugin] was
   * already added to a [FlutterEngine] and that [       ] was just connected to an [       ].
   *
   *
   *
   * The given [ActivityPluginBinding] contains [Activity]-related
   * references that an `ActivityAware` [ ] may require, such as a reference to the
   * actual [Activity] in question. The [ActivityPluginBinding] may be
   * referenced until either [.onDetachedFromActivityForConfigChanges] or [ ][.onDetachedFromActivity] is invoked. At the conclusion of either of those methods, the
   * binding is no longer valid. Clear any references to the binding or its resources, and do not
   * invoke any further methods on the binding or its resources.
   */

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
    binding.addActivityResultListener(activityResultListener)
  }

  /**
   * The [Activity] that was attached and made available in [.onAttachedToActivity]
   * has been detached from this `ActivityAware`'s [FlutterEngine] for the purpose of processing a
   * configuration change.
   *
   *
   * By the end of this method, the [Activity] that was made available in
   * [.onAttachedToActivity] is no longer valid. Any references to the associated [ ] or [ActivityPluginBinding] should be cleared.
   *
   *
   * This method should be quickly followed by [ ][.onReattachedToActivityForConfigChanges], which signifies that a new [Activity] has
   * been created with the new configuration options. That method provides a new [ActivityPluginBinding], which
   * references the newly created and associated [Activity].
   *
   *
   * Any `Lifecycle` listeners that were registered in [ ][.onAttachedToActivity] should be deregistered here to avoid a possible memory leak and
   * other side effects.
   */

  override fun onDetachedFromActivityForConfigChanges() {
    unregisterReceiver()
  }

  /**
   * This plugin and its [FlutterEngine] have been re-attached to an [Activity] after the [Activity]
   * was recreated to handle configuration changes.
   *
   *
   * `binding` includes a reference to the new instance of the [ ]. `binding` and its references may be cached and used from now until either [ ][.onDetachedFromActivityForConfigChanges] or [.onDetachedFromActivity] is invoked. At the conclusion of
   * either of those methods, the binding is no longer valid. Clear any references to the binding or its resources,
   * and do not invoke any further methods on the binding or its resources.
   */

  override fun onReattachedToActivityForConfigChanges( binding: ActivityPluginBinding) {
    activity = binding.activity
    binding.addActivityResultListener(activityResultListener)
  }

  /**
   * This plugin has been detached from an [Activity].
   *
   *
   * Detachment can occur for a number of reasons.
   *
   *
   *  * The app is no longer visible and the [Activity] instance has been
   * destroyed.
   *  * The [FlutterEngine] that this plugin is connected to
   * has been detached from its [FlutterView].
   *  * This `ActivityAware` plugin has been removed from its [       ].
   *
   *
   *
   * By the end of this method, the [Activity] that was made available in [ ][.onAttachedToActivity] is no longer valid. Any references to the
   * associated [Activity] or [ActivityPluginBinding] should be cleared.
   *
   *
   * Any `Lifecycle` listeners that were registered in [ ][.onAttachedToActivity] or [ ][.onReattachedToActivityForConfigChanges] should be deregistered here to
   * avoid a possible memory leak and other side effects.
   */

  override fun onDetachedFromActivity() {
    unregisterReceiver()
  }

  class SmsBroadcastReceiver(
    plugin: WeakReference<OtpPinFieldPlugin>,
    smsCodeRegexPattern: String
  ) :
    BroadcastReceiver() {
    val plugin: WeakReference<OtpPinFieldPlugin>
    val smsCodeRegexPattern: String

    init {
      this.plugin = plugin
      this.smsCodeRegexPattern = smsCodeRegexPattern
    }

    override fun onReceive(context: Context?, intent: Intent) {
      if (SmsRetriever.SMS_RETRIEVED_ACTION == intent.action) {
        if (plugin.get() == null) {
          return
        } else {
//          plugin.get()!!.activity?.unregisterReceiver(this)
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
            }catch (e:java.lang.Exception){
              e.printStackTrace();
            }
          }
        }
      }
    }
  }

  companion object {
    private const val PHONE_HINT_REQUEST = 1112
    private const val channelName = "otp_pin_field"

    /**
     * Plugin registration.
     */
    fun registerWith(registrar: PluginRegistry.Registrar) {
      OtpPinFieldPlugin(registrar)
    }
  }
}