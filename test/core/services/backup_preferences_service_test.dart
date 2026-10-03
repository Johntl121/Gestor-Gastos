import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gestor_gastos/core/services/backup_preferences_service.dart';

void main() {
  late BackupPreferencesService backupService;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    backupService = BackupPreferencesService(prefs);
  });

  group('BackupPreferencesService Export', () {
    test('export incluye solo whitelist', () async {
      // Configuramos preferencias: 2 de whitelist, 2 de blacklist/unknown
      await prefs.setString('USER_NAME', 'Juan');
      await prefs.setDouble('BUDGET_LIMIT', 1000.5);
      await prefs.setString('SECURITY_PIN', '1234'); // excluded
      await prefs.setBool('FIRST_TIME', false); // excluded
      await prefs.setString('UNKNOWN_KEY', 'x'); // unknown

      final export = await backupService.exportPreferences();

      // Debe exportar 2 y nada más
      expect(export.length, 2);
      expect(export['USER_NAME'], 'Juan');
      expect(export['BUDGET_LIMIT'], 1000.5);
      expect(export.containsKey('SECURITY_PIN'), isFalse);
      expect(export.containsKey('FIRST_TIME'), isFalse);
      expect(export.containsKey('UNKNOWN_KEY'), isFalse);
    });

    test('export excluye migration flags y coach cache', () async {
      await prefs.setString('USER_NAME', 'Maria');
      await prefs.setInt('SCHEDULER_MIGRATION_VERSION', 2);
      await prefs.setString('weekly_advice', 'Test advice');

      final export = await backupService.exportPreferences();

      expect(export.length, 1);
      expect(export['USER_NAME'], 'Maria');
      expect(export.containsKey('SCHEDULER_MIGRATION_VERSION'), isFalse);
      expect(export.containsKey('weekly_advice'), isFalse);
    });
  });

  group('BackupPreferencesService Restore', () {
    test('unknown key en restore se ignora', () async {
      final input = {
        'USER_NAME': 'Carlos',
        'MALICIOUS_KEY': 'hacked',
      };

      await backupService.restorePreferences(input);

      // Verificamos que solo ingresó USER_NAME
      expect(prefs.getString('USER_NAME'), 'Carlos');
      expect(prefs.containsKey('MALICIOUS_KEY'), isFalse);
    });

    test('tipo inválido se rechaza según política, key ausente conserva valor actual', () async {
      // Estado previo
      await prefs.setString('USER_NAME', 'Ana');
      await prefs.setDouble('BUDGET_LIMIT', 500.0);
      await prefs.setBool('THEME_MODE', false);

      final input = {
        'BUDGET_LIMIT': 'not_a_double', // Tipo inválido, se debe rechazar y conservar 500.0
        'THEME_MODE': true, // Tipo válido, se actualiza
        // USER_NAME no está en el input, se conserva 'Ana'
      };

      await backupService.restorePreferences(input);

      expect(prefs.getString('USER_NAME'), 'Ana'); // Conserva
      expect(prefs.getDouble('BUDGET_LIMIT'), 500.0); // Conserva por fallo de tipo
      expect(prefs.getBool('THEME_MODE'), true); // Actualizado
    });

    test('tipos preservados (ej. int casteado a double para BUDGET_LIMIT)', () async {
      final input = {
        'BUDGET_LIMIT': 1500, // int
      };

      await backupService.restorePreferences(input);

      final val = prefs.getDouble('BUDGET_LIMIT');
      expect(val, isA<double>());
      expect(val, 1500.0);
    });

    test('ninguna key excluida puede ser sobrescrita desde backup manipulado', () async {
      // Estado previo seguro
      await prefs.setString('SECURITY_PIN', 'safepin');
      
      final input = {
        'USER_NAME': 'Hacker',
        'SECURITY_PIN': 'compromised', // Intentando inyectar PIN
        'ENABLE_NOTIFICATIONS': false, // Intentando cambiar setting excluido
      };

      await backupService.restorePreferences(input);

      // Verifica whitelist aplicada
      expect(prefs.getString('USER_NAME'), 'Hacker');
      
      // Verifica blacklist / keys protegidas intactas
      expect(prefs.getString('SECURITY_PIN'), 'safepin');
      expect(prefs.containsKey('ENABLE_NOTIFICATIONS'), isFalse);
    });

    test('restore válido aplica preferencias correctamente', () async {
      final input = {
        'USER_NAME': 'Pedro',
        'CURRENCY': 'USD',
        'BUDGET_LIMIT': 2000.0,
        'USER_AVATAR': '😎',
        'THEME_MODE': true,
        'EXCHANGE_RATES': '{"USD": 1.0, "PEN": 3.7}',
        'LAST_KNOWN_TIMEZONE': 'America/Lima',
      };

      await backupService.restorePreferences(input);

      expect(prefs.getString('USER_NAME'), 'Pedro');
      expect(prefs.getString('CURRENCY'), 'USD');
      expect(prefs.getDouble('BUDGET_LIMIT'), 2000.0);
      expect(prefs.getString('USER_AVATAR'), '😎');
      expect(prefs.getBool('THEME_MODE'), true);
      expect(prefs.getString('EXCHANGE_RATES'), '{"USD": 1.0, "PEN": 3.7}');
      expect(prefs.getString('LAST_KNOWN_TIMEZONE'), 'America/Lima');
    });
  });
}
