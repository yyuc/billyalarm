package com.example.billyalarm

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

class TestSchedulerReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        try {
            val id = intent.getIntExtra("id", 0)
            val time = intent.getLongExtra("time", System.currentTimeMillis())
            val uri = intent.getStringExtra("uri") ?: ""
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val alarmIntent = Intent(context, AlarmReceiver::class.java)
            alarmIntent.putExtra("uri", uri)
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE else PendingIntent.FLAG_UPDATE_CURRENT
            val pending = PendingIntent.getBroadcast(context, id, alarmIntent, flags)
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, time, pending)
                } else {
                    am.setExact(AlarmManager.RTC_WAKEUP, time, pending)
                }
                Log.d("TestScheduler", "scheduled id=$id time=$time uri=$uri (exact)")
            } catch (se: SecurityException) {
                // Fallback: use setAndAllowWhileIdle which doesn't require special permission
                Log.w("TestScheduler", "Exact alarm failed, falling back to setAndAllowWhileIdle: ${se.message}")
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, time, pending)
                Log.d("TestScheduler", "scheduled id=$id time=$time uri=$uri (fallback)")
            }
        } catch (e: Exception) {
            Log.e("TestScheduler", "schedule failed", e)
        }
    }
}
