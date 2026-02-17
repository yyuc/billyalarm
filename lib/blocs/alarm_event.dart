import 'package:billyalarm/models/minute_item.dart';

abstract class AlarmEvent {
  const AlarmEvent();
}

// Load events
class LoadAlarmConfig extends AlarmEvent {
  const LoadAlarmConfig();
}

// Configuration events
class SetStartTime extends AlarmEvent {
  final int hour;
  final int minute;
  const SetStartTime(this.hour, this.minute);
}

class SetEndTime extends AlarmEvent {
  final int hour;
  final int minute;
  const SetEndTime(this.hour, this.minute);
}

class SetStartDate extends AlarmEvent {
  final DateTime? date;
  const SetStartDate(this.date);
}

class SetEndDate extends AlarmEvent {
  final DateTime? date;
  const SetEndDate(this.date);
}

class ClearDateRange extends AlarmEvent {
  const ClearDateRange();
}

// Minute item events
class AddMinuteItem extends AlarmEvent {
  final int minute;
  final String? ringtoneUri;
  final String? ringtoneTitle;
  final String? remark;
  const AddMinuteItem({
    required this.minute,
    this.ringtoneUri,
    this.ringtoneTitle,
    this.remark,
  });
}

class UpdateMinuteItem extends AlarmEvent {
  final MinuteItem oldItem;
  final int minute;
  final String? ringtoneUri;
  final String? ringtoneTitle;
  final String? remark;
  const UpdateMinuteItem({
    required this.oldItem,
    required this.minute,
    this.ringtoneUri,
    this.ringtoneTitle,
    this.remark,
  });
}

class RemoveMinuteItem extends AlarmEvent {
  final MinuteItem item;
  const RemoveMinuteItem(this.item);
}

// Scheduling
class ScheduleAlarms extends AlarmEvent {
  const ScheduleAlarms();
}

// Test
class TestMinuteItem extends AlarmEvent {
  final MinuteItem item;
  const TestMinuteItem(this.item);
}
