package com.example.billyalarm

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.util.Log
import org.json.JSONArray

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            try {
                val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val raw = prefs.getString("minute_items", "[]") ?: "[]"
                val arr = JSONArray(raw)
                for (i in 0 until arr.length()) {
                    val obj = arr.getJSONObject(i)
                    val minute = obj.getInt("minute")
                    val idBase = obj.getInt("idBase")
                    val uri = if (obj.has("ringtoneUri")) obj.getString("ringtoneUri") else ""
                    // schedule next occurrence for each hour 0..23 at the configured minute
                    for (h in 0..23) {
                        try {
                            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                            val alarmIntent = Intent(context, AlarmReceiver::class.java)
                            alarmIntent.putExtra("uri", uri)
                            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE else PendingIntent.FLAG_UPDATE_CURRENT
                            val pending = PendingIntent.getBroadcast(context, idBase + h, alarmIntent, flags)
                            val timeMillis = System.currentTimeMillis() + ((h * 60L + minute) * 60L * 1000L)
                            try {
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                    am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, timeMillis, pending)
                                } else {
                                    am.setExact(AlarmManager.RTC_WAKEUP, timeMillis, pending)
                                }
                                Log.d("BootReceiver", "Scheduled alarm id=${idBase + h} at $timeMillis")
                            } catch (e: SecurityException) {
                                Log.w("BootReceiver", "Exact alarm failed for id=${idBase + h}, falling back to setAndAllowWhileIdle")
                                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, timeMillis, pending)
                                Log.d("BootReceiver", "Scheduled (fallback) alarm id=${idBase + h} at $timeMillis")
                            }
                        } catch (e: Exception) {
                            Log.e("BootReceiver", "schedule failed", e)
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e("BootReceiver", "reschedule failed", e)
            }
        }
    }
}
