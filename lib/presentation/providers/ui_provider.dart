import 'package:flutter/material.dart';
import '../../data/models/subscription.dart';
import '../../data/datasources/preferences_local_data_source.dart';
import '../../core/services/notification_coordinator.dart';
import '../../core/services/pin_security_service.dart';

class UiProvider extends ChangeNotifier {
  final PreferencesLocalDataSource preferencesLocalDataSource;
  final NotificationCoordinator notificationCoordinator;
  final PinSecurityService pinSecurityService;

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
  bool _hasPin = false;
  bool get isPinEnabled => _hasPin;
  bool _enableBiometrics = false;
  bool get enableBiometrics => _enableBiometrics;
  bool _enableNotifications = true;
  bool get enableNotifications => _enableNotifications;

  UiProvider({
    required this.preferencesLocalDataSource,
    required this.notificationCoordinator,
    required this.pinSecurityService,
  }) {
    _loadUiData();
  }

  Future<void> _loadUiData() async {
    // 1. Migrar PIN si existe en texto plano (SharedPreferences)
    await preferencesLocalDataSource.migratePinIfNeeded();

    _userName = preferencesLocalDataSource.getUserName() ?? 'Usuario';
    _userAvatar = preferencesLocalDataSource.getUserAvatar();
    _profileImagePath = preferencesLocalDataSource.getProfileImagePath();

    // 2. Cargar estado de PIN de forma asíncrona desde almacenamiento seguro
    final storedPin = await preferencesLocalDataSource.getSecurityPinAsync();
    _hasPin = storedPin != null;

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
    final hashedPin = await pinSecurityService.hashPin(pin);
    await preferencesLocalDataSource.saveSecurityPin(hashedPin);
    _hasPin = true;
    notifyListeners();
  }

  Future<void> removePin() async {
    await preferencesLocalDataSource.saveSecurityPin(null);
    _hasPin = false;
    notifyListeners();
  }

  Future<bool> verifyPin(String input) async {
    final storedPin = await preferencesLocalDataSource.getSecurityPinAsync();
    if (storedPin == null) return false;
    return await pinSecurityService.verifyPin(input, storedPin);
  }

  Future<void> toggleBiometrics(bool value) async {
    _enableBiometrics = value;
    notifyListeners();
    await preferencesLocalDataSource.saveEnableBiometrics(value);
  }

  Future<NotificationStatus> toggleNotifications(bool value) async {
    _enableNotifications = value;
    notifyListeners();
    
    NotificationStatus status;
    if (value) {
      status = await notificationCoordinator.enableNotifications();
      if (status == NotificationStatus.permissionDenied || 
          status == NotificationStatus.timezoneUnavailable) {
        // Si falló por permisos, la preferencia fue revertida internamente a OFF por el coordinador.
        // Sincronizamos la UI para mostrar que están OFF.
        _enableNotifications = false;
        notifyListeners();
      }
    } else {
      status = await notificationCoordinator.disableNotifications();
    }
    
    return status;
  }
}
