import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gestor_gastos/core/services/notification_coordinator.dart';
import 'package:gestor_gastos/core/services/pin_security_service.dart';
import 'package:gestor_gastos/core/services/secure_storage_service.dart';
import 'package:gestor_gastos/data/datasources/preferences_local_data_source.dart';
import 'package:gestor_gastos/presentation/providers/ui_provider.dart';

class MockNotificationCoordinator extends Mock implements NotificationCoordinator {}
class MockSecureStorageService extends Mock implements SecureStorageService {}

void main() {
  late MockNotificationCoordinator mockNotificationCoordinator;
  late MockSecureStorageService mockSecureStorage;
  late PinSecurityService pinSecurityService;
  late PreferencesLocalDataSourceImpl dataSource;
  late UiProvider uiProvider;
  
  String? fakeSecureStorageData;

  setUp(() async {
    mockNotificationCoordinator = MockNotificationCoordinator();
    mockSecureStorage = MockSecureStorageService();
    pinSecurityService = PinSecurityService();
    
    fakeSecureStorageData = null;
    when(() => mockSecureStorage.getPin()).thenAnswer((_) async => fakeSecureStorageData);
    when(() => mockSecureStorage.savePin(any())).thenAnswer((inv) async {
      fakeSecureStorageData = inv.positionalArguments[0] as String?;
    });
    when(() => mockSecureStorage.deletePin()).thenAnswer((_) async {
      fakeSecureStorageData = null;
    });

    SharedPreferences.setMockInitialValues({});
    final sharedPreferences = await SharedPreferences.getInstance();

    dataSource = PreferencesLocalDataSourceImpl(
      sharedPreferences: sharedPreferences,
      secureStorage: mockSecureStorage,
      pinSecurityService: pinSecurityService,
    );

    uiProvider = UiProvider(
      preferencesLocalDataSource: dataSource,
      notificationCoordinator: mockNotificationCoordinator,
      pinSecurityService: pinSecurityService,
    );
    
    // Wait for the constructor's _loadUiData to finish (it uses async internally but constructor is sync)
    // we just use a small delay in tests to make sure it's loaded
    await Future.delayed(const Duration(milliseconds: 50));
  });

  group('UiProvider PIN Operations', () {
    test('Verificar cambio de PIN genera un salt nuevo y el PIN anterior deja de ser válido', () async {
      // 1. Set PIN 1234
      await uiProvider.setPin('1234');
      final firstCredential = fakeSecureStorageData;
      expect(firstCredential, isNotNull);
      expect(uiProvider.isPinEnabled, isTrue);

      // 2. Verify 1234
      var isVerified = await uiProvider.verifyPin('1234');
      expect(isVerified, isTrue);

      // 3. Change PIN to 5678
      await uiProvider.setPin('5678');
      final secondCredential = fakeSecureStorageData;
      expect(secondCredential, isNotNull);
      expect(firstCredential, isNot(equals(secondCredential)));
      
      // Extract salt from both
      final firstSalt = firstCredential!.split(':')[3];
      final secondSalt = secondCredential!.split(':')[3];
      expect(firstSalt, isNot(equals(secondSalt)));

      // 4. Verify new PIN is true
      isVerified = await uiProvider.verifyPin('5678');
      expect(isVerified, isTrue);

      // 5. Verify old PIN is false
      isVerified = await uiProvider.verifyPin('1234');
      expect(isVerified, isFalse);
    });

    test('Verificar eliminación del PIN', () async {
      // 1. Set PIN
      await uiProvider.setPin('1234');
      expect(uiProvider.isPinEnabled, isTrue);
      expect(fakeSecureStorageData, isNotNull);

      // 2. Remove PIN
      await uiProvider.removePin();
      expect(uiProvider.isPinEnabled, isFalse);
      expect(fakeSecureStorageData, isNull);

      // 3. Verify PIN no longer unlocks
      final isVerified = await uiProvider.verifyPin('1234');
      expect(isVerified, isFalse);
      
      // Also verify sharedPreferences is empty for the PIN key
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(keySecurityPin), isNull);
    });
  });
}
