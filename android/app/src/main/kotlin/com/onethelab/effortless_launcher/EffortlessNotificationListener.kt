package com.onethelab.effortless_launcher

import android.app.Notification
import android.os.Handler
import android.os.Looper
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import io.flutter.plugin.common.EventChannel

class EffortlessNotificationListener : NotificationListenerService() {

    companion object {
        private val counts = mutableMapOf<String, Int>()
        private val mainHandler = Handler(Looper.getMainLooper())

        @Volatile
        var sink: EventChannel.EventSink? = null

        fun snapshot(): Map<String, Int> = synchronized(counts) { counts.toMap() }

        private fun emit() {
            val snapshot = snapshot()
            mainHandler.post {
                sink?.success(snapshot)
            }
        }

        internal fun replaceCounts(next: Map<String, Int>) {
            synchronized(counts) {
                counts.clear()
                counts.putAll(next)
            }
            emit()
        }
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        recompute()
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        replaceCounts(emptyMap())
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        recompute()
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        recompute()
    }

    private fun recompute() {
        try {
            val active = activeNotifications ?: return
            val next = mutableMapOf<String, Int>()
            for (sbn in active) {
                val n = sbn.notification ?: continue
                val flags = n.flags
                if (flags and Notification.FLAG_ONGOING_EVENT != 0) continue
                if (flags and Notification.FLAG_FOREGROUND_SERVICE != 0) continue
                if (flags and Notification.FLAG_GROUP_SUMMARY != 0) continue
                if (sbn.isOngoing) continue
                val pkg = sbn.packageName ?: continue
                next[pkg] = (next[pkg] ?: 0) + 1
            }
            replaceCounts(next)
        } catch (_: SecurityException) {
        } catch (_: Exception) {
        }
    }
}
