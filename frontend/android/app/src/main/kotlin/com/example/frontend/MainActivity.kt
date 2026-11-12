package com.example.frontend

import android.Manifest
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

class MainActivity : FlutterActivity(), PluginRegistry.RequestPermissionsResultListener {
    private val CHANNEL = "com.meravyapar.ai/capture"
    private var methodChannel: MethodChannel? = null

    private val PERMISSION_REQ_RECORD_AUDIO = 1001
    private val PERMISSION_REQ_POST_NOTIFICATIONS = 1002

    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                // 1. Notification Listener Access (Special App Access Settings)
                "checkPermission" -> {
                    val feature = call.argument<String>("feature") ?: "NOTIFICATION_LISTENER"
                    when (feature) {
                        "NOTIFICATION_LISTENER" -> result.success(isNotificationServiceEnabled())
                        "RECORD_AUDIO" -> {
                            val granted = ContextCompat.checkSelfPermission(
                                this,
                                Manifest.permission.RECORD_AUDIO
                            ) == PackageManager.PERMISSION_GRANTED
                            result.success(granted)
                        }
                        "POST_NOTIFICATIONS" -> {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                                val granted = ContextCompat.checkSelfPermission(
                                    this,
                                    Manifest.permission.POST_NOTIFICATIONS
                                ) == PackageManager.PERMISSION_GRANTED
                                result.success(granted)
                            } else {
                                result.success(true)
                            }
                        }
                        "INTERNET" -> result.success(isInternetConnected())
                        else -> result.success(false)
                    }
                }

                "requestPermission" -> {
                    val feature = call.argument<String>("feature") ?: "NOTIFICATION_LISTENER"
                    when (feature) {
                        "NOTIFICATION_LISTENER" -> {
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
                        "RECORD_AUDIO" -> {
                            val alreadyGranted = ContextCompat.checkSelfPermission(
                                this,
                                Manifest.permission.RECORD_AUDIO
                            ) == PackageManager.PERMISSION_GRANTED
                            if (alreadyGranted) {
                                result.success("GRANTED")
                            } else {
                                pendingPermissionResult = result
                                ActivityCompat.requestPermissions(
                                    this,
                                    arrayOf(Manifest.permission.RECORD_AUDIO),
                                    PERMISSION_REQ_RECORD_AUDIO
                                )
                            }
                        }
                        "POST_NOTIFICATIONS" -> {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                                val alreadyGranted = ContextCompat.checkSelfPermission(
                                    this,
                                    Manifest.permission.POST_NOTIFICATIONS
                                ) == PackageManager.PERMISSION_GRANTED
                                if (alreadyGranted) {
                                    result.success("GRANTED")
                                } else {
                                    pendingPermissionResult = result
                                    ActivityCompat.requestPermissions(
                                        this,
                                        arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                                        PERMISSION_REQ_POST_NOTIFICATIONS
                                    )
                                }
                            } else {
                                result.success("GRANTED")
                            }
                        }
                        else -> result.success("DENIED")
                    }
                }

                "getDetailedPermissionStatus" -> {
                    val micStatus = if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) {
                        "GRANTED"
                    } else if (ActivityCompat.shouldShowRequestPermissionRationale(this, Manifest.permission.RECORD_AUDIO)) {
                        "DENIED"
                    } else {
                        "NOT_REQUESTED"
                    }

                    val postNotifStatus = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) {
                            "GRANTED"
                        } else if (ActivityCompat.shouldShowRequestPermissionRationale(this, Manifest.permission.POST_NOTIFICATIONS)) {
                            "DENIED"
                        } else {
                            "NOT_REQUESTED"
                        }
                    } else {
                        "GRANTED"
                    }

                    val statusMap = mapOf(
                        "RECORD_AUDIO" to micStatus,
                        "NOTIFICATION_LISTENER" to if (isNotificationServiceEnabled()) "GRANTED" else "DENIED",
                        "POST_NOTIFICATIONS" to postNotifStatus,
                        "INTERNET" to if (isInternetConnected()) "CONNECTED" else "DISCONNECTED"
                    )
                    result.success(statusMap)
                }

                "openAppSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = Uri.fromParts("package", packageName, null)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ACTIVITY_NOT_FOUND", e.message, null)
                    }
                }

                "openNotificationListenerSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS).apply {
                            putExtra(
                                Settings.EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME,
                                ComponentName(packageName, FinancialNotificationListenerService::class.java.name).flattenToString()
                            )
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                            result.success(true)
                        } catch (e2: Exception) {
                            result.error("ACTIVITY_NOT_FOUND", e2.message, null)
                        }
                    }
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

    private fun isInternetConnected(): Boolean {
        val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager ?: return false
        val network = cm.activeNetwork ?: return false
        val caps = cm.getNetworkCapabilities(network) ?: return false
        return caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        val res = pendingPermissionResult
        pendingPermissionResult = null

        if (res == null) return false

        if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            res.success("GRANTED")
        } else {
            val permission = if (permissions.isNotEmpty()) permissions[0] else ""
            val showRationale = ActivityCompat.shouldShowRequestPermissionRationale(this, permission)
            if (!showRationale) {
                res.success("PERMANENTLY_DENIED")
            } else {
                res.success("DENIED")
            }
        }
        return true
    }
}
