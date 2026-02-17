package com.example.billyalarm

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.*

class MainActivity : FlutterActivity() {
	private var ringtone: Ringtone? = null
	private var wakeLock: PowerManager.WakeLock? = null

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "billyalarm/native").setMethodCallHandler { call, result ->
			when (call.method) {
				"getRingtones" -> {
					try {
						val rm = RingtoneManager(this)
						rm.setType(RingtoneManager.TYPE_RINGTONE)
						val cursor = rm.cursor
						val list = ArrayList<Map<String, String>>()
						if (cursor != null) {
							while (cursor.moveToNext()) {
								val title = cursor.getString(RingtoneManager.TITLE_COLUMN_INDEX)
								val uri: Uri? = rm.getRingtoneUri(cursor.position)
								list.add(mapOf("title" to (title ?: ""), "uri" to (uri?.toString() ?: "")))
							}
						}
						result.success(list)
					} catch (e: Exception) {
						result.error("ERR", e.message, null)
					}
				}
				"playRingtone" -> {
					try {
						val uriStr = call.argument<String>("uri") ?: ""
						playRingtone(uriStr)
						result.success(true)
					} catch (e: Exception) {
						result.error("ERR", e.message, null)
					}
				}
				"stopRingtone" -> {
					try {
						stopRingtone()
						result.success(true)
					} catch (e: Exception) {
						result.error("ERR", e.message, null)
					}
				}
				"scheduleAlarm" -> {
					try {
						val id = call.argument<Int>("id") ?: 0
						val time = call.argument<Long>("time") ?: System.currentTimeMillis()
						val uri = call.argument<String>("uri") ?: ""
						scheduleExact(id, time, uri)
						result.success(true)
					} catch (e: Exception) {
						result.error("ERR", e.message, null)
					}
				}
				"ensureExactAlarmPermission" -> {
					try {
						val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
						if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
							if (!am.canScheduleExactAlarms()) {
								val i = Intent("android.app.action.REQUEST_SCHEDULE_EXACT_ALARM")
								startActivity(i)
							}
						}
						result.success(true)
					} catch (e: Exception) {
						result.error("ERR", e.message, null)
					}
				}
				"cancelAlarm" -> {
					try {
						val id = call.argument<Int>("id") ?: 0
						cancelScheduled(id)
						result.success(true)
					} catch (e: Exception) {
						result.error("ERR", e.message, null)
					}
				}
				else -> result.notImplemented()
			}
		}
	}

	private fun playRingtone(uriStr: String) {
		try {
			val uri: Uri = if (uriStr.isEmpty()) RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM) else Uri.parse(uriStr)
			ringtone = RingtoneManager.getRingtone(this, uri)
			val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
			wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "billyalarm:alarm")
			wakeLock?.acquire(10 * 60 * 1000L /*10 minutes*/)
			ringtone?.play()
		} catch (_: Exception) {
		}
	}

	private fun stopRingtone() {
		try {
			ringtone?.stop()
		} catch (_: Exception) {
		}
		try {
			if (wakeLock?.isHeld == true) wakeLock?.release()
		} catch (_: Exception) {
		}
	}

	private fun scheduleExact(id: Int, timeMillis: Long, uriStr: String) {
		try {
			val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
			val intent = Intent(this, AlarmReceiver::class.java)
			intent.putExtra("uri", uriStr)
			val pending = PendingIntent.getBroadcast(this, id, intent, PendingIntent.FLAG_UPDATE_CURRENT or getMutableFlag())
			
			try {
				// Try exact alarm first (requires SCHEDULE_EXACT_ALARM permission)
				if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
					am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, timeMillis, pending)
					Log.d("MainActivity", "setExactAndAllowWhileIdle scheduled id=$id")
				} else {
					am.setExact(AlarmManager.RTC_WAKEUP, timeMillis, pending)
					Log.d("MainActivity", "setExact scheduled id=$id")
				}
			} catch (e: SecurityException) {
				// Fallback: use setAndAllowWhileIdle (no special permission needed)
				Log.w("MainActivity", "Exact alarm failed, falling back to setAndAllowWhileIdle: ${e.message}")
				am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, timeMillis, pending)
				Log.d("MainActivity", "setAndAllowWhileIdle scheduled id=$id")
			}
		} catch (e: Exception) {
			Log.e("MainActivity", "schedule failed completely", e)
		}
	}

	private fun cancelScheduled(id: Int) {
		try {
			val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
			val intent = Intent(this, AlarmReceiver::class.java)
			val pending = PendingIntent.getBroadcast(this, id, intent, PendingIntent.FLAG_NO_CREATE or getMutableFlag())
			if (pending != null) am.cancel(pending)
		} catch (e: Exception) {
			Log.e("MainActivity", "cancel failed", e)
		}
	}

	private fun getMutableFlag(): Int {
		return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0
	}
}
