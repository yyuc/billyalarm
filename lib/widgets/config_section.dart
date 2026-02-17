import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:billyalarm/blocs/blocs.dart';
import 'package:billyalarm/ui/theme.dart';

class ConfigSection extends StatelessWidget {
  final AlarmLoaded state;

  const ConfigSection({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final rangeLabel =
        '${state.startHour.toString().padLeft(2, '0')}:${state.startMinute.toString().padLeft(2, '0')} - ${state.endHour.toString().padLeft(2, '0')}:${state.endMinute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.music_note, color: AppTheme.accentColor, size: 24),
              const SizedBox(width: 8),
              const Text('铃声播放',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ]),
          ]),
          const SizedBox(height: 16),
          _buildDivider('闹铃周期'),
          Row(children: [
            Expanded(
              child: _buildDateButton(
                context,
                '开始日期',
                state.startDate,
                () => _pickStartDate(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDateButton(
                context,
                '结束日期',
                state.endDate,
                () => _pickEndDate(context),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          _buildDivider('每日起始时间'),
          Row(children: [
            Expanded(
              child: _buildTimeButton(
                context,
                '起始',
                state.startHour,
                state.startMinute,
                () => _pickStartHour(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTimeButton(
                context,
                '结束',
                state.endHour,
                state.endMinute,
                () => _pickEndHour(context),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          _buildDivider('生效时间'),
          Text(
            '${_getDateRangeText()}$rangeLabel',
            style: TextStyle(
              color: AppTheme.textColor.withOpacity(0.7),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: AppTheme.primaryColor.withOpacity(0.3),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: TextStyle(
                color: AppTheme.textColor.withOpacity(0.6),
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: AppTheme.primaryColor.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeButton(
    BuildContext context,
    String label,
    int hour,
    int minute,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.primaryColor.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$label: ',
              style: TextStyle(
                color: AppTheme.textColor.withOpacity(0.7),
              ),
            ),
            Text(
              '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.accentColor,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateButton(
    BuildContext context,
    String label,
    DateTime? date,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: date != null
              ? AppTheme.accentColor.withOpacity(0.15)
              : AppTheme.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: date != null
                ? AppTheme.accentColor.withOpacity(0.3)
                : AppTheme.primaryColor.withOpacity(0.2),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today,
              size: 16,
              color: date != null
                  ? AppTheme.accentColor
                  : AppTheme.textColor.withOpacity(0.5),
            ),
            const SizedBox(width: 6),
            Text(
              _formatDate(date),
              style: TextStyle(
                fontWeight: date != null ? FontWeight.bold : FontWeight.normal,
                color: date != null
                    ? AppTheme.accentColor
                    : AppTheme.textColor.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickStartHour(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: state.startHour, minute: state.startMinute),
      helpText: '选择起始时间',
    );
    if (picked != null && context.mounted) {
      context.read<AlarmBloc>().add(SetStartTime(picked.hour, picked.minute));
    }
  }

  Future<void> _pickEndHour(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: state.endHour, minute: state.endMinute),
      helpText: '选择结束时间',
    );
    if (picked != null && context.mounted) {
      context.read<AlarmBloc>().add(SetEndTime(picked.hour, picked.minute));
    }
  }

  Future<void> _pickStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: state.startDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: '选择开始日期',
    );
    if (picked != null && context.mounted) {
      context.read<AlarmBloc>().add(SetStartDate(picked));
    }
  }

  Future<void> _pickEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: state.endDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: '选择结束日期',
    );
    if (picked != null && context.mounted) {
      context.read<AlarmBloc>().add(SetEndDate(picked));
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '未设置';
    return '${date.month}月${date.day}日';
  }

  String _getDateRangeText() {
    if (state.startDate == null && state.endDate == null) {
      return '';
    } else if (state.startDate != null && state.endDate != null) {
      return '${_formatDate(state.startDate)} - ${_formatDate(state.endDate)} | ';
    } else if (state.startDate != null) {
      return '${_formatDate(state.startDate)} 起 | ';
    } else {
      return '截止 ${_formatDate(state.endDate)} | ';
    }
  }
}
