import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:FocusFlow/services/auth/auth_service.dart';

class TimerSettings {
  final int focusMinutes;
  final int shortBreakMinutes;
  final int longBreakMinutes;

  const TimerSettings({
    this.focusMinutes      = 25,
    this.shortBreakMinutes = 5,
    this.longBreakMinutes  = 15,
  });

  TimerSettings copyWith({
    int? focusMinutes,
    int? shortBreakMinutes,
    int? longBreakMinutes,
  }) =>
      TimerSettings(
        focusMinutes:      focusMinutes      ?? this.focusMinutes,
        shortBreakMinutes: shortBreakMinutes ?? this.shortBreakMinutes,
        longBreakMinutes:  longBreakMinutes  ?? this.longBreakMinutes,
      );

  Map<String, dynamic> toMap() => {
    'focusMinutes':      focusMinutes,
    'shortBreakMinutes': shortBreakMinutes,
    'longBreakMinutes':  longBreakMinutes,
  };

  factory TimerSettings.fromMap(Map<dynamic, dynamic> m) => TimerSettings(
    focusMinutes:      (m['focusMinutes']      as int?) ?? 25,
    shortBreakMinutes: (m['shortBreakMinutes'] as int?) ?? 5,
    longBreakMinutes:  (m['longBreakMinutes']  as int?) ?? 15,
  );
}

class TimerSettingsService extends ChangeNotifier {
  static final TimerSettingsService instance = TimerSettingsService._();
  TimerSettingsService._();

  final _db = FirebaseDatabase.instance.ref();
  String? get _uid => AuthService.firebase().currentUser?.id;

  TimerSettings _settings = const TimerSettings();
  TimerSettings get settings => _settings;
  bool _loaded = false;
  bool get loaded => _loaded;

  Future<void> load() async {
    if (_uid == null) return;
    final snap = await _db.child('timers/$_uid/settings').get();
    if (snap.exists) {
      _settings = TimerSettings.fromMap(snap.value as Map);
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> save(TimerSettings s) async {
    if (_uid == null) return;
    _settings = s;
    notifyListeners();
    await _db.child('timers/$_uid/settings').update(s.toMap());
  }

  Future<void> updateFocus(int minutes) =>
      save(_settings.copyWith(focusMinutes: minutes));

  Future<void> updateShortBreak(int minutes) =>
      save(_settings.copyWith(shortBreakMinutes: minutes));

  Future<void> updateLongBreak(int minutes) =>
      save(_settings.copyWith(longBreakMinutes: minutes));
}