import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:gestor_gastos/injection_container.dart' as di;
import 'package:gestor_gastos/core/services/snapshot_service.dart';
import 'package:gestor_gastos/domain/services/backup_creation_service.dart';
import 'package:gestor_gastos/domain/services/backup_restore_service.dart';
import 'package:gestor_gastos/domain/usecases/create_backup_usecase.dart';
import 'package:gestor_gastos/domain/usecases/restore_backup_usecase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await di.sl.reset();
    await di.init();
  });

  tearDown(() async {
    await di.sl.reset();
  });

  group('DI: Grafo de producción de Backup y Restore', () {
    test('Resuelve SnapshotService real sin mocks', () {
      final snapshotService = di.sl<SnapshotService>();
      expect(snapshotService, isNotNull);
      expect(snapshotService, isA<SnapshotService>());
    });

    test(
        'Resuelve BackupCreationService real con todas sus dependencias transitivas',
        () {
      final creationService = di.sl<BackupCreationService>();
      expect(creationService, isNotNull);
      expect(creationService, isA<BackupCreationService>());
    });

    test('Resuelve CreateBackupUseCase real con grafo completo', () {
      final createUseCase = di.sl<CreateBackupUseCase>();
      expect(createUseCase, isNotNull);
      expect(createUseCase, isA<CreateBackupUseCase>());
    });

    test(
        'Resuelve BackupRestoreService real con todas sus dependencias transitivas',
        () {
      final restoreService = di.sl<BackupRestoreService>();
      expect(restoreService, isNotNull);
      expect(restoreService, isA<BackupRestoreService>());
    });

    test('Resuelve RestoreBackupUseCase real con grafo completo', () {
      final restoreUseCase = di.sl<RestoreBackupUseCase>();
      expect(restoreUseCase, isNotNull);
      expect(restoreUseCase, isA<RestoreBackupUseCase>());
    });
  });
}
