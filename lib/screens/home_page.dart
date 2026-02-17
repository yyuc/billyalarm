import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:billyalarm/blocs/blocs.dart';
import 'package:billyalarm/models/minute_item.dart';
import 'package:billyalarm/ui/theme.dart';
import 'package:billyalarm/widgets/minute_tile.dart';
import 'package:billyalarm/widgets/config_section.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    context.read<AlarmBloc>().add(const LoadAlarmConfig());
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkExactAlarmPermission());
  }

  Future<void> _checkExactAlarmPermission() async {
    final channel = MethodChannel('billyalarm/native');
    try {
      final can = await channel.invokeMethod<bool>('canScheduleExactAlarms');
      if (can == false && mounted) {
        // show dialog explaining steps
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('需要精确闹钟权限'),
            content: const Text(
                '为了保证铃声能精确在整分钟（:00.000）播放，请在系统设置中为本应用启用「精确闹钟」或在弹出页面中允许。\n\n点击下方按钮打开系统权限页面。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () async {
                  try {
                    await channel.invokeMethod('ensureExactAlarmPermission');
                  } catch (_) {}
                  Navigator.pop(ctx);
                },
                child: const Text('打开系统权限'),
              ),
            ],
          ),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.alarm, size: 24),
            ),
            const SizedBox(width: 8),
            const Text(
              'Billy Alarm',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
      body: BlocBuilder<AlarmBloc, AlarmState>(
        builder: (context, state) {
          if (state is AlarmLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is AlarmError) {
            return Center(child: Text('Error: ${state.message}'));
          }
          if (state is! AlarmLoaded) {
            return const SizedBox.shrink();
          }

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.backgroundColor,
                  AppTheme.primaryColor.withOpacity(0.1),
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  ConfigSection(state: state),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            _showMinuteAndRingtoneDialog(context, null),
                        icon: const Icon(Icons.add),
                        label: const Text('添加分钟点'),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  Expanded(
                    child: state.minuteItems.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            itemCount: state.minuteItems.length,
                            itemBuilder: (context, index) => MinuteTile(
                              item: state.minuteItems[index],
                              onEdit: () => _showMinuteAndRingtoneDialog(
                                  context, state.minuteItems[index]),
                              onDelete: () => context.read<AlarmBloc>().add(
                                    RemoveMinuteItem(state.minuteItems[index]),
                                  ),
                              onTest: () =>
                                  context.read<AlarmBloc>().add(
                                        TestMinuteItem(state.minuteItems[index]),
                                      ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.alarm_off,
            size: 64,
            color: AppTheme.primaryColor.withOpacity(0.3),
          ),
          const SizedBox(height: 12),
          Text(
            '尚未添加任何分钟点',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textColor.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击上方"添加分钟点"开始设置',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textColor.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showMinuteAndRingtoneDialog(
    BuildContext context,
    MinuteItem? editing,
  ) async {
    final int? picked = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('选择分钟（0-59）'),
        children: List.generate(60, (i) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(context, i),
            child: Text(i.toString().padLeft(2, '0')),
          );
        }),
      ),
    );
    if (picked == null || !mounted) return;

    String? chosenUri = editing?.ringtoneUri;
    String? chosenTitle = editing?.ringtoneTitle;
    String? chosenRemark = editing?.remark;

    if (!context.mounted) return;
    context.read<RingtoneBloc>().add(const LoadRingtones());

    final ringtoneState = await _waitForRingtones(context);
    if (ringtoneState is RingtoneLoaded && ringtoneState.ringtones.isNotEmpty) {
      final pick = await _showRingtoneSelectionDialog(
        context,
        ringtoneState.ringtones,
      );
      if (pick != null) {
        chosenUri = ringtoneState.ringtones[pick]['uri'];
        chosenTitle = ringtoneState.ringtones[pick]['title'];
      }
    }

    if (!mounted) return;
    final remarkResult = await _showRemarkDialog(context, chosenRemark);
    if (remarkResult != null) {
      chosenRemark = remarkResult;
    }

    if (!mounted) return;
    if (editing == null) {
      context.read<AlarmBloc>().add(
            AddMinuteItem(
              minute: picked,
              ringtoneUri: chosenUri,
              ringtoneTitle: chosenTitle,
              remark: chosenRemark,
            ),
          );
    } else {
      context.read<AlarmBloc>().add(
            UpdateMinuteItem(
              oldItem: editing,
              minute: picked,
              ringtoneUri: chosenUri,
              ringtoneTitle: chosenTitle,
              remark: chosenRemark,
            ),
          );
    }
  }

  Future<RingtoneState> _waitForRingtones(BuildContext context) async {
    return await context.read<RingtoneBloc>().stream.firstWhere(
          (state) => state is! RingtoneLoading,
          orElse: () => const RingtoneLoaded(ringtones: []),
        );
  }

  Future<int?> _showRingtoneSelectionDialog(
    BuildContext context,
    List<Map<String, String>> ringtones,
  ) async {
    return await showDialog<int?>(
      context: context,
      builder: (context) {
        int? previewIndex;
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Text('选择铃声'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: ringtones.length,
                itemBuilder: (ctx, i) {
                  final r = ringtones[i];
                  final isPreviewing = previewIndex == i;
                  return ListTile(
                    title: Text(r['title'] ?? '铃声'),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        icon: Icon(
                            isPreviewing ? Icons.stop : Icons.play_arrow),
                        onPressed: () async {
                          try {
                            if (isPreviewing) {
                              context
                                  .read<RingtoneBloc>()
                                  .add(const StopRingtone());
                              setState(() => previewIndex = null);
                            } else {
                              context.read<RingtoneBloc>().add(
                                    PlayRingtone(r['uri'] ?? ''),
                                  );
                              setState(() => previewIndex = i);
                            }
                          } catch (_) {}
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.check),
                        onPressed: () async {
                          try {
                            context
                                .read<RingtoneBloc>()
                                .add(const StopRingtone());
                          } catch (_) {}
                          Navigator.pop(context, i);
                        },
                      ),
                    ]),
                    onTap: () async {
                      try {
                        if (isPreviewing) {
                          context
                              .read<RingtoneBloc>()
                              .add(const StopRingtone());
                          setState(() => previewIndex = null);
                        } else {
                          context.read<RingtoneBloc>().add(
                                PlayRingtone(r['uri'] ?? ''),
                              );
                          setState(() => previewIndex = i);
                        }
                      } catch (_) {}
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () async {
                    try {
                      context.read<RingtoneBloc>().add(const StopRingtone());
                    } catch (_) {}
                    Navigator.pop(context, null);
                  },
                  child: const Text('取消')),
            ],
          );
        });
      },
    );
  }

  Future<String?> _showRemarkDialog(BuildContext context, String? initial) async {
    return await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController(text: initial ?? '');
        return AlertDialog(
          title: const Text('添加备注（可选）'),
          content: TextField(
            maxLines: 3,
            controller: controller,
            decoration: const InputDecoration(
              hintText: '例如：工作会议、锻炼时间',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }
}
