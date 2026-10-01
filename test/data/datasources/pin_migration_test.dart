import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gestor_gastos/core/services/secure_storage_service.dart';
import 'package:gestor_gastos/core/services/pin_security_service.dart';
import 'package:gestor_gastos/data/datasources/preferences_local_data_source.dart';

class MockSecureStorageService extends Mock implements SecureStorageService {}
class MockPinSecurityService extends Mock implements PinSecurityService {}

void main() {
  late MockSecureStorageService mockSecureStorage;
  late MockPinSecurityService mockPinSecurityService;
  late PreferencesLocalDataSourceImpl dataSource;

  setUp(() {
    mockSecureStorage = MockSecureStorageService();
    mockPinSecurityService = MockPinSecurityService();
    
    // Configurar fallback behaviors para PinSecurityService mock
    when(() => mockPinSecurityService.isValidFormat(any())).thenReturn(false);
    when(() => mockPinSecurityService.isLegacyPin(any())).thenAnswer((inv) {
      final data = inv.positionalArguments[0] as String;
      if (data.length != 4) return false;
      return RegExp(r'^[0-9]+$').hasMatch(data);
    });
    when(() => mockPinSecurityService.hashPin(any())).thenAnswer((inv) async => 'v1:pbkdf2-sha256:100000:salt:hash');
  });

  group('Pin Migration', () {
    test('migración SharedPreferences -> v1', () async {
      SharedPreferences.setMockInitialValues({keySecurityPin: '1234'});
      final sharedPreferences = await SharedPreferences.getInstance();
      
      dataSource = PreferencesLocalDataSourceImpl(
        sharedPreferences: sharedPreferences,
        secureStorage: mockSecureStorage,
        pinSecurityService: mockPinSecurityService,
      );

      when(() => mockSecureStorage.getPin()).thenAnswer((_) async => null);
      when(() => mockSecureStorage.savePin(any())).thenAnswer((_) async => {});

      await dataSource.migratePinIfNeeded();

      verify(() => mockSecureStorage.getPin()).called(1);
      verify(() => mockPinSecurityService.hashPin('1234')).called(1);
      verify(() => mockSecureStorage.savePin('v1:pbkdf2-sha256:100000:salt:hash')).called(1);
      
      expect(sharedPreferences.getString(keySecurityPin), isNull);
    });

    test('migración SecureStorage plaintext -> v1', () async {
      SharedPreferences.setMockInitialValues({});
      final sharedPreferences = await SharedPreferences.getInstance();
      
      dataSource = PreferencesLocalDataSourceImpl(
        sharedPreferences: sharedPreferences,
        secureStorage: mockSecureStorage,
        pinSecurityService: mockPinSecurityService,
      );

      when(() => mockSecureStorage.getPin()).thenAnswer((_) async => '4321');
      when(() => mockSecureStorage.savePin(any())).thenAnswer((_) async => {});

      await dataSource.migratePinIfNeeded();

      verify(() => mockSecureStorage.getPin()).called(1);
      verify(() => mockPinSecurityService.hashPin('4321')).called(1);
      verify(() => mockSecureStorage.savePin('v1:pbkdf2-sha256:100000:salt:hash')).called(1);
    });

    test('SecureStorage tiene prioridad (ambos contienen legacy)', () async {
      SharedPreferences.setMockInitialValues({keySecurityPin: '1111'}); // SharedPreferences has 1111
      final sharedPreferences = await SharedPreferences.getInstance();
      
      dataSource = PreferencesLocalDataSourceImpl(
        sharedPreferences: sharedPreferences,
        secureStorage: mockSecureStorage,
        pinSecurityService: mockPinSecurityService,
      );

      when(() => mockSecureStorage.getPin()).thenAnswer((_) async => '2222'); // SecureStorage has 2222
      when(() => mockSecureStorage.savePin(any())).thenAnswer((_) async => {});

      await dataSource.migratePinIfNeeded();

      verify(() => mockSecureStorage.getPin()).called(1);
      verify(() => mockPinSecurityService.hashPin('2222')).called(1); // Migrates SecureStorage's legacy
      verifyNever(() => mockPinSecurityService.hashPin('1111')); // Ignores SharedPreferences
      verify(() => mockSecureStorage.savePin('v1:pbkdf2-sha256:100000:salt:hash')).called(1);
      
      expect(sharedPreferences.getString(keySecurityPin), isNull); // Still cleans up SP
    });

    test('migración idempotente', () async {
      SharedPreferences.setMockInitialValues({});
      final sharedPreferences = await SharedPreferences.getInstance();
      
      dataSource = PreferencesLocalDataSourceImpl(
        sharedPreferences: sharedPreferences,
        secureStorage: mockSecureStorage,
        pinSecurityService: mockPinSecurityService,
      );

      when(() => mockSecureStorage.getPin()).thenAnswer((_) async => 'v1:pbkdf2-sha256:100000:salt:hash');
      when(() => mockPinSecurityService.isValidFormat('v1:pbkdf2-sha256:100000:salt:hash')).thenReturn(true);
      
      await dataSource.migratePinIfNeeded();

      verify(() => mockSecureStorage.getPin()).called(1);
      verifyNever(() => mockPinSecurityService.hashPin(any()));
      verifyNever(() => mockSecureStorage.savePin(any()));
    });

    test('desbloqueo después de migración (integration logic)', () async {
      // Usaremos instancias reales de PinSecurityService para verificar el hash y verify
      final realPinService = PinSecurityService();
      
      SharedPreferences.setMockInitialValues({keySecurityPin: '5678'});
      final sharedPreferences = await SharedPreferences.getInstance();
      
      // Variable para guardar lo que se escriba en SecureStorage
      String? savedToSecureStorage;
      
      dataSource = PreferencesLocalDataSourceImpl(
        sharedPreferences: sharedPreferences,
        secureStorage: mockSecureStorage,
        pinSecurityService: realPinService,
      );

      when(() => mockSecureStorage.getPin()).thenAnswer((_) async => null);
      when(() => mockSecureStorage.savePin(any())).thenAnswer((inv) async {
        savedToSecureStorage = inv.positionalArguments[0] as String;
      });

      await dataSource.migratePinIfNeeded();
      
      expect(savedToSecureStorage, isNotNull);
      
      // Simulamos que el usuario intenta desbloquear
      final isVerified = await realPinService.verifyPin('5678', savedToSecureStorage!);
      expect(isVerified, isTrue);
    });

    test('SecureStorage corrupto no hace fallback a SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({keySecurityPin: '9999'}); // SharedPreferences has valid legacy
      final sharedPreferences = await SharedPreferences.getInstance();
      
      dataSource = PreferencesLocalDataSourceImpl(
        sharedPreferences: sharedPreferences,
        secureStorage: mockSecureStorage,
        pinSecurityService: mockPinSecurityService,
      );

      // SecureStorage has garbage (neither v1 nor legacy)
      when(() => mockSecureStorage.getPin()).thenAnswer((_) async => 'garbage_data');
      // No mock for hashPin because it shouldn't be called
      when(() => mockSecureStorage.savePin(any())).thenAnswer((_) async => {});

      await dataSource.migratePinIfNeeded();

      verify(() => mockSecureStorage.getPin()).called(1);
      verifyNever(() => mockPinSecurityService.hashPin(any()));
      verifyNever(() => mockSecureStorage.savePin(any()));
      
      // The SharedPreferences PIN is left alone, but not migrated
      expect(sharedPreferences.getString(keySecurityPin), '9999');
    });
  });
}
