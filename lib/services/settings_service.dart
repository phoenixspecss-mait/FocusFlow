import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class SettingsService extends ChangeNotifier {
  static final SettingsService instance = SettingsService._();
  SettingsService._();

  static const _keyNotifications = 'notifications_enabled';
  static const _keySounds        = 'sounds_enabled';
  static const _keyTheme         = 'theme_mode'; // 'dark' | 'light'
  static const _keyLanguage      = 'language';   // 'English' | 'Hindi'

  bool   _notifications = true;
  bool   _sounds        = true;
  String _theme         = 'Dark';
  String _language      = 'English';

  bool   get notifications => _notifications;
  bool   get sounds        => _sounds;
  String get theme         => _theme;
  String get language      => _language;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _notifications = p.getBool(_keyNotifications) ?? true;
    _sounds        = p.getBool(_keySounds)        ?? true;
    _theme         = p.getString(_keyTheme)       ?? 'Dark';
    _language      = p.getString(_keyLanguage)    ?? 'English';
    notifyListeners();
  }

  Future<void> setNotifications(bool v) async {
    _notifications = v;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_keyNotifications, v);
  }

  Future<void> setSounds(bool v) async {
    _sounds = v;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_keySounds, v);
  }

  Future<void> setTheme(String v) async {
    _theme = v;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString(_keyTheme, v);
  }

  Future<void> setLanguage(String v) async {
    _language = v;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString(_keyLanguage, v);
  }
}