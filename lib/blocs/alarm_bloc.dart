import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:billyalarm/blocs/alarm_event.dart';
import 'package:billyalarm/blocs/alarm_state.dart';
import 'package:billyalarm/models/minute_item.dart';

const MethodChannel _native = MethodChannel('billyalarm/native');

class AlarmBloc extends Bloc<AlarmEvent, AlarmState> {
  AlarmBloc() : super(const AlarmInitial()) {
    on<LoadAlarmConfig>(_onLoadAlarmConfig);
    on<SetStartTime>(_onSetStartTime);
    on<SetEndTime>(_onSetEndTime);
    on<SetStartDate>(_onSetStartDate);
    on<SetEndDate>(_onSetEndDate);
    on<ClearDateRange>(_onClearDateRange);
    on<AddMinuteItem>(_onAddMinuteItem);
    on<UpdateMinuteItem>(_onUpdateMinuteItem);
    on<RemoveMinuteItem>(_onRemoveMinuteItem);
    on<ScheduleAlarms>(_onScheduleAlarms);
    on<TestMinuteItem>(_onTestMinuteItem);
  }

  Future<void> _onLoadAlarmConfig(LoadAlarmConfig event, Emitter<AlarmState> emit) async {
    emit(const AlarmLoading());
    try {
      final prefs = await SharedPreferences.getInstance();
      final startHour = prefs.getInt('startHour') ?? 8;
      final startMinute = prefs.getInt('startMinute') ?? 0;
      final endHour = prefs.getInt('endHour') ?? 22;
      final endMinute = prefs.getInt('endMinute') ?? 0;
      
      final startDateStr = prefs.getString('startDate');
      final endDateStr = prefs.getString('endDate');
      final startDate = startDateStr != null ? DateTime.parse(startDateStr) : null;
      final endDate = endDateStr != null ? DateTime.parse(endDateStr) : null;
      
      final raw = prefs.getString('minute_items') ?? '[]';
      final List decoded = jsonDecode(raw);
      final minuteItems = decoded.map((e) => MinuteItem.fromJson(e)).toList();

      // Ensure exact alarm permission on Android 12+
      try {
        await _native.invokeMethod('ensureExactAlarmPermission');
      } catch (_) {}

      emit(AlarmLoaded(
        startHour: startHour,
        startMinute: startMinute,
        endHour: endHour,
        endMinute: endMinute,
        startDate: startDate,
        endDate: endDate,
        minuteItems: minuteItems,
      ));

      // Schedule all alarms
      add(const ScheduleAlarms());
    } catch (e) {
      emit(AlarmError('Failed to load config: $e'));
    }
  }

  Future<void> _onSetStartTime(SetStartTime event, Emitter<AlarmState> emit) async {
    if (state is AlarmLoaded) {
      final current = state as AlarmLoaded;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('startHour', event.hour);
      await prefs.setInt('startMinute', event.minute);
      
      emit(current.copyWith(
        startHour: event.hour,
        startMinute: event.minute,
      ));
      add(const ScheduleAlarms());
    }
  }

  Future<void> _onSetEndTime(SetEndTime event, Emitter<AlarmState> emit) async {
    if (state is AlarmLoaded) {
      final current = state as AlarmLoaded;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('endHour', event.hour);
      await prefs.setInt('endMinute', event.minute);
      
      emit(current.copyWith(
        endHour: event.hour,
        endMinute: event.minute,
      ));
      add(const ScheduleAlarms());
    }
  }

  Future<void> _onSetStartDate(SetStartDate event, Emitter<AlarmState> emit) async {
    if (state is AlarmLoaded) {
      final current = state as AlarmLoaded;
      final prefs = await SharedPreferences.getInstance();
      
      if (event.date != null) {
        await prefs.setString('startDate', event.date!.toIso8601String().split('T')[0]);
      } else {
        await prefs.remove('startDate');
      }
      
      emit(current.copyWith(startDate: () => event.date));
      add(const ScheduleAlarms());
    }
  }

  Future<void> _onSetEndDate(SetEndDate event, Emitter<AlarmState> emit) async {
    if (state is AlarmLoaded) {
      final current = state as AlarmLoaded;
      final prefs = await SharedPreferences.getInstance();
      
      if (event.date != null) {
        await prefs.setString('endDate', event.date!.toIso8601String().split('T')[0]);
      } else {
        await prefs.remove('endDate');
      }
      
      emit(current.copyWith(endDate: () => event.date));
      add(const ScheduleAlarms());
    }
  }

  Future<void> _onClearDateRange(ClearDateRange event, Emitter<AlarmState> emit) async {
    if (state is AlarmLoaded) {
      final current = state as AlarmLoaded;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('startDate');
      await prefs.remove('endDate');
      
      emit(current.copyWith(
        startDate: () => null,
        endDate: () => null,
      ));
      add(const ScheduleAlarms());
    }
  }

