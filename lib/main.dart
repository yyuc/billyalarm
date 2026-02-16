// lib/main.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
final FlutterTts flutterTts = FlutterTts();

Future<void> _speakWithGender(String text, String gender, {dynamic availableVoices}) async {
  String? voiceName;
  double pitch = 1.0;
  double speechRate = 0.5;

  if (availableVoices != null && availableVoices is List && availableVoices.isNotEmpty) {
    final lowerGender = gender.toLowerCase();
    for (final v in availableVoices) {
      try {
        final map = v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
        final name = (map['name'] ?? map['voice'] ?? '').toString().toLowerCase();
        final genderField = (map['gender'] ?? '').toString().toLowerCase();
        if (gender == 'default') break;
        if (lowerGender == 'male') {
          if (name.contains('male') || name.contains('man') || name.contains('男') ||
              genderField.contains('male') || genderField.contains('man')) {
            voiceName = map['name']?.toString();
            break;
          }
        } else if (lowerGender == 'female') {
          if (name.contains('female') || name.contains('woman') || name.contains('女') ||
              genderField.contains('female') || genderField.contains('woman')) {
            voiceName = map['name']?.toString();
            break;
          }
        }
      } catch (_) {}
    }
  }

  await flutterTts.setLanguage("zh-CN");
  if (voiceName != null) {
    await flutterTts.setVoice({"name": voiceName, "locale": "zh-CN"});
  }
  await flutterTts.setSpeechRate(speechRate);
  await flutterTts.setPitch(pitch);
  await flutterTts.speak(text);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));

  const AndroidInitializationSettings androidInit =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initSettings =
      InitializationSettings(android: androidInit);

  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) async {
      final payload = response.payload;
      if (payload != null && payload.isNotEmpty) {
        try {
          final Map parsed = jsonDecode(payload);
          final text = parsed['text']?.toString() ?? '';
          final gender = parsed['gender']?.toString() ?? 'default';
          final prefs = await SharedPreferences.getInstance();
          final enableTTS = prefs.getBool('enableTTS') ?? true;
          if (enableTTS) {
            final voices = await flutterTts.getVoices;
            await _speakWithGender(text, gender, availableVoices: voices);
          }
        } catch (_) {
          // 如果 payload 不是 JSON，直接播报原始字符串
          final prefs = await SharedPreferences.getInstance();
          final enableTTS = prefs.getBool('enableTTS') ?? true;
          if (enableTTS) {
            final voices = await flutterTts.getVoices;
            await _speakWithGender(payload, 'default', availableVoices: voices);
          }
        }
      }
    },
  );

  runApp(const MyApp());
}

class MinuteItem {
  int minute; // 0-59
  String message;
  int idBase; // unique base id for this minute item
  String voiceGender; // 'default' | 'male' | 'female'

  MinuteItem({
    required this.minute,
    required this.message,
    required this.idBase,
    required this.voiceGender,
  });

  Map<String, dynamic> toJson() =>
      {'minute': minute, 'message': message, 'idBase': idBase, 'voiceGender': voiceGender};

