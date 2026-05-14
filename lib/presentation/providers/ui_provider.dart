import 'package:flutter/material.dart';
import '../../data/models/subscription.dart';
import '../../data/repositories/transaction_data_source.dart';

class UiProvider extends ChangeNotifier {
  final TransactionLocalDataSource localDataSource;

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

  UiProvider({required this.localDataSource}) {
    _loadUiData();
  }

  Future<void> _loadUiData() async {
    // 1. Migrar PIN si existe en texto plano (SharedPreferences)
    await localDataSource.migratePinIfNeeded();

    _userName = localDataSource.getUserName() ?? 'Usuario';
    _userAvatar = localDataSource.getUserAvatar();
    _profileImagePath = localDataSource.getProfileImagePath();
    
    // 2. Cargar PIN de forma asíncrona desde almacenamiento seguro
    _userPin = await localDataSource.getSecurityPinAsync();
    
    _isDarkMode = localDataSource.getThemeMode();
    _enableBiometrics = localDataSource.getEnableBiometrics();
    _enableNotifications = localDataSource.getEnableNotifications();

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

  void toggleTheme(bool value) {
    _isDarkMode = value;
    notifyListeners();
    localDataSource.saveThemeMode(value);
  }

  Future<void> setUserName(String name) async {
    _userName = name;
    notifyListeners();
    await localDataSource.saveUserName(name);
  }

  Future<void> setUserAvatar(String avatar) async {
    _userAvatar = avatar;
    _profileImagePath = null;
    notifyListeners();
    await localDataSource.saveUserAvatar(avatar);
    await localDataSource.saveProfileImagePath(null);
  }

  Future<void> setProfileImagePath(String? path) async {
    _profileImagePath = path;
    notifyListeners();
    await localDataSource.saveProfileImagePath(path);
  }

  void setPin(String pin) {
    _userPin = pin;
    notifyListeners();
    localDataSource.saveSecurityPin(pin);
  }

  void removePin() {
    _userPin = null;
    notifyListeners();
    localDataSource.saveSecurityPin(null);
  }

  bool verifyPin(String input) {
    return _userPin == input;
  }

  void toggleBiometrics(bool value) {
    _enableBiometrics = value;
    notifyListeners();
    localDataSource.saveEnableBiometrics(value);
  }

  void toggleNotifications(bool value) {
    _enableNotifications = value;
    notifyListeners();
    localDataSource.saveEnableNotifications(value);
  }
}
