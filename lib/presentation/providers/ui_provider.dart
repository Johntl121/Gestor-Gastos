import 'package:flutter/material.dart';
import '../../data/models/subscription.dart';
import '../../data/datasources/preferences_local_data_source.dart';

class UiProvider extends ChangeNotifier {
  final PreferencesLocalDataSource preferencesLocalDataSource;

  // Theme
  bool _isDarkMode = true;
  bool get isDarkMode => _isDarkMode;

  // Navigation
  int _currentIndex = 0;
  int get currentIndex => _currentIndex;

  // Pending payment action (set from notification to auto-open payment dialog)
  Subscription? _pendingPaySubscription;
  Subscription? get pendingPaySubscription => _pendingPaySubscription;

  void setPendingPaySubscription(Subscription? sub) {
    _pendingPaySubscription = sub;
    notifyListeners();
  }

  // Global Loading
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // User Profile
  String _userName = 'Usuario';
  String _userAvatar = '😎';
  String? _profileImagePath;

  String get userName => _userName;
  String get userAvatar => _userAvatar;
  String? get profileImagePath => _profileImagePath;

  // Security
  String? _userPin;
  bool get isPinEnabled => _userPin != null;
  bool _enableBiometrics = false;
  bool get enableBiometrics => _enableBiometrics;
  bool _enableNotifications = true;
  bool get enableNotifications => _enableNotifications;

  UiProvider({required this.preferencesLocalDataSource}) {
    _loadUiData();
  }

  Future<void> _loadUiData() async {
    // 1. Migrar PIN si existe en texto plano (SharedPreferences)
    await preferencesLocalDataSource.migratePinIfNeeded();

    _userName = preferencesLocalDataSource.getUserName() ?? 'Usuario';
    _userAvatar = preferencesLocalDataSource.getUserAvatar();
    _profileImagePath = preferencesLocalDataSource.getProfileImagePath();
    
    // 2. Cargar PIN de forma asíncrona desde almacenamiento seguro
    _userPin = await preferencesLocalDataSource.getSecurityPinAsync();
    
    _isDarkMode = preferencesLocalDataSource.getThemeMode();
    _enableBiometrics = preferencesLocalDataSource.getEnableBiometrics();
    _enableNotifications = preferencesLocalDataSource.getEnableNotifications();

    notifyListeners();
  }

  void setIndex(int index) {
    _currentIndex = index;
    notifyListeners();
  }

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<void> toggleTheme(bool value) async {
    _isDarkMode = value;
    notifyListeners();
    await preferencesLocalDataSource.saveThemeMode(value);
  }

  Future<void> setUserName(String name) async {
    _userName = name;
    notifyListeners();
    await preferencesLocalDataSource.saveUserName(name);
  }

  Future<void> setUserAvatar(String avatar) async {
    _userAvatar = avatar;
    _profileImagePath = null;
    notifyListeners();
    await preferencesLocalDataSource.saveUserAvatar(avatar);
    await preferencesLocalDataSource.saveProfileImagePath(null);
  }

  Future<void> setProfileImagePath(String? path) async {
    _profileImagePath = path;
    notifyListeners();
    await preferencesLocalDataSource.saveProfileImagePath(path);
  }

  Future<void> setPin(String pin) async {
    _userPin = pin;
    notifyListeners();
    await preferencesLocalDataSource.saveSecurityPin(pin);
  }

  Future<void> removePin() async {
    _userPin = null;
    notifyListeners();
    await preferencesLocalDataSource.saveSecurityPin(null);
  }

  bool verifyPin(String input) {
    return _userPin == input;
  }

  Future<void> toggleBiometrics(bool value) async {
    _enableBiometrics = value;
    notifyListeners();
    await preferencesLocalDataSource.saveEnableBiometrics(value);
  }

  Future<void> toggleNotifications(bool value) async {
    _enableNotifications = value;
    notifyListeners();
    await preferencesLocalDataSource.saveEnableNotifications(value);
  }
}
