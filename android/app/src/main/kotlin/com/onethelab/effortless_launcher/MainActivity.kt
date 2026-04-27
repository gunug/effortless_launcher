package com.onethelab.effortless_launcher

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val packageEventsChannel = "com.onethelab.effortless_launcher/package_events"
    private val usageStatsChannel = "com.onethelab.effortless_launcher/usage_stats"
    private val notificationChannel = "com.onethelab.effortless_launcher/notifications"
    private val notificationCountsChannel = "com.onethelab.effortless_launcher/notification_counts"

    private var packageEventSink: EventChannel.EventSink? = null
    private var packageReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        EventChannel(messenger, packageEventsChannel)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    packageEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    packageEventSink = null
                }
            })

        EventChannel(messenger, notificationCountsChannel)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    EffortlessNotificationListener.sink = events
                    events?.success(EffortlessNotificationListener.snapshot())
                }

                override fun onCancel(arguments: Any?) {
                    EffortlessNotificationListener.sink = null
                }
            })

        MethodChannel(messenger, usageStatsChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasPermission" -> result.success(hasUsageStatsPermission())
                "openSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "queryEvents" -> {
                    val days = (call.argument<Int>("days") ?: 30).coerceIn(1, 90)
                    val maxPerPackage = (call.argument<Int>("maxPerPackage") ?: 50).coerceIn(1, 500)
                    result.success(queryUsageEvents(days, maxPerPackage))
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(messenger, notificationChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasPermission" -> result.success(isNotificationListenerEnabled())
                "openSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "rebind" -> {
                    rebindNotificationListener()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        registerPackageReceiver()
    }

    override fun onDestroy() {
        unregisterPackageReceiver()
        super.onDestroy()
    }

    private fun registerPackageReceiver() {
        if (packageReceiver != null) return
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                val action = intent?.action ?: return
                val pkg = intent.data?.schemeSpecificPart ?: return
                val replacing = intent.getBooleanExtra(Intent.EXTRA_REPLACING, false)
                val payload = mapOf(
                    "action" to action,
                    "package" to pkg,
                    "replacing" to replacing,
                )
                runOnUiThread { packageEventSink?.success(payload) }
            }
        }
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_PACKAGE_ADDED)
            addAction(Intent.ACTION_PACKAGE_REMOVED)
            addAction(Intent.ACTION_PACKAGE_REPLACED)
            addAction(Intent.ACTION_PACKAGE_FULLY_REMOVED)
            addDataScheme("package")
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(receiver, filter)
        }
        packageReceiver = receiver
    }

    private fun unregisterPackageReceiver() {
        val r = packageReceiver ?: return
        try {
            unregisterReceiver(r)
        } catch (_: IllegalArgumentException) {
        }
        packageReceiver = null
    }

    private fun hasUsageStatsPermission(): Boolean {
        return try {
            val appOps = getSystemService(APP_OPS_SERVICE) as AppOpsManager
            val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                appOps.unsafeCheckOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    Process.myUid(),
                    packageName
                )
            } else {
                @Suppress("DEPRECATION")
                appOps.checkOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    Process.myUid(),
                    packageName
                )
            }
            mode == AppOpsManager.MODE_ALLOWED
        } catch (e: Exception) {
            false
        }
    }

    private fun queryUsageEvents(daysBack: Int, maxPerPackage: Int): Map<String, List<Long>> {
        if (!hasUsageStatsPermission()) return emptyMap()
        val usm = try {
            getSystemService(USAGE_STATS_SERVICE) as? UsageStatsManager
        } catch (e: Exception) {
            null
        } ?: return emptyMap()
        val end = System.currentTimeMillis()
        val start = end - daysBack.toLong() * 24L * 60L * 60L * 1000L
        val events = try {
            usm.queryEvents(start, end)
        } catch (e: Exception) {
            return emptyMap()
        } ?: return emptyMap()
        val map = HashMap<String, ArrayList<Long>>()
        val event = UsageEvents.Event()
        while (events.hasNextEvent()) {
            try {
                events.getNextEvent(event)
            } catch (e: Exception) {
                break
            }
            val type = event.eventType
            val isLaunch = type == UsageEvents.Event.MOVE_TO_FOREGROUND ||
                (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
                    type == UsageEvents.Event.ACTIVITY_RESUMED)
            if (!isLaunch) continue
            val pkg = event.packageName ?: continue
            val list = map.getOrPut(pkg) { ArrayList() }
            list.add(event.timeStamp)
        }
        val result = HashMap<String, List<Long>>(map.size)
        for ((pkg, list) in map) {
            list.sortDescending()
            result[pkg] = if (list.size > maxPerPackage) list.subList(0, maxPerPackage).toList() else list
        }
        return result
    }

    private fun isNotificationListenerEnabled(): Boolean {
        return try {
            val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
                ?: return false
            flat.split(":").any { entry ->
                ComponentName.unflattenFromString(entry)?.packageName == packageName
            }
        } catch (e: Exception) {
            false
        }
    }

    private fun rebindNotificationListener() {
        try {
            val component = ComponentName(this, EffortlessNotificationListener::class.java)
            val pm = packageManager
            pm.setComponentEnabledSetting(
                component,
                android.content.pm.PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                android.content.pm.PackageManager.DONT_KILL_APP
            )
            pm.setComponentEnabledSetting(
                component,
                android.content.pm.PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                android.content.pm.PackageManager.DONT_KILL_APP
            )
        } catch (_: Exception) {
        }
    }
}
