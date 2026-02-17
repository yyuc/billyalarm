package com.example.billyalarm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.util.Log

class AlarmReceiver : BroadcastReceiver() {
    private var ringtone: Ringtone? = null
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onReceive(context: Context, intent: Intent) {
        val uriStr = intent.getStringExtra("uri") ?: ""
        val scheduledTime = intent.getLongExtra("scheduledTime", 0L)
        val now = System.currentTimeMillis()
        val nowStr = java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS").format(java.util.Date(now))
        Log.d("AlarmReceiver", "🔔 onReceive at $nowStr (id=${intent.action}) uri=${if(uriStr.isEmpty()) "DEFAULT" else uriStr.take(50)} scheduled=$scheduledTime")
        try {
            val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "billyalarm:alarm")
            wakeLock?.acquire(10 * 60 * 1000L)

            // Prepare a runnable that will initialize audio attributes and start playback on main thread
            val handler = android.os.Handler(android.os.Looper.getMainLooper())
            val playRunnable = Runnable {
                try {
                    val uri: Uri = if (uriStr.isEmpty()) RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM) else Uri.parse(uriStr)
                    ringtone = RingtoneManager.getRingtone(context, uri)
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            val attrs = android.media.AudioAttributes.Builder()
                                .setUsage(android.media.AudioAttributes.USAGE_ALARM)
                                .setContentType(android.media.AudioAttributes.CONTENT_TYPE_MUSIC)
                                .build()
                            ringtone?.audioAttributes = attrs
                        } else {
                            @Suppress("DEPRECATION")
                            ringtone?.setStreamType(AudioManager.STREAM_ALARM)
                        }
                    } catch (e: Exception) {
                        Log.w("AlarmReceiver", "set stream failed", e)
                    }

                    val am = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
                    try {
                        @Suppress("DEPRECATION")
                        am.requestAudioFocus(null, AudioManager.STREAM_ALARM, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                    } catch (e: Exception) {
                        Log.w("AlarmReceiver", "requestAudioFocus failed", e)
                    }

                    ringtone?.play()
                    val playTime = java.text.SimpleDateFormat("HH:mm:ss.SSS").format(java.util.Date(System.currentTimeMillis()))
                    Log.d("AlarmReceiver", "🔊 Ringtone playing at $playTime")
                } catch (e: Exception) {
                    Log.e("AlarmReceiver", "play failed", e)
                }
            }

            // If scheduledTime is provided, wait until that moment (up to 10s) to improve precision
            if (scheduledTime > 0L) {
                val delta = scheduledTime - System.currentTimeMillis()
                if (delta > 0 && delta <= 10_000L) {
                    Log.d("AlarmReceiver", "Delaying playback by ${delta}ms to hit exact boundary")
                    Thread {
                        try {
                            Thread.sleep(delta)
                        } catch (_: InterruptedException) {}
                        handler.post(playRunnable)
                    }.start()
                } else {
                    // too late or too far in future, just play immediately
                    handler.post(playRunnable)
                }
            } else {
                handler.post(playRunnable)
            }
        } catch (e: Exception) {
            Log.e("AlarmReceiver", "play failed", e)
        }
    }
}
