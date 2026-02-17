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
import android.content.ActivityNotFoundException
import android.provider.Settings
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
				"canScheduleExactAlarms" -> {
					try {
						val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
						if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
							result.success(am.canScheduleExactAlarms())
						} else {
							result.success(true)
						}
					} catch (e: Exception) {
						result.error("ERR", e.message, null)
					}
				}
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
			// Ensure alignment to exact minute start: HH:MM:00.000
			val alignedTimeMillis = (timeMillis / 60000L) * 60000L
			val intent = Intent(this, AlarmReceiver::class.java)
			intent.putExtra("uri", uriStr)
			// include the scheduled target time so the receiver can align playback precisely
			intent.putExtra("scheduledTime", alignedTimeMillis)
			val pending = PendingIntent.getBroadcast(this, id, intent, PendingIntent.FLAG_UPDATE_CURRENT or getMutableFlag())

			// If the app cannot schedule exact alarms (Android 12+), prompt the user and use fallback
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
				if (!am.canScheduleExactAlarms()) {
					Log.w("MainActivity", "⚠ App cannot schedule exact alarms; prompting user to allow exact alarms")
					try {
						val i = Intent("android.app.action.REQUEST_SCHEDULE_EXACT_ALARM")
						i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
						startActivity(i)
					} catch (e: ActivityNotFoundException) {
						Log.w("MainActivity", "exact alarm permission activity not found, falling back to app settings", e)
						try {
							val pi = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
							pi.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
							startActivity(pi)
						} catch (e2: Exception) {
							Log.w("MainActivity", "failed to open app settings fallback", e2)
						}
					} catch (e: Exception) {
						Log.w("MainActivity", "failed to launch exact alarm permission intent", e)
					}
					// schedule fallback so alarm still fires (may be delayed by OS)
					am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, alignedTimeMillis, pending)
					val dateStr = java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS").format(java.util.Date(alignedTimeMillis))
					Log.d("MainActivity", "✓ Scheduled FALLBACK id=$id time=$dateStr (${alignedTimeMillis}ms)")
					return
				}
			}
			
			try {
				// Use exact time aligned to minute start
				if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
					am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, alignedTimeMillis, pending)
					val dateStr = java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS").format(java.util.Date(alignedTimeMillis))
					Log.d("MainActivity", "✓ Scheduled EXACT id=$id time=$dateStr (${alignedTimeMillis}ms)")
				} else {
					am.setExact(AlarmManager.RTC_WAKEUP, alignedTimeMillis, pending)
					val dateStr = java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS").format(java.util.Date(alignedTimeMillis))
					Log.d("MainActivity", "✓ Scheduled EXACT id=$id time=$dateStr (${alignedTimeMillis}ms)")
				}
			} catch (e: SecurityException) {
				// Fallback: use setAndAllowWhileIdle (no special permission needed)
				Log.w("MainActivity", "⚠ Permission denied for exact alarm, falling back to setAndAllowWhileIdle")
				am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, alignedTimeMillis, pending)
				val dateStr = java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS").format(java.util.Date(alignedTimeMillis))
				Log.d("MainActivity", "✓ Scheduled FALLBACK id=$id time=$dateStr (${alignedTimeMillis}ms)")
			}
		} catch (e: Exception) {
			Log.e("MainActivity", "✗ Schedule failed: ${e.message}", e)
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
