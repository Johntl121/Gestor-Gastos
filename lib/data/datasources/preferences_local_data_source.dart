import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/secure_storage_service.dart';

const String keyFirstTime = 'FIRST_TIME';
const String keyUserName = 'USER_NAME';
const String keyCurrency = 'CURRENCY';
const String keyBudgetLimit = 'BUDGET_LIMIT';
const String keySecurityPin = 'SECURITY_PIN';
const String keyUserAvatar = 'USER_AVATAR';
const String keyProfileImagePath = 'PROFILE_IMAGE_PATH';
const String keyThemeMode = 'THEME_MODE';
const String keyEnableBiometrics = 'ENABLE_BIOMETRICS';
const String keyEnableNotifications = 'ENABLE_NOTIFICATIONS';
const String keyExchangeRates = 'EXCHANGE_RATES';

abstract class PreferencesLocalDataSource {
  bool isFirstTime();
  Future<void> setFirstTime(bool value);
  Future<void> saveUserName(String name);
  String? getUserName();
  Future<void> saveBudgetLimit(double amount);
  double getBudgetLimit();
  Future<void> saveCurrency(String symbol);
  String getCurrency();
  Future<void> saveSecurityPin(String? pin);
  String? getSecurityPin();
  Future<String?> getSecurityPinAsync();
  Future<void> saveUserAvatar(String avatar);
  String getUserAvatar();
  Future<void> saveProfileImagePath(String? path);
  String? getProfileImagePath();
  Future<void> saveThemeMode(bool isDark);
  bool getThemeMode();
  Future<void> saveEnableBiometrics(bool enable);
  bool getEnableBiometrics();
  Future<void> saveEnableNotifications(bool enable);
  bool getEnableNotifications();
  Future<void> clearAllPreferences();
  Future<void> migratePinIfNeeded();
  Future<void> saveExchangeRates(Map<String, double> rates);
  Map<String, double> getExchangeRates();
}

class PreferencesLocalDataSourceImpl implements PreferencesLocalDataSource {
  final SharedPreferences sharedPreferences;
  final SecureStorageService secureStorage;

  PreferencesLocalDataSourceImpl({
    required this.sharedPreferences,
    required this.secureStorage,
  });

  @override
  bool isFirstTime() => sharedPreferences.getBool(keyFirstTime) ?? true;

  @override
  Future<void> setFirstTime(bool value) => sharedPreferences.setBool(keyFirstTime, value);

  @override
  Future<void> saveUserName(String name) => sharedPreferences.setString(keyUserName, name);

  @override
  String? getUserName() => sharedPreferences.getString(keyUserName);

  @override
  Future<void> saveBudgetLimit(double amount) => sharedPreferences.setDouble(keyBudgetLimit, amount);

  @override
  double getBudgetLimit() => sharedPreferences.getDouble(keyBudgetLimit) ?? 2400.00;

  @override
  Future<void> saveCurrency(String symbol) => sharedPreferences.setString(keyCurrency, symbol);

  @override
  String getCurrency() => sharedPreferences.getString(keyCurrency) ?? 'S/';

  @override
  Future<void> saveSecurityPin(String? pin) async {
    if (pin == null) {
      await secureStorage.deletePin();
      return;
    }
    await secureStorage.savePin(pin);
  }

  @override
  String? getSecurityPin() {
    return null; 
  }

  @override
  Future<String?> getSecurityPinAsync() => secureStorage.getPin();

  @override
  Future<void> migratePinIfNeeded() async {
    final oldPin = sharedPreferences.getString(keySecurityPin);
    if (oldPin != null) {
      try {
        await secureStorage.savePin(oldPin);
        await sharedPreferences.remove(keySecurityPin);
        debugPrint("🔐 Migración exitosa: PIN movido a almacenamiento seguro");
      } catch (e) {
        debugPrint("❌ Error migrando PIN: $e");
      }
    }
  }

  @override
  Future<void> saveUserAvatar(String avatar) => sharedPreferences.setString(keyUserAvatar, avatar);

  @override
  String getUserAvatar() => sharedPreferences.getString(keyUserAvatar) ?? '😎';

  @override
  Future<void> saveProfileImagePath(String? path) {
    if (path == null) return sharedPreferences.remove(keyProfileImagePath);
    return sharedPreferences.setString(keyProfileImagePath, path);
  }

  @override
  String? getProfileImagePath() => sharedPreferences.getString(keyProfileImagePath);

  @override
  Future<void> saveThemeMode(bool isDark) => sharedPreferences.setBool(keyThemeMode, isDark);

  @override
  bool getThemeMode() => sharedPreferences.getBool(keyThemeMode) ?? true;

  @override
  Future<void> saveEnableBiometrics(bool enable) => sharedPreferences.setBool(keyEnableBiometrics, enable);

  @override
  bool getEnableBiometrics() => sharedPreferences.getBool(keyEnableBiometrics) ?? false;

  @override
  Future<void> saveEnableNotifications(bool enable) => sharedPreferences.setBool(keyEnableNotifications, enable);

  @override
  bool getEnableNotifications() => sharedPreferences.getBool(keyEnableNotifications) ?? true;

  @override
  Future<void> clearAllPreferences() async {
    final currentTheme = getThemeMode();
    await sharedPreferences.clear();
    await saveThemeMode(currentTheme);
  }

  @override
  Future<void> saveExchangeRates(Map<String, double> rates) async {
    final String jsonString = jsonEncode(rates);
    await sharedPreferences.setString(keyExchangeRates, jsonString);
  }

  @override
  Map<String, double> getExchangeRates() {
    final String? jsonString = sharedPreferences.getString(keyExchangeRates);
    if (jsonString != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(jsonString);
        return decoded.map((key, value) => MapEntry(key, (value as num).toDouble()));
      } catch (e) {
        debugPrint("Error al parsear exchange rates: $e");
      }
    }
    // Default values if none exist
    return {
      'S/': 1.0,
      '\$': 3.75,
      '€': 4.10,
      '¥': 0.025,
      '₽': 0.040,
      '₿': 350000.0,
    };
  }
}
