package com.example.frontend

import android.content.ComponentName
import android.content.Intent
import android.provider.Settings
import android.text.TextUtils
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.meravyapar.ai/capture"
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "checkPermission" -> {
                    val isEnabled = isNotificationServiceEnabled()
                    result.success(isEnabled)
                }
                "requestPermission" -> {
                    val isEnabled = isNotificationServiceEnabled()
                    if (!isEnabled) {
                        val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS).apply {
                            putExtra(
                                Settings.EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME,
                                ComponentName(packageName, FinancialNotificationListenerService::class.java.name).flattenToString()
                            )
                        }
                        try {
                            startActivity(intent)
                        } catch (e: Exception) {
                            startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                        }
                    }
                    result.success(isEnabled)
                }
                else -> result.notImplemented()
            }
        }

        // Connect notification observer callback to Flutter MethodChannel
        FinancialNotificationListenerService.notificationCallback = { data ->
            runOnUiThread {
                methodChannel?.invokeMethod("onNotificationReceived", data)
            }
        }
    }

    private fun isNotificationServiceEnabled(): Boolean {
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners") ?: return false
        val myComponent = ComponentName(this, FinancialNotificationListenerService::class.java).flattenToString()
        return flat.contains(myComponent)
    }
}
