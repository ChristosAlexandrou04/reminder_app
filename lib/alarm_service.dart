import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'alarm_screen.dart';

class AlarmService {
  AlarmService._();
  static final AlarmService instance = AlarmService._();

  final AudioPlayer _player = AudioPlayer();
  Process? _soundProcess;
  Timer? _timer;
  GlobalKey<NavigatorState>? navigatorKey;

  final Set<String> _fired = {};

  void start() {
    _timer?.cancel();
    debugPrint('[Alarm] started');
    _loadFired().then((_) {
      Future.delayed(const Duration(seconds: 3), _checkAlarms);
    });
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _checkAlarms());
  }

  Future<void> _loadFired() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('fired_alarms') ?? [];
    _fired.addAll(saved);
  }

  Future<void> _saveFired() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('fired_alarms', _fired.toList());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> stopSound() async {
    _soundProcess?.kill();
    _soundProcess = null;
    try { await _player.stop(); } catch (_) {}
  }

  Future<void> _checkAlarms() async {
    final now = DateTime.now();
    debugPrint('[Alarm] check ${now.hour}:${now.minute.toString().padLeft(2, '0')}');

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final todayPrefix =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final before = _fired.length;
      _fired.removeWhere((k) => !k.startsWith(todayPrefix));
      if (_fired.length != before) _saveFired();

      QuerySnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('reminders')
            .get();
      } catch (e) {
        debugPrint('[Alarm] Firestore error: $e');
        return;
      }

      debugPrint('[Alarm] ${snapshot.docs.length} reminder(s)');

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final timeStr = (data['time'] ?? '').toString();
        debugPrint('[Alarm] "${data['title']}" scheduled=$timeStr');

        final parts = timeStr.split(':');
        if (parts.length != 2) continue;
        final alarmHour = int.tryParse(parts[0]);
        final alarmMinute = int.tryParse(parts[1]);
        if (alarmHour == null || alarmMinute == null) continue;

        if (now.hour != alarmHour || now.minute != alarmMinute) continue;
        if (!_shouldFireToday(data, now)) continue;

        final fireKey = '$todayPrefix-${doc.id}-$timeStr';
        if (_fired.contains(fireKey)) continue;
        _fired.add(fireKey);
        _saveFired();

        debugPrint('[Alarm] FIRING "${data['title']}"');

        _showAlarmScreen(
          (data['title'] ?? 'Medication').toString(),
          (data['dosage'] ?? '').toString(),
        );

        _playSound();
      }
    } catch (e) {
      debugPrint('[Alarm] check error: $e');
    }
  }

  bool _shouldFireToday(Map<String, dynamic> data, DateTime now) {
    final repeatType = (data['repeatType'] ?? 'daily').toString();
    final startDateStr = data['startDate'] as String?;
    DateTime? startDate;
    if (startDateStr != null && startDateStr.isNotEmpty) {
      try { startDate = DateTime.parse(startDateStr); } catch (_) {}
    }
    final today = DateTime(now.year, now.month, now.day);

    switch (repeatType) {
      case 'daily':
        if (startDate == null) return true;
        return !startDate.isAfter(today);
      case 'once':
        if (startDate == null) return false;
        return startDate.year == now.year &&
            startDate.month == now.month &&
            startDate.day == now.day;
      case 'weekly':
        final weekday = data['weekday'] as int?;
        if (weekday == null) return false;
        final okStart = startDate == null ? true : !startDate.isAfter(today);
        return okStart && now.weekday == weekday;
    }
    return false;
  }

  // Called without await — runs in background so it never blocks the alarm screen
  Future<void> _playSound() async {
    if (kIsWeb || Platform.isAndroid || Platform.isIOS) {
      try {
        await _player.stop();
        await _player.setAudioContext(AudioContext(
          android: AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: false,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.alarm,
            audioFocus: AndroidAudioFocus.gain,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: {AVAudioSessionOptions.mixWithOthers},
          ),
        ));
        await _player.setVolume(1.0);
        await _player.setReleaseMode(ReleaseMode.loop);
        await _player.play(AssetSource('sounds/alarm.mp3.wav'));
      } catch (e) {
        debugPrint('[Alarm] mobile audio error: $e');
      }
      return;
    }

    // Windows / Linux / macOS: extract asset to temp file, play via PowerShell WPF MediaPlayer
    try {
      _soundProcess?.kill();
      _soundProcess = null;

      final bytes = await rootBundle.load('assets/sounds/alarm.mp3.wav');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}\\alarm.mp3.wav');
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      debugPrint('[Alarm] wrote ${file.lengthSync()} bytes to ${file.path}');

      final path = file.path.replaceAll('\\', '/');
      _soundProcess = await Process.start(
        'powershell',
        [
          '-STA', '-NonInteractive', '-WindowStyle', 'Hidden', '-Command',
          'Add-Type -AssemblyName presentationCore;'
          r'$m=New-Object System.Windows.Media.MediaPlayer;'
          '\$m.Open([uri]"$path");'
          r'$m.Volume=1;Start-Sleep -ms 1000;'
          r'while($true){$m.Play();Start-Sleep -s 10;$m.Position=[timespan]::Zero}',
        ],
      );
      debugPrint('[Alarm] sound process pid=${_soundProcess?.pid}');
    } catch (e) {
      debugPrint('[Alarm] Windows sound error: $e');
    }
  }

  void _showAlarmScreen(String title, String dosage) {
    final nav = navigatorKey?.currentState;
    debugPrint('[Alarm] nav=$nav');
    if (nav == null) return;
    nav.push(PageRouteBuilder(
      opaque: false,
      barrierDismissible: false,
      pageBuilder: (_, __, ___) => AlarmScreen(
        title: title,
        dosage: dosage,
        onDismiss: () {
          stopSound();
          nav.pop();
        },
      ),
    ));
  }
}
