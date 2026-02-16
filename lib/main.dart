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
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '多分钟点报时（每点可选男女声）',
      debugShowCheckedModeBanner: false,
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
  int endHour = 22;
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
      endHour = prefs.getInt('endHour') ?? 22;
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
    await prefs.setInt('endHour', endHour);
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
    final int? picked = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('选择起始小时'),
        children: List.generate(24, (i) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(context, i),
            child: Text('${i.toString().padLeft(2, '0')}:00'),
          );
        }),
      ),
    );
    if (picked != null) {
      setState(() => startHour = picked);
      await _saveAll();
      await _scheduleAll();
    }
  }

  Future<void> _pickEndHour() async {
    final int? picked = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('选择结束小时'),
        children: List.generate(24, (i) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(context, i),
            child: Text('${i.toString().padLeft(2, '0')}:00'),
          );
        }),
      ),
    );
    if (picked != null) {
      setState(() => endHour = picked);
      await _saveAll();
      await _scheduleAll();
    }
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
      child: ListTile(
        title: Text('$label  （$voiceLabel）'),
        subtitle: Text(preview),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.play_arrow),
              onPressed: () => _testItemNow(item),
              tooltip: '立即测试',
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _pickMinuteAndMessage(editing: item),
              tooltip: '编辑',
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _removeMinuteItem(item),
              tooltip: '删除',
            ),
          ],
        ),
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
        '${startHour.toString().padLeft(2, '0')}:00 - ${endHour.toString().padLeft(2, '0')}:00';
    return Scaffold(
      appBar: AppBar(title: const Text('多分钟点报时（每点可选男女声）')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('语音播报', style: TextStyle(fontSize: 16)),
            Switch(
              value: enableTTS,
              onChanged: (v) async {
                setState(() => enableTTS = v);
                await _saveAll();
              },
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            ElevatedButton(
                onPressed: _pickStartHour,
                child: Text('起始小时：${startHour.toString().padLeft(2, '0')}:00')),
            const SizedBox(width: 12),
            ElevatedButton(
                onPressed: _pickEndHour,
                child: Text('结束小时：${endHour.toString().padLeft(2, '0')}:00')),
            const SizedBox(width: 12),
            Text('当前范围：$rangeLabel'),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            ElevatedButton.icon(
              onPressed: () => _pickMinuteAndMessage(),
              icon: const Icon(Icons.add),
              label: const Text('添加分钟点'),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                await _scheduleAll();
                messenger.showSnackBar(
                    const SnackBar(content: Text('已重新安排所有通知')));
              },
              child: const Text('重新安排'),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _showAvailableVoices,
              child: const Text('查看可用 voices'),
            ),
          ]),
          const SizedBox(height: 12),
          Expanded(
            child: minuteItems.isEmpty
                ? const Center(child: Text('尚未添加任何分钟点'))
                : ListView.builder(
                    itemCount: minuteItems.length,
                    itemBuilder: (context, index) =>
                        _buildMinuteTile(minuteItems[index]),
                  ),
          ),
        ]),
      ),
    );
  }
}
