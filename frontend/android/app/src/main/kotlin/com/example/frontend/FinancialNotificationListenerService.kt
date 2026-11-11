package com.example.frontend

import android.app.Notification
import android.content.Intent
import android.os.Bundle
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

/**
 * Service observing financial payment and transaction alerts on Android.
 * Operates strictly with explicit user authorization granted via Android Notification Access Settings.
 * Filters strictly for financial keywords (UPI, credited, debited, paid, bank, a/c, INR, Rs)
 * and disallows logging or transmission of personal non-financial notifications.
 */
class FinancialNotificationListenerService : NotificationListenerService() {

    companion object {
        private const val TAG = "FinancialNotification"
        var notificationCallback: ((Map<String, Any?>) -> Unit)? = null

        // Financial filtering keywords for Indian merchant transactions
        private val FINANCIAL_KEYWORDS = setOf(
            "credited", "debited", "paid to", "received from", "upi",
            "vpa", "bank", "a/c", "inr", "rs.", "txn", "ref no", "imps", "neft"
        )
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        if (sbn == null) return

        val packageName = sbn.packageName ?: return
        val extras = sbn.notification.extras ?: return

        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""
        val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString() ?: text

        val fullText = "$title $bigText".trim()
        val lowerText = fullText.lowercase()

        // Strict financial relevance filter
        val isFinancial = FINANCIAL_KEYWORDS.any { keyword -> lowerText.contains(keyword) }
        if (!isFinancial) {
            return
        }

        val timestamp = sbn.postTime
        val notificationData = mapOf(
            "packageName" to packageName,
            "title" to title,
            "text" to bigText,
            "timestamp" to timestamp
        )

        Log.d(TAG, "Financial notification candidate observed from: $packageName")
        notificationCallback?.invoke(notificationData)
    }
}
