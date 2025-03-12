import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _soundEnabledKey = 'sound_enabled';
  static const String _visualNotificationsEnabledKey = 'visual_notifications_enabled';

  // Singleton instance
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  Future<void> setSoundEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundEnabledKey, enabled);
  }

  Future<void> setVisualNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_visualNotificationsEnabledKey, enabled);
  }

  Future<bool> isSoundEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_soundEnabledKey) ?? true;
  }

  Future<bool> isVisualNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_visualNotificationsEnabledKey) ?? true;
  }
}