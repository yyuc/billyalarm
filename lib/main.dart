// lib/main.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

const MethodChannel _native = MethodChannel('billyalarm/native');

@pragma('vm:entry-point')
void alarmCallback(int id) async {
  // This runs in background when alarm fires. It should be fast and use native playback.
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('minute_items') ?? '[]';
    final List decoded = jsonDecode(raw);
    final items = decoded.map((e) => MinuteItem.fromJson(e)).toList();
    // find matching item by idBase match (we scheduled with id = idBase + hourOffset)
    for (final item in items) {
      // scheduled ids were created as item.idBase + offset where offset < 100000
      final base = item.idBase;
      if (id >= base && id < base + 100000) {
        final uri = item.ringtoneUri;
        await _native.invokeMethod('playRingtone', {'uri': uri ?? ''});
        break;
      }
    }
  } catch (_) {}
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));

  runApp(const MyApp());
}

class MinuteItem {
  int minute; // 0-59
  int idBase; // unique base id for this minute item
  String? ringtoneUri;
  String? ringtoneTitle;
  String? remark; // user note for this alarm

  MinuteItem({
    required this.minute,
    required this.idBase,
    this.ringtoneUri,
    this.ringtoneTitle,
    this.remark,
  });

  Map<String, dynamic> toJson() =>
      {
        'minute': minute,
        'idBase': idBase,
        'ringtoneUri': ringtoneUri,
        'ringtoneTitle': ringtoneTitle,
        'remark': remark,
      };

