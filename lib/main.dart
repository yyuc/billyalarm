import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:billyalarm/models/minute_item.dart';
import 'package:billyalarm/blocs/blocs.dart';
import 'package:billyalarm/ui/theme.dart';
import 'package:billyalarm/screens/home_page.dart';

const MethodChannel _native = MethodChannel('billyalarm/native');

@pragma('vm:entry-point')
void alarmCallback(int id) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('minute_items') ?? '[]';
    final List decoded = jsonDecode(raw);
    final items = decoded.map((e) => MinuteItem.fromJson(e)).toList();
    for (final item in items) {
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
  initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => AlarmBloc()),
        BlocProvider(create: (context) => RingtoneBloc()),
      ],
      child: MaterialApp(
        title: 'Billy Alarm',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
        home: const HomePage(),
      ),
    );
  }
}
