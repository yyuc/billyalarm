import 'package:billyalarm/models/minute_item.dart';

abstract class AlarmState {
  const AlarmState();
}

class AlarmInitial extends AlarmState {
  const AlarmInitial();
}

class AlarmLoading extends AlarmState {
  const AlarmLoading();
}

class AlarmLoaded extends AlarmState {
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<MinuteItem> minuteItems;

  const AlarmLoaded({
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    this.startDate,
    this.endDate,
    required this.minuteItems,
  });

  AlarmLoaded copyWith({
    int? startHour,
    int? startMinute,
    int? endHour,
    int? endMinute,
    DateTime? Function()? startDate,
    DateTime? Function()? endDate,
    List<MinuteItem>? minuteItems,
  }) => AlarmLoaded(
    startHour: startHour ?? this.startHour,
    startMinute: startMinute ?? this.startMinute,
    endHour: endHour ?? this.endHour,
    endMinute: endMinute ?? this.endMinute,
    startDate: startDate != null ? startDate() : this.startDate,
    endDate: endDate != null ? endDate() : this.endDate,
    minuteItems: minuteItems ?? this.minuteItems,
  );
}

class AlarmError extends AlarmState {
  final String message;
  const AlarmError(this.message);
}

class AlarmScheduled extends AlarmState {
  final String message;
  const AlarmScheduled(this.message);
}