  static MinuteItem fromJson(Map<String, dynamic> j) => MinuteItem(
        minute: j['minute'],
        idBase: j['idBase'],
        ringtoneUri: j['ringtoneUri'],
        ringtoneTitle: j['ringtoneTitle'],
        remark: j['remark'],
      );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const Color primaryColor = Color.fromRGBO(255, 179, 71, 1);
  static const Color secondaryColor = Color(0xFFB8956B);
  static const Color accentColor = Color(0xFFFF8C00);
  static const Color backgroundColor = Color(0xFFFFFAF0);
  static const Color cardColor = Colors.white;
  static const Color textColor = Color(0xFF5D4037);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Billy Alarm',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          primary: primaryColor,
          secondary: secondaryColor,
          tertiary: accentColor,
          surface: backgroundColor,
          onSurface: textColor,
        ),
        scaffoldBackgroundColor: backgroundColor,
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        cardTheme: CardThemeData(
          color: cardColor,
          elevation: 4,
          shadowColor: primaryColor.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            elevation: 4,
            shadowColor: primaryColor.withOpacity(0.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
          elevation: 6,
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return accentColor;
            }
            return Colors.grey;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return accentColor.withOpacity(0.5);
            }
            return Colors.grey.withOpacity(0.3);
          }),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.orange.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: primaryColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: accentColor, width: 2),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: accentColor,
          contentTextStyle: const TextStyle(color: Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int startHour = 8;
  int startMinute = 0;
  int endHour = 22;
  int endMinute = 0;
  DateTime? startDate;
  DateTime? endDate;
  bool enableTTS = false;
  bool _nativeAvailable = true;
  List<MinuteItem> minuteItems = [];
  

  @override
  void initState() {
    super.initState();
    _initAlarmAndLoad();
  }

  Future<void> _initAlarmAndLoad() async {
    await _loadAll();
    // schedule existing items via native scheduler
    // ensure app has exact-alarm permission on Android 12+
    try {
      await _native.invokeMethod('ensureExactAlarmPermission');
    } catch (_) {}
    await _scheduleAll();
  }

  // The real work is done via Android AlarmManager callbacks; keep UI responsive.

  Future<List<Map<String, String>>> _getSystemRingtones() async {
    try {
      final res = await _native.invokeMethod('getRingtones');
      final List list = res as List? ?? [];
      return list.map<Map<String, String>>((e) => Map<String, String>.from(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      startHour = prefs.getInt('startHour') ?? 8;
      startMinute = prefs.getInt('startMinute') ?? 0;
      endHour = prefs.getInt('endHour') ?? 22;
      endMinute = prefs.getInt('endMinute') ?? 0;
      final startDateStr = prefs.getString('startDate');
      final endDateStr = prefs.getString('endDate');
      startDate = startDateStr != null ? DateTime.parse(startDateStr) : null;
      endDate = endDateStr != null ? DateTime.parse(endDateStr) : null;
      enableTTS = false; // TTS removed; keep false
      final raw = prefs.getString('minute_items') ?? '[]';
      final List decoded = jsonDecode(raw);
      minuteItems = decoded.map((e) => MinuteItem.fromJson(e)).toList();
    });
  }

  Future<void> _saveAll() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(minuteItems.map((e) => e.toJson()).toList());
    await prefs.setString('minute_items', encoded);
    await prefs.setInt('startHour', startHour);
    await prefs.setInt('startMinute', startMinute);
    await prefs.setInt('endHour', endHour);
    await prefs.setInt('endMinute', endMinute);
    if (startDate != null) {
      await prefs.setString('startDate', startDate!.toIso8601String().split('T')[0]);
    } else {
      await prefs.remove('startDate');
    }
    if (endDate != null) {
      await prefs.setString('endDate', endDate!.toIso8601String().split('T')[0]);
    } else {
      await prefs.remove('endDate');
    }
    // no TTS setting
  }

  bool _hourInRange(int h) {
    if (startHour <= endHour) {
      return h >= startHour && h <= endHour;
    } else {
      return h >= startHour || h <= endHour;
    }
  }

  Future<void> _testItemNow(MinuteItem item) async {
    final now = DateTime.now();
    final inRange = _hourInRange(now.hour);
    try {
      await _native.invokeMethod('playRingtone', {'uri': item.ringtoneUri ?? ''});
    } catch (_) {}
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('测试已触发（当前小时在范围: $inRange）'),
    ));
  }

  Future<void> _scheduleAll() async {
    // Use native AlarmManager to schedule exact alarms with RTC_WAKEUP
    final prefs = await SharedPreferences.getInstance();
    final scheduledRaw = prefs.getStringList('scheduled_ids') ?? [];
    for (final s in scheduledRaw) {
      try {
        final id = int.parse(s);
        try {
          await _native.invokeMethod('cancelAlarm', {'id': id});
        } catch (_) {}
      } catch (_) {}
    }
    final List<String> newScheduled = [];
    final now = tz.TZDateTime.now(tz.local);
    for (final item in minuteItems) {
      final hours = <int>[];
      if (startHour <= endHour) {
        for (int h = startHour; h <= endHour; h++) hours.add(h);
      } else {
        for (int h = startHour; h < 24; h++) hours.add(h);
        for (int h = 0; h <= endHour; h++) hours.add(h);
      }
      int offset = 0;
      for (final h in hours) {
        var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, h, item.minute);
        if (scheduled.isBefore(now)) scheduled = scheduled.add(const Duration(days: 1));
        final id = item.idBase + offset;
        try {
          await _native.invokeMethod('scheduleAlarm', {
            'id': id,
            'time': scheduled.millisecondsSinceEpoch,
            'uri': item.ringtoneUri ?? ''
          });
          newScheduled.add(id.toString());
        } catch (_) {}
        offset += 1;
        if (offset > 99999) break;
      }
    }
    await prefs.setStringList('scheduled_ids', newScheduled);
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) scheduled = scheduled.add(const Duration(days: 1));
    return scheduled;
  }

  Future<void> _addMinuteItem(int minute) async {
    final idBase = DateTime.now().millisecondsSinceEpoch.remainder(1000000);
    final item = MinuteItem(minute: minute, idBase: idBase);
    minuteItems.add(item);
    await _saveAll();
    await _scheduleAll();
    setState(() {});
  }

  Future<void> _editMinuteItem(MinuteItem old, int minute) async {
    final idx = minuteItems.indexWhere((e) => e.idBase == old.idBase);
    if (idx >= 0) {
      minuteItems[idx].minute = minute;
      await _saveAll();
      await _scheduleAll();
      setState(() {});
    }
  }

  Future<void> _removeMinuteItem(MinuteItem item) async {
    minuteItems.removeWhere((e) => e.idBase == item.idBase);
    await _saveAll();
    await _scheduleAll();
    setState(() {});
  }

  Future<void> _pickStartHour() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: startHour, minute: startMinute),
      helpText: '选择起始时间',
    );
    if (picked != null) {
      setState(() {
        startHour = picked.hour;
        startMinute = picked.minute;
      });
      await _saveAll();
      await _scheduleAll();
    }
  }

  Future<void> _pickEndHour() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: endHour, minute: endMinute),
      helpText: '选择结束时间',
    );
    if (picked != null) {
      setState(() {
        endHour = picked.hour;
        endMinute = picked.minute;
      });
      await _saveAll();
      await _scheduleAll();
    }
  }

  Future<void> _pickStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: startDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: '选择开始日期',
    );
    if (picked != null) {
      setState(() => startDate = picked);
      await _saveAll();
      await _scheduleAll();
    }
  }

  Future<void> _pickEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: endDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: '选择结束日期',
    );
    if (picked != null) {
      setState(() => endDate = picked);
      await _saveAll();
      await _scheduleAll();
    }
  }

  Future<void> _clearDateRange() async {
    setState(() {
      startDate = null;
      endDate = null;
    });
    await _saveAll();
    await _scheduleAll();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '未设置';
    return '${date.month}月${date.day}日';
  }

  Future<void> _pickMinuteAndMessage({MinuteItem? editing}) async {
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
    // pick system ringtone (if available)
    String? chosenUri = editing?.ringtoneUri;
    String? chosenTitle = editing?.ringtoneTitle;
    String? chosenRemark = editing?.remark;
    final ringtones = await _getSystemRingtones();
    if (ringtones.isNotEmpty) {
      final pick = await showDialog<int?>(
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
                          icon: Icon(isPreviewing ? Icons.stop : Icons.play_arrow),
                          onPressed: () async {
                            try {
                              if (isPreviewing) {
                                await _native.invokeMethod('stopRingtone');
                                setState(() => previewIndex = null);
                              } else {
                                await _native.invokeMethod('playRingtone', {'uri': r['uri'] ?? ''});
                                setState(() => previewIndex = i);
                              }
                            } catch (_) {}
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.check),
                          onPressed: () async {
                            try {
                              await _native.invokeMethod('stopRingtone');
                            } catch (_) {}
                            Navigator.pop(context, i);
                          },
                        ),
                      ]),
                      onTap: () async {
                        // toggle preview on tap
                        try {
                          if (isPreviewing) {
                            await _native.invokeMethod('stopRingtone');
                            setState(() => previewIndex = null);
                          } else {
                            await _native.invokeMethod('playRingtone', {'uri': r['uri'] ?? ''});
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
                        await _native.invokeMethod('stopRingtone');
                      } catch (_) {}
                      Navigator.pop(context, null);
                    },
                    child: const Text('取消')),
              ],
            );
          });
        },
      );
      if (pick != null) {
        chosenUri = ringtones[pick]['uri'];
        chosenTitle = ringtones[pick]['title'];
      }
    }
    // ask for remark
    if (!mounted) return;
    final remarkResult = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController(text: chosenRemark ?? '');
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
    if (remarkResult != null) {
      chosenRemark = remarkResult;
    }
    if (editing == null) {
      final idBase = DateTime.now().millisecondsSinceEpoch.remainder(1000000);
      final item = MinuteItem(
        minute: picked,
        idBase: idBase,
        ringtoneUri: chosenUri,
        ringtoneTitle: chosenTitle,
        remark: chosenRemark,
      );
      minuteItems.add(item);
      await _saveAll();
      await _scheduleAll();
      setState(() {});
    } else {
      await _editMinuteItem(editing, picked);
      final idx = minuteItems.indexWhere((e) => e.idBase == editing.idBase);
      if (idx >= 0) {
        minuteItems[idx].ringtoneUri = chosenUri;
        minuteItems[idx].ringtoneTitle = chosenTitle;
        minuteItems[idx].remark = chosenRemark;
        await _saveAll();
        await _scheduleAll();
        setState(() {});
      }
    }
  }

  Widget _buildMinuteTile(MinuteItem item) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (item.remark != null && item.remark!.isNotEmpty)
                        Text(
                            item.remark!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              color: MyApp.textColor.withOpacity(0.6),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        if (item.ringtoneTitle != null)
                         Text(
                            ' - ${item.ringtoneTitle!}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: MyApp.accentColor,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: MyApp.accentColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${item.minute.toString().padLeft(2, '0')}分',
                          style: const TextStyle(
                            fontSize: 12,
                            color: MyApp.accentColor,
                          ),
                        )
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 12),
                _buildIconButton(Icons.play_arrow, () => _testItemNow(item), '立即测试'),
                SizedBox(width: 12),
                _buildIconButton(Icons.edit, () => _pickMinuteAndMessage(editing: item), '编辑'),
                SizedBox(width: 12),
                _buildIconButton(Icons.delete, () => _removeMinuteItem(item), '删除'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onPressed, String tooltip) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: MyApp.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        icon: Icon(icon, color: MyApp.accentColor),
        onPressed: onPressed,
        tooltip: tooltip,
        iconSize: 22,
      ),
    );
  }

  // TTS removed; native ringtone listing available via system dialog
  Future<void> _showAvailableVoices() async {
    if (!mounted) return;
    showDialog(context: context, builder: (_) => AlertDialog(title: const Text('已移除'), content: const Text('语音播报已移除，使用铃声播放'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭'))]));
  }

  @override
  Widget build(BuildContext context) {
    final rangeLabel =
        '${startHour.toString().padLeft(2, '0')}:${startMinute.toString().padLeft(2, '0')} - ${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}';
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              MyApp.backgroundColor,
              MyApp.primaryColor.withOpacity(0.1),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: MyApp.primaryColor.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.start, children: [
                    Row(children: [
                      Icon(Icons.music_note, color: MyApp.accentColor, size: 24),
                      const SizedBox(width: 8),
                      const Text('铃声播放', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ]),
                  ]),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 1,
                            color: MyApp.primaryColor.withOpacity(0.3),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            '闹铃周期',
                            style: TextStyle(
                              color: MyApp.textColor.withOpacity(0.6),
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 1,
                            color: MyApp.primaryColor.withOpacity(0.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(children: [
                    Expanded(
                      child: _buildDateButton(
                        '开始日期',
                        startDate,
                        _pickStartDate,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDateButton(
                        '结束日期',
                        endDate,
                        _pickEndDate,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 1,
                            color: MyApp.primaryColor.withOpacity(0.3),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            '每日起始时间',
                            style: TextStyle(
                              color: MyApp.textColor.withOpacity(0.6),
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 1,
                            color: MyApp.primaryColor.withOpacity(0.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(children: [
                    Expanded(
                      child: _buildTimeButton(
                        '起始',
                        startHour,
                        startMinute,
                        _pickStartHour,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTimeButton(
                        '结束',
                        endHour,
                        endMinute,
                        _pickEndHour,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 1,
                            color: MyApp.primaryColor.withOpacity(0.3),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            '生效时间',
                            style: TextStyle(
                              color: MyApp.textColor.withOpacity(0.6),
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 1,
                            color: MyApp.primaryColor.withOpacity(0.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${_getDateRangeText()}$rangeLabel',
                    style: TextStyle(
                      color: MyApp.textColor.withOpacity(0.7),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _pickMinuteAndMessage(),
                  icon: const Icon(Icons.add),
                  label: const Text('添加分钟点'),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            Expanded(
              child: minuteItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.alarm_off,
                            size: 64,
                            color: MyApp.primaryColor.withOpacity(0.3),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '尚未添加任何分钟点',
                            style: TextStyle(
                              fontSize: 16,
                              color: MyApp.textColor.withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '点击上方"添加分钟点"开始设置',
                            style: TextStyle(
                              fontSize: 13,
                              color: MyApp.textColor.withOpacity(0.4),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: minuteItems.length,
                      itemBuilder: (context, index) =>
                          _buildMinuteTile(minuteItems[index]),
                    ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildTimeButton(String label, int hour, int minute, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: MyApp.primaryColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: MyApp.primaryColor.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$label: ',
              style: TextStyle(
                color: MyApp.textColor.withOpacity(0.7),
              ),
            ),
            Text(
              '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: MyApp.accentColor,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateButton(String label, DateTime? date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: date != null ? MyApp.accentColor.withOpacity(0.15) : MyApp.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: date != null ? MyApp.accentColor.withOpacity(0.3) : MyApp.primaryColor.withOpacity(0.2),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today,
              size: 16,
              color: date != null ? MyApp.accentColor : MyApp.textColor.withOpacity(0.5),
            ),
            const SizedBox(width: 6),
            Text(
              '${_formatDate(date)}',
              style: TextStyle(
                fontWeight: date != null ? FontWeight.bold : FontWeight.normal,
                color: date != null ? MyApp.accentColor : MyApp.textColor.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getDateRangeText() {
    if (startDate == null && endDate == null) {
      return '';
    } else if (startDate != null && endDate != null) {
      return '${_formatDate(startDate)} - ${_formatDate(endDate)} | ';
    } else if (startDate != null) {
      return '${_formatDate(startDate)} 起 | ';
    } else {
      return '截止 ${_formatDate(endDate)} | ';
    }
  }
}
