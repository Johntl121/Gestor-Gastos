import 'package:flutter/material.dart';
import '../../injection_container.dart';
import '../../data/models/subscription.dart';
import '../../data/repositories/transaction_data_source.dart';

class UiProvider extends ChangeNotifier {
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

  UiProvider() {
    _loadUiData();
  }

  Future<void> _loadUiData() async {
    final dataSource = sl<TransactionLocalDataSource>();
    
    // 1. Migrar PIN si existe en texto plano (SharedPreferences)
    await dataSource.migratePinIfNeeded();

    _userName = dataSource.getUserName() ?? 'Usuario';
    _userAvatar = dataSource.getUserAvatar();
    _profileImagePath = dataSource.getProfileImagePath();
    
    // 2. Cargar PIN de forma asíncrona desde almacenamiento seguro
    _userPin = await dataSource.getSecurityPinAsync();
    
    _isDarkMode = dataSource.getThemeMode();

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
    sl<TransactionLocalDataSource>().saveThemeMode(value);
  }

  Future<void> setUserName(String name) async {
    _userName = name;
    notifyListeners();
    await sl<TransactionLocalDataSource>().saveUserName(name);
  }

  Future<void> setUserAvatar(String avatar) async {
    _userAvatar = avatar;
    _profileImagePath = null;
    notifyListeners();
    await sl<TransactionLocalDataSource>().saveUserAvatar(avatar);
    await sl<TransactionLocalDataSource>().saveProfileImagePath(null);
  }

  Future<void> setProfileImagePath(String? path) async {
    _profileImagePath = path;
    notifyListeners();
    await sl<TransactionLocalDataSource>().saveProfileImagePath(path);
  }

  void setPin(String pin) {
    _userPin = pin;
    notifyListeners();
    sl<TransactionLocalDataSource>().saveSecurityPin(pin);
  }

  void removePin() {
    _userPin = null;
    notifyListeners();
    sl<TransactionLocalDataSource>().saveSecurityPin(null);
  }

  bool verifyPin(String input) {
    return _userPin == input;
  }

  void toggleBiometrics(bool value) {
    _enableBiometrics = value;
    notifyListeners();
  }

  void toggleNotifications(bool value) {
    _enableNotifications = value;
    notifyListeners();
  }
}
