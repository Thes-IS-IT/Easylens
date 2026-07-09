package com.easylens.easylens

import android.Manifest
import android.content.pm.PackageManager
import android.telephony.SmsManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.easylens.easylens/sms"
    private var pendingResult: MethodChannel.Result? = null
    private var pendingTo: String? = null
    private var pendingMessage: String? = null
    private val SMS_PERMISSION_CODE = 101

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "sendSMS") {
                val to = call.argument<String>("to")
                val message = call.argument<String>("message")

                if (to == null || message == null) {
                    result.error("INVALID_ARGUMENTS", "Recipient or message is null", null)
                    return@setMethodCallHandler
                }

                if (ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) == PackageManager.PERMISSION_GRANTED) {
                    sendDirectSms(to, message, result)
                } else {
                    pendingResult = result
                    pendingTo = to
                    pendingMessage = message
                    ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.SEND_SMS), SMS_PERMISSION_CODE)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun sendDirectSms(to: String, message: String, result: MethodChannel.Result) {
        try {
            val smsManager: SmsManager = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                this.getSystemService(SmsManager::class.java)
            } else {
                @Suppress("DEPRECATION")
                SmsManager.getDefault()
            }
            
            val parts = smsManager.divideMessage(message)
            if (parts.size > 1) {
                smsManager.sendMultipartTextMessage(to, null, parts, null, null)
            } else {
                smsManager.sendTextMessage(to, null, message, null, null)
            }
            result.success(true)
        } catch (e: Exception) {
            result.error("SMS_SEND_FAILED", e.localizedMessage, null)
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == SMS_PERMISSION_CODE) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                val to = pendingTo
                val message = pendingMessage
                val result = pendingResult
                if (to != null && message != null && result != null) {
                    sendDirectSms(to, message, result)
                }
            } else {
                pendingResult?.error("PERMISSION_DENIED", "SEND_SMS permission denied", null)
            }
            pendingResult = null
            pendingTo = null
            pendingMessage = null
        }
    }
}