  Future<void> _onAddMinuteItem(AddMinuteItem event, Emitter<AlarmState> emit) async {
    if (state is AlarmLoaded) {
      final current = state as AlarmLoaded;
      final idBase = DateTime.now().millisecondsSinceEpoch.remainder(1000000);
      final newItem = MinuteItem(
        minute: event.minute,
        idBase: idBase,
        ringtoneUri: event.ringtoneUri,
        ringtoneTitle: event.ringtoneTitle,
        remark: event.remark,
      );
      
      final newItems = [...current.minuteItems, newItem];
      await _saveMinuteItems(newItems);
      
      emit(current.copyWith(minuteItems: newItems));
      add(const ScheduleAlarms());
    }
  }

  Future<void> _onUpdateMinuteItem(UpdateMinuteItem event, Emitter<AlarmState> emit) async {
    if (state is AlarmLoaded) {
      final current = state as AlarmLoaded;
      final idx = current.minuteItems.indexWhere((e) => e.idBase == event.oldItem.idBase);
      
      if (idx >= 0) {
        final newItems = [...current.minuteItems];
        newItems[idx] = MinuteItem(
          minute: event.minute,
          idBase: event.oldItem.idBase,
          ringtoneUri: event.ringtoneUri ?? newItems[idx].ringtoneUri,
          ringtoneTitle: event.ringtoneTitle ?? newItems[idx].ringtoneTitle,
          remark: event.remark ?? newItems[idx].remark,
        );
        
        await _saveMinuteItems(newItems);
        emit(current.copyWith(minuteItems: newItems));
        add(const ScheduleAlarms());
      }
    }
  }

  Future<void> _onRemoveMinuteItem(RemoveMinuteItem event, Emitter<AlarmState> emit) async {
    if (state is AlarmLoaded) {
      final current = state as AlarmLoaded;
      final newItems = current.minuteItems.where((e) => e.idBase != event.item.idBase).toList();
      
      await _saveMinuteItems(newItems);
      emit(current.copyWith(minuteItems: newItems));
      add(const ScheduleAlarms());
    }
  }

  Future<void> _saveMinuteItems(List<MinuteItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(items.map((e) => e.toJson()).toList());
    await prefs.setString('minute_items', encoded);
  }

  Future<void> _onScheduleAlarms(ScheduleAlarms event, Emitter<AlarmState> emit) async {
    if (state is AlarmLoaded) {
      final current = state as AlarmLoaded;
      
      try {
        // Ensure exact-alarm permission prompt on Android 12+ before scheduling
        try {
          await _native.invokeMethod('ensureExactAlarmPermission');
        } catch (_) {}
        // Cancel all previously scheduled alarms
        final prefs = await SharedPreferences.getInstance();
        final scheduledRaw = prefs.getStringList('scheduled_ids') ?? [];
        for (final s in scheduledRaw) {
          try {
            final id = int.parse(s);
            await _native.invokeMethod('cancelAlarm', {'id': id});
          } catch (_) {}
        }

        final List<String> newScheduled = [];
        final now = tz.TZDateTime.now(tz.local);

        for (final item in current.minuteItems) {
          final hours = _getHoursInRange(current.startHour, current.endHour);
          
          int offset = 0;
          for (final h in hours) {
            // Create time using TZDateTime to respect Asia/Shanghai timezone
            var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, h, item.minute, 0, 0);
            if (scheduled.isBefore(now)) {
              scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day + 1, h, item.minute, 0, 0);
            }

            final timeMillis = scheduled.millisecondsSinceEpoch;
            final alignedMillis = (timeMillis ~/ 60000) * 60000;

            final id = item.idBase + offset;
            try {
              await _native.invokeMethod('scheduleAlarm', {
                'id': id,
                'time': alignedMillis,
                'uri': item.ringtoneUri ?? ''
              });
              newScheduled.add(id.toString());
            } catch (_) {}
            offset += 1;
            if (offset > 99999) break;
          }
        }

        await prefs.setStringList('scheduled_ids', newScheduled);
      } catch (e) {
        emit(AlarmError('Failed to schedule alarms: $e'));
      }
    }
  }

  List<int> _getHoursInRange(int startHour, int endHour) {
    final hours = <int>[];
    if (startHour <= endHour) {
      for (int h = startHour; h <= endHour; h++) {
        hours.add(h);
      }
    } else {
      for (int h = startHour; h < 24; h++) {
        hours.add(h);
      }
      for (int h = 0; h <= endHour; h++) {
        hours.add(h);
      }
    }
    return hours;
  }

  Future<void> _onTestMinuteItem(TestMinuteItem event, Emitter<AlarmState> emit) async {
    if (state is AlarmLoaded) {
      final current = state as AlarmLoaded;
      final inRange = _hourInRange(DateTime.now().hour, current.startHour, current.endHour);
      
      try {
        await _native.invokeMethod('playRingtone', {'uri': event.item.ringtoneUri ?? ''});
      } catch (_) {}
      
      final message = '测试已触发（当前小时在范围: $inRange）';
      emit(AlarmScheduled(message));
      emit(current);
    }
  }

  bool _hourInRange(int h, int startHour, int endHour) {
    if (startHour <= endHour) {
      return h >= startHour && h <= endHour;
    } else {
      return h >= startHour || h <= endHour;
    }
  }
}