  static MinuteItem fromJson(Map<String, dynamic> j) => MinuteItem(
        minute: j['minute'],
        message: j['message'],
        idBase: j['idBase'],
        voiceGender: j['voiceGender'] ?? 'default',
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
  bool enableTTS = true;
  List<MinuteItem> minuteItems = [];
  final TextEditingController _messageController = TextEditingController();

  // 可用 voices（调试/匹配用）
  List<dynamic> availableVoices = [];

  @override
  void initState() {
    super.initState();
    _loadAll().then((_) async {
      await _loadAvailableVoices();
      await _scheduleAll();
    });
  }

  Future<void> _loadAvailableVoices() async {
    try {
      final voices = await flutterTts.getVoices;
      setState(() {
        availableVoices = voices ?? [];
      });
    } catch (_) {
      availableVoices = [];
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
      enableTTS = prefs.getBool('enableTTS') ?? true;
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
    await prefs.setBool('enableTTS', enableTTS);
  }

  bool _hourInRange(int h) {
    if (startHour <= endHour) {
      return h >= startHour && h <= endHour;
    } else {
      return h >= startHour || h <= endHour;
    }
  }

  Future<void> _scheduleAll() async {
    await flutterLocalNotificationsPlugin.cancelAll();

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'multi_min_channel',
      '多分钟点报时',
      channelDescription: '在指定时间范围内每小时到达选定分钟点播报',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );
    const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    // 生成小时列表（支持跨午夜）
    final List<int> hours = [];
    if (startHour <= endHour) {
      for (int h = startHour; h <= endHour; h++) hours.add(h);
    } else {
      for (int h = startHour; h < 24; h++) hours.add(h);
      for (int h = 0; h <= endHour; h++) hours.add(h);
    }

    for (final item in minuteItems) {
      for (final h in hours) {
        final tz.TZDateTime scheduled = _nextInstanceOfTime(h, item.minute);
        final String text = item.message
            .replaceAll('{hour}', h.toString())
            .replaceAll('{minute}', item.minute.toString().padLeft(2, '0'));
        final payload = jsonEncode({'text': text, 'gender': item.voiceGender});
        final body = text;
        final int id = item.idBase + h; // idBase + hour 保证唯一
        await flutterLocalNotificationsPlugin.zonedSchedule(
          id,
          '报时提醒',
          body,
          scheduled,
          platformDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: payload,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }
    }
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) scheduled = scheduled.add(const Duration(days: 1));
    return scheduled;
  }

  // 语音播报：优先尝试匹配 voice，否则用 pitch 回退
  static Future<void> _speakWithGender(String text, String gender,
      {List<dynamic>? availableVoices}) async {
    double pitch = 1.0;
    String? voiceName;

    if (gender == 'male') {
      pitch = 0.8;
    } else if (gender == 'female') {
      pitch = 1.2;
    } else {
      pitch = 1.0;
    }

    if (availableVoices != null && availableVoices.isNotEmpty) {
      final lowerGender = gender.toLowerCase();
      for (final v in availableVoices) {
        try {
          final map = v is Map ? v : Map<String, dynamic>.from(v);
          final name = (map['name'] ?? map['voice'] ?? '').toString().toLowerCase();
          final genderField = (map['gender'] ?? '').toString().toLowerCase();
          if (lowerGender == 'male') {
            if (name.contains('male') ||
                name.contains('man') ||
                name.contains('男') ||
                genderField.contains('male') ||
                genderField.contains('man')) {
              voiceName = map['name']?.toString();
              break;
            }
          } else if (lowerGender == 'female') {
            if (name.contains('female') ||
                name.contains('woman') ||
                name.contains('女') ||
                genderField.contains('female') ||
                genderField.contains('woman')) {
              voiceName = map['name']?.toString();
              break;
            }
          }
        } catch (_) {
          continue;
        }
      }
    }

    try {
      if (voiceName != null) {
        await flutterTts.setVoice({'name': voiceName});
      }
    } catch (_) {}
    try {
      await flutterTts.setPitch(pitch);
    } catch (_) {}
    try {
      await flutterTts.setLanguage("zh-CN");
      await flutterTts.setSpeechRate(0.5);
      await flutterTts.speak(text);
    } catch (_) {}
  }

  Future<void> _addMinuteItem(int minute, String message, String gender) async {
    final idBase = DateTime.now().millisecondsSinceEpoch.remainder(1000000);
    final item = MinuteItem(minute: minute, message: message, idBase: idBase, voiceGender: gender);
    minuteItems.add(item);
    await _saveAll();
    await _scheduleAll();
    setState(() {});
  }

  Future<void> _editMinuteItem(MinuteItem old, int minute, String message, String gender) async {
    final idx = minuteItems.indexWhere((e) => e.idBase == old.idBase);
    if (idx >= 0) {
      minuteItems[idx].minute = minute;
      minuteItems[idx].message = message;
      minuteItems[idx].voiceGender = gender;
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
    _messageController.text = editing?.message ?? "现在是 {hour} 点 {minute} 分";
    String selectedGender = editing?.voiceGender ?? 'default';
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
    final msg = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        String tempMsg = _messageController.text;
        String tempGender = selectedGender;
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Text('设置播报文本与声音（支持 {hour} 和 {minute}）'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _messageController,
                  maxLines: 3,
                  onChanged: (v) => tempMsg = v,
                  decoration: const InputDecoration(hintText: '例如：现在是 {hour} 点 {minute} 分'),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  const Text('声音：'),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: tempGender,
                    items: const [
                      DropdownMenuItem(value: 'default', child: Text('系统默认')),
                      DropdownMenuItem(value: 'male', child: Text('男声')),
                      DropdownMenuItem(value: 'female', child: Text('女声')),
                    ],
                    onChanged: (v) => setState(() => tempGender = v ?? 'default'),
                  ),
                ]),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
              TextButton(
                  onPressed: () => Navigator.pop(context, {'msg': tempMsg.trim(), 'gender': tempGender}),
                  child: const Text('确定')),
            ],
          );
        });
      },
    );
    if (msg == null || !mounted) return;
    final message = msg['msg'] ?? '';
    final gender = msg['gender'] ?? 'default';
    if (editing == null) {
      await _addMinuteItem(picked, message, gender);
    } else {
      await _editMinuteItem(editing, picked, message, gender);
    }
  }

  Future<void> _testItemNow(MinuteItem item) async {
    final now = DateTime.now();
    final inRange = _hourInRange(now.hour);
    final payload = item.message
        .replaceAll('{hour}', now.hour.toString())
        .replaceAll('{minute}', item.minute.toString().padLeft(2, '0'));
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('enableTTS') ?? true;
    if (enabled) {
      await _speakWithGender(payload, item.voiceGender, availableVoices: availableVoices);
    } else {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'multi_min_channel',
        '报时测试',
        channelDescription: '测试通知',
        importance: Importance.max,
        priority: Priority.high,
      );
      const NotificationDetails platformDetails =
          NotificationDetails(android: androidDetails);
      await flutterLocalNotificationsPlugin.show(
        item.idBase + 999999,
        '报时测试',
        payload,
        platformDetails,
        payload: payload,
      );
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('测试已触发（当前小时在范围: $inRange）'),
    ));
  }

  Widget _buildMinuteTile(MinuteItem item) {
    final label = '${item.minute.toString().padLeft(2, '0')} 分';
    final preview = item.message
        .replaceAll('{hour}', '--')
        .replaceAll('{minute}', item.minute.toString().padLeft(2, '0'));
    final voiceLabel = item.voiceGender == 'male'
        ? '男声'
        : item.voiceGender == 'female'
            ? '女声'
            : '默认';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: MyApp.primaryColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              '${item.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: MyApp.accentColor,
              ),
            ),
          ),
        ),
        title: Text(
          '$label  （$voiceLabel）',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: MyApp.textColor,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            preview,
            style: TextStyle(
              color: MyApp.textColor.withOpacity(0.7),
            ),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildIconButton(Icons.play_arrow, () => _testItemNow(item), '立即测试'),
            _buildIconButton(Icons.edit, () => _pickMinuteAndMessage(editing: item), '编辑'),
            _buildIconButton(Icons.delete, () => _removeMinuteItem(item), '删除'),
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

  // 显示可用 voices（调试）
  Future<void> _showAvailableVoices() async {
    await _loadAvailableVoices();
    final names = availableVoices.map((v) {
      try {
        final map = v is Map ? v : Map<String, dynamic>.from(v);
        return '${map['name'] ?? map['voice'] ?? ''} (${map['locale'] ?? map['language'] ?? ''}) ${map['gender'] ?? ''}';
      } catch (_) {
        return v.toString();
      }
    }).join('\n');
    if (!mounted) return;
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
              title: const Text('可用 TTS voices（调试）'),
              content: SizedBox(
                  width: double.maxFinite,
                  child: SingleChildScrollView(child: Text(names.isEmpty ? '无' : names))),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭'))
              ],
            ));
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
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Row(children: [
                      Icon(Icons.record_voice_over, color: MyApp.accentColor, size: 24),
                      const SizedBox(width: 8),
                      const Text('语音播报', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ]),
                    Switch(
                      value: enableTTS,
                      activeColor: MyApp.accentColor,
                      onChanged: (v) async {
                        setState(() => enableTTS = v);
                        await _saveAll();
                      },
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
                            '闹铃起始日期',
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
