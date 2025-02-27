package com.shivam.otp_pin_field

import android.annotation.SuppressLint
import android.content.Context
import android.content.ContextWrapper
import android.content.pm.PackageManager
import android.content.pm.Signature
import android.os.Build
import android.util.Base64
import android.util.Log
import java.nio.charset.Charset
import java.security.MessageDigest
import java.security.NoSuchAlgorithmException
import java.util.*


/**
 * This is a helper class to generate your message hash to be included in your SMS message.
 *
 *
 * Without the correct hash, your app won't receive the message callback. This only needs to be
 * generated once per app and stored. Then you can remove this helper class from your code.
 */
class AppSignatureHelper(context: Context?) : ContextWrapper(context) {
    /**
     * Get first app signature.
     */
    val appSignature: String
        get() {
            val appSignatures: ArrayList<String> = appSignatures
            return if (appSignatures.isNotEmpty()) {
                appSignatures[0]
            } else {
                "NA"
            }
        }// Get all package signatures for the current package

    // For each signature create a compatible hash
    /**
     * Get all the app signatures for the current package
     *
     * @return
     */
    @get:SuppressLint("PackageManagerGetSignatures")
    val appSignatures: ArrayList<String>
        get() {
            val appCodes: ArrayList<String> = ArrayList<String>()
            try {
                // Get all package signatures for the current package
                val packageName: String = packageName
                val packageManager: PackageManager = packageManager
                val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    packageManager.getPackageInfo(
                        packageName,
                        PackageManager.GET_SIGNING_CERTIFICATES
                    ).signingInfo?.apkContentsSigners?.let { Array(it.size) { i -> it[i] } } ?: emptyArray()
                } else {
                    @Suppress("DEPRECATION")
                    packageManager.getPackageInfo(
                        packageName,
                        PackageManager.GET_SIGNATURES
                    ).signatures
                }

                // Updated this part to handle null safety
                signatures?.forEach { signature ->
                    val hash = hash(packageName, signature.toCharsString())
                    if (hash != null) {
                        appCodes.add(String.format("%s", hash))
                    }
                }
            } catch (e: PackageManager.NameNotFoundException) {
                Log.e(TAG, "Unable to find package to obtain hash.", e)
            }
            return appCodes
        }

    companion object {
        val TAG: String = "shivam check"
        private const val HASH_TYPE = "SHA-256"
        const val NUM_HASHED_BYTES = 9
        const val NUM_BASE64_CHAR = 11
        private fun hash(packageName: String, signature: String): String? {
            val appInfo = "$packageName $signature"
            try {
                val messageDigest: MessageDigest = MessageDigest.getInstance(HASH_TYPE)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
                    messageDigest.update(appInfo.toByteArray(java.nio.charset.StandardCharsets.UTF_8))
                } else {
                    messageDigest.update(appInfo.toByteArray(Charset.forName("UTF-8")))
                }
                var hashSignature: ByteArray = messageDigest.digest()

                // truncated into NUM_HASHED_BYTES
                hashSignature = hashSignature.copyOfRange(0, NUM_HASHED_BYTES)
                // encode into Base64
                var base64Hash: String =
                    Base64.encodeToString(hashSignature, Base64.NO_PADDING or Base64.NO_WRAP)
                base64Hash = base64Hash.substring(0, NUM_BASE64_CHAR)
                Log.d(TAG, String.format("pkg: %s -- hash: %s", packageName, base64Hash))
                return base64Hash
            } catch (e: NoSuchAlgorithmException) {
                Log.e(TAG, "hash:NoSuchAlgorithm", e)
            }
            return null
        }
    }
}
