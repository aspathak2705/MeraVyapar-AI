package com.example.frontend

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.RemoteInput

/**
 * QuickEntryReceiver handles inline RemoteInput actions from Android Notification Shade:
 * - Mera Vyapar AI — Quick Entry
 * - RemoteInput for transaction amount and description ("1500 from Rahul" or "Expense 450 groceries")
 * - Dispatches verified intent to MainActivity or callbacks to persist via canonical SQLite repository.
 */
class QuickEntryReceiver : BroadcastReceiver() {

    companion object {
        const val TAG = "QuickEntryReceiver"
        const val CHANNEL_ID = "meravyapar_quick_entry"
        const val NOTIFICATION_ID = 4001
        const val CONFIRMATION_NOTIFICATION_ID = 4002

        const val ACTION_ADD_INCOME = "com.meravyapar.ai.ACTION_ADD_INCOME"
        const val ACTION_ADD_EXPENSE = "com.meravyapar.ai.ACTION_ADD_EXPENSE"
        const val ACTION_SUBMIT_QUICK_ENTRY = "com.meravyapar.ai.ACTION_SUBMIT_QUICK_ENTRY"

        const val KEY_TEXT_REPLY = "key_quick_entry_text"
        const val EXTRA_ENTRY_TYPE = "extra_entry_type" // "CREDIT" or "DEBIT"

        var quickEntryCallback: ((Map<String, Any?>) -> Unit)? = null

        fun createNotificationChannel(context: Context) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val name = "Quick Financial Entry"
                val descriptionText = "Persistent notification action for fast daily financial entries"
                val importance = NotificationManager.IMPORTANCE_LOW
                val channel = NotificationChannel(CHANNEL_ID, name, importance).apply {
                    description = descriptionText
                    setShowBadge(false)
                }
                val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                notificationManager.createNotificationChannel(channel)
            }
        }

        fun showQuickEntryNotification(context: Context) {
            createNotificationChannel(context)
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            val remoteInputIncome = RemoteInput.Builder(KEY_TEXT_REPLY)
                .setLabel("Amount & details (e.g. 1500 from Rahul)")
                .build()

            val incomeIntent = Intent(context, QuickEntryReceiver::class.java).apply {
                action = ACTION_SUBMIT_QUICK_ENTRY
                putExtra(EXTRA_ENTRY_TYPE, "CREDIT")
            }
            val incomePendingIntent = PendingIntent.getBroadcast(
                context,
                101,
                incomeIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0)
            )

            val incomeAction = NotificationCompat.Action.Builder(
                android.R.drawable.ic_input_add,
                "+ Add Income",
                incomePendingIntent
            ).addRemoteInput(remoteInputIncome).build()

            val remoteInputExpense = RemoteInput.Builder(KEY_TEXT_REPLY)
                .setLabel("Amount & details (e.g. 450 groceries)")
                .build()

            val expenseIntent = Intent(context, QuickEntryReceiver::class.java).apply {
                action = ACTION_SUBMIT_QUICK_ENTRY
                putExtra(EXTRA_ENTRY_TYPE, "DEBIT")
            }
            val expensePendingIntent = PendingIntent.getBroadcast(
                context,
                102,
                expenseIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0)
            )

            val expenseAction = NotificationCompat.Action.Builder(
                android.R.drawable.ic_delete,
                "- Add Expense",
                expensePendingIntent
            ).addRemoteInput(remoteInputExpense).build()

            val openAppIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val openAppPendingIntent = PendingIntent.getActivity(
                context,
                0,
                openAppIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
            )

            val notification = NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle("Mera Vyapar AI — Quick Entry")
                .setContentText("Pull down to record Income or Expense in seconds")
                .setOngoing(true)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setContentIntent(openAppPendingIntent)
                .addAction(incomeAction)
                .addAction(expenseAction)
                .build()

            notificationManager.notify(NOTIFICATION_ID, notification)
        }

        fun showSuccessConfirmationNotification(context: Context, amountStr: String, type: String) {
            createNotificationChannel(context)
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            val label = if (type == "CREDIT") "Income recorded" else "Expense recorded"
            val symbol = if (type == "CREDIT") "+" else "-"

            val confirmation = NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle("Mera Vyapar AI — Entry Confirmed")
                .setContentText("$label: $symbol ₹$amountStr saved to private ledger")
                .setAutoCancel(true)
                .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                .build()

            notificationManager.notify(CONFIRMATION_NOTIFICATION_ID, confirmation)
            // Re-show persistent quick entry shade
            showQuickEntryNotification(context)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_SUBMIT_QUICK_ENTRY) {
            val bundle = RemoteInput.getResultsFromIntent(intent)
            val inputCharSequence = bundle?.getCharSequence(KEY_TEXT_REPLY)
            val text = inputCharSequence?.toString()?.trim() ?: ""
            val entryType = intent.getStringExtra(EXTRA_ENTRY_TYPE) ?: "CREDIT"

            Log.d(TAG, "Quick entry received from notification shade: '$text', type: $entryType")

            if (text.isNotEmpty()) {
                val payload = mapOf(
                    "text" to text,
                    "type" to entryType,
                    "timestamp" to System.currentTimeMillis()
                )

                if (quickEntryCallback != null) {
                    quickEntryCallback?.invoke(payload)
                } else {
                    // Launch or signal MainActivity if Flutter engine is detached
                    val launchIntent = Intent(context, MainActivity::class.java).apply {
                        action = ACTION_SUBMIT_QUICK_ENTRY
                        putExtra("quick_entry_text", text)
                        putExtra("quick_entry_type", entryType)
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                    }
                    context.startActivity(launchIntent)
                }
            }
        }
    }
}
