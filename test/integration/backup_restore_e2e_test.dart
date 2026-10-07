import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:gestor_gastos/core/constants/app_constants.dart';
import 'package:gestor_gastos/core/services/app_info_provider.dart';
import 'package:gestor_gastos/core/services/attachment_storage_service.dart';
import 'package:gestor_gastos/core/services/backup_crypto_service.dart';
import 'package:gestor_gastos/core/services/backup_preferences_service.dart';
import 'package:gestor_gastos/core/services/database_helper.dart';
import 'package:gestor_gastos/core/services/restore_service.dart';
import 'package:gestor_gastos/core/services/snapshot_service.dart';
import 'package:gestor_gastos/data/datasources/goal_local_data_source.dart';
import 'package:gestor_gastos/data/datasources/preferences_local_data_source.dart';
import 'package:gestor_gastos/data/datasources/subscription_local_data_source.dart';
import 'package:gestor_gastos/data/datasources/transaction_local_data_source.dart';
import 'package:gestor_gastos/data/models/goal_model.dart';
import 'package:gestor_gastos/data/models/subscription.dart';
import 'package:gestor_gastos/data/repositories/account_repository_impl.dart';
import 'package:gestor_gastos/data/repositories/subscription_operations_repository_impl.dart';
import 'package:gestor_gastos/data/repositories/transaction_repository_impl.dart';
import 'package:gestor_gastos/data/services/backup_creation_service_impl.dart';
import 'package:gestor_gastos/data/services/backup_restore_service_impl.dart';
import 'package:gestor_gastos/domain/entities/account_entity.dart';
import 'package:gestor_gastos/domain/entities/transaction_entity.dart';
import 'package:gestor_gastos/domain/repositories/account_repository.dart';
import 'package:gestor_gastos/domain/usecases/create_backup_usecase.dart';
import 'package:gestor_gastos/domain/usecases/restore_backup_usecase.dart';
import 'package:gestor_gastos/domain/usecases/subscriptions/pay_subscription_usecase.dart';

class FakeAppInfoProvider implements AppInfoProvider {
  final String version;
  FakeAppInfoProvider({this.version = '1.0.0'});

  @override
  Future<String> getAppVersion() async => version;
}

class FakePreferencesLocalDataSource extends Fake
    implements PreferencesLocalDataSource {
  String currency = 'S/';
  double budgetLimit = 0.0;
  final Map<String, double> rates = {};

  @override
  String getCurrency() => currency;

  @override
  double getBudgetLimit() => budgetLimit;

  @override
  Future<void> saveBudgetLimit(double amount) async {
    budgetLimit = amount;
  }

  @override
  Map<String, double> getExchangeRates() => rates;
}

Future<double> getAccountCurrentBalance(
    AccountRepository repo, int accountId) async {
  final accounts = (await repo.getAccounts()).getOrElse(() => []);
  final acc = accounts.firstWhere((a) => a.id == accountId);
  return acc.currentBalance;
}

void main() {
  late LocalDatabase localDatabase;
  late Directory tempDir;
  late String dbPath;
  late List<String> filesToClean;
  late FakePreferencesLocalDataSource fakePrefsDs;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('backup_e2e_test_');
    fakePrefsDs = FakePreferencesLocalDataSource();

    final databasesPath = await getDatabasesPath();
    dbPath = p.join(databasesPath, 'gestor_gastos.db');
    filesToClean = [
      dbPath,
      '$dbPath.restore',
      '$dbPath.fallback',
      '$dbPath-journal',
      '$dbPath-wal',
      '$dbPath-shm',
      p.join(databasesPath, 'gestor_gastos.restore.pending'),
    ];

    localDatabase = LocalDatabase();
    await localDatabase.closeAndRelease();

    for (final f in filesToClean) {
      final file = File(f);
      if (await file.exists()) {
        await file.delete();
      }
    }

    await localDatabase.forceOpen();
    await localDatabase.clearAllTables();
  });

  tearDown(() async {
    await localDatabase.closeAndRelease();

    for (final f in filesToClean) {
      final file = File(f);
      if (await file.exists()) {
        await file.delete();
      }
    }

    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('FASE 13A-09: Validación End-to-End de Backup y Restore', () {
    test('E2E-01: Ciclo completo financiero e integridad relacional', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final backupPrefsService = BackupPreferencesService(prefs);

      final attachmentService = AttachmentStorageServiceImpl(
        getDocsDirProvider: () async => tempDir,
      );
      final cryptoService = BackupCryptoService();
      final appInfoProvider = FakeAppInfoProvider();
      final snapshotService = SnapshotService(localDatabase: localDatabase);
      final restoreService = RestoreService(localDatabase: localDatabase);

      final creationService = BackupCreationServiceImpl(
        snapshotService: snapshotService,
        preferencesService: backupPrefsService,
        attachmentService: attachmentService,
        cryptoService: cryptoService,
        appInfoProvider: appInfoProvider,
        getDocsDirProvider: () async => tempDir,
      );

      final backupRestoreService = BackupRestoreServiceImpl(
        restoreService: restoreService,
        preferencesService: backupPrefsService,
        attachmentService: attachmentService,
        cryptoService: cryptoService,
        appInfoProvider: appInfoProvider,
        getDocsDirProvider: () async => tempDir,
      );

      final createBackupUseCase = CreateBackupUseCase(creationService);
      final restoreBackupUseCase = RestoreBackupUseCase(backupRestoreService);

      // Repositorios y fuentes de datos reales
      final transactionLocalDataSource =
          TransactionLocalDataSourceImpl(localDatabase: localDatabase);
      final transactionRepo = TransactionRepositoryImpl(
        localDatabase: localDatabase,
        transactionLocalDataSource: transactionLocalDataSource,
      );

      final accountRepo = AccountRepositoryImpl(
        localDatabase: localDatabase,
        preferencesLocalDataSource: fakePrefsDs,
      );

      final goalDataSource =
          GoalLocalDataSourceImpl(localDatabase: localDatabase);
      final subscriptionDataSource =
          SubscriptionLocalDataSourceImpl(localDatabase: localDatabase);
      final subscriptionOpsRepo =
          SubscriptionOperationsRepositoryImpl(localDatabase: localDatabase);
      final paySubscriptionUseCase =
          PaySubscriptionUseCase(subscriptionOpsRepo);

      // --- 1. CONSTRUIR ESTADO A ---
      // 1.1 Cuentas
      final acc1Result = await accountRepo.createAccount(
        const AccountEntity(
          id: 0,
          name: 'Cuenta Principal',
          isCash: true,
          initialBalance: 1000.0,
          colorValue: 0xFF2196F3,
          iconCode: 58343,
          currencySymbol: 'S/',
        ),
      );
      final acc1Id = acc1Result.getOrElse(() => throw Exception('Fallo acc1'));

      final acc2Result = await accountRepo.createAccount(
        const AccountEntity(
          id: 0,
          name: 'Cuenta Ahorros',
          isCash: false,
          initialBalance: 500.0,
          colorValue: 0xFF4CAF50,
          iconCode: 58344,
          currencySymbol: 'S/',
        ),
      );
      final acc2Id = acc2Result.getOrElse(() => throw Exception('Fallo acc2'));

      // 1.2 Transacciones (ingreso, gasto, transferencia)
      // Categorías Core (1..15): 1 = Comida (EXPENSE), 14 = Regalos/Ingreso, 15 = Otros Ingresos (INCOME)
      await transactionRepo.addTransaction(
        TransactionEntity(
          accountId: acc1Id,
          categoryId: 15, // Otros Ingresos
          amount: 2000.0,
          date: DateTime(2026, 10, 1, 10, 0),
          description: 'Sueldo Octubre',
          type: TransactionType.income,
        ),
        updateBalance: true,
      );

      await transactionRepo.addTransaction(
        TransactionEntity(
          accountId: acc1Id,
          categoryId: 1, // Comida
          amount: -300.0,
          date: DateTime(2026, 10, 2, 14, 0),
          description: 'Almuerzo familiar',
          type: TransactionType.expense,
        ),
        updateBalance: true,
      );

      await transactionRepo.addTransaction(
        TransactionEntity(
          accountId: acc1Id,
          destinationAccountId: acc2Id,
          categoryId: AppConstants.transferCategoryId,
          amount: 400.0,
          date: DateTime(2026, 10, 3, 11, 0),
          description: 'Ahorro programado',
          type: TransactionType.transfer,
        ),
        updateBalance: true,
      );

      // 1.3 Meta (categoryId 1 = Comida o Core válida)
      final goal = GoalModel(
        id: 'goal-vacaciones-01',
        name: 'Vacaciones 2027',
        targetAmount: 5000.0,
        currentAmount: 400.0,
        iconCode: 58343,
        colorValue: 0xFF00BCD4,
        accountId: acc2Id,
        categoryId: 1,
        orderIndex: 0,
      );
      await goalDataSource.saveGoal(goal);

      // 1.4 Suscripción y Pago vinculado (FASE 11)
      final sub = Subscription(
        id: 'sub-netflix-99',
        name: 'Netflix Premium',
        amount: 50.0,
        paymentDate: DateTime(2026, 10, 15),
        frequency: ExpenseFrequency.monthly,
        categoryId: 1, // Core válida
        accountToCharge: acc1Id,
        orderIndex: 0,
      );
      await subscriptionDataSource.saveSubscription(sub);

      final payResult = await paySubscriptionUseCase(
        PaySubscriptionParams(subscription: sub),
      );
      expect(payResult.isRight(), isTrue);

      // 1.5 Preferencia de Presupuesto
      await prefs.setDouble('BUDGET_LIMIT', 1800.0);

      // --- 2. SNAPSHOT ESTADO A ---
      final balanceAcc1Snapshot =
          await getAccountCurrentBalance(accountRepo, acc1Id);
      final balanceAcc2Snapshot =
          await getAccountCurrentBalance(accountRepo, acc2Id);

      // Cuenta 1: 1000 + 2000 - 300 - 400 - 50 = 2250.0
      expect(balanceAcc1Snapshot, 2250.0);
      // Cuenta 2: 500 + 400 = 900.0
      expect(balanceAcc2Snapshot, 900.0);

      final txsBefore = (await transactionRepo.getTransactions(limit: 100))
          .getOrElse(() => []);
      expect(txsBefore.length, 4);

      final linkedPaymentTx = txsBefore.firstWhere(
        (tx) => tx.subscriptionId == 'sub-netflix-99',
      );
      expect(linkedPaymentTx.amount, -50.0);

      // --- 3. CREATE BACKUP (.gestorbackup) ---
      const backupPassword = 'StrongPassword2026!';
      final createResult = await createBackupUseCase(
        CreateBackupParams(password: backupPassword),
      );
      expect(createResult.isRight(), isTrue);

      final backupFilePath = createResult.fold(
        (l) => throw Exception(l.message),
        (r) => r.backupFilePath,
      );
      expect(await File(backupFilePath).exists(), isTrue);

      final encBytes = await File(backupFilePath).readAsBytes();
      final decBytes = await cryptoService.decrypt(encBytes, backupPassword);
      final arch = ZipDecoder().decodeBytes(decBytes);
      final dbEntry = arch.files.firstWhere((f) => f.name == 'gestor_gastos.db');
      final tempInspectedDb = File(p.join(tempDir.path, 'inspected.db'));
      await tempInspectedDb.writeAsBytes(dbEntry.content as List<int>);
      final testDb = await openDatabase(tempInspectedDb.path);
      final accsInBackup = await testDb.query('accounts');
      expect(accsInBackup.isNotEmpty, isTrue);
      await testDb.close();

      // --- 4. MUTACIÓN / DESTRUCCIÓN DEL ESTADO A ---
      final db = await localDatabase.database;
      await db.update('accounts', {'balance': 99999.0},
          where: 'id = ?', whereArgs: [acc1Id]);
      await db.delete('fixed_expenses',
          where: 'id = ?', whereArgs: ['sub-netflix-99']);
      await db
          .delete('goals', where: 'id = ?', whereArgs: ['goal-vacaciones-01']);
      await db.delete('transactions');
      await prefs.setDouble('BUDGET_LIMIT', 50.0);

      // Verificar que el estado quedó mutado
      final mutatedBalance =
          await getAccountCurrentBalance(accountRepo, acc1Id);
      expect(mutatedBalance, 99999.0);
      final mutatedTxs = (await transactionRepo.getTransactions(limit: 100))
          .getOrElse(() => []);
      expect(mutatedTxs.isEmpty, isTrue);

      // --- 5. RESTORE BACKUP ---
      final restoreResult = await restoreBackupUseCase(
        backupFilePath,
        backupPassword,
      );
      if (restoreResult.isLeft()) {
        fail(
            'E2E-01 restore falló: ${restoreResult.fold((l) => l.message, (r) => '')}');
      }
      expect(restoreResult.isRight(), isTrue);

      // Reabrir conexión limpia a la base restaurada
      await localDatabase.closeAndRelease();

      // --- 6. ASSERT VERIFICACIÓN DE ESTADO A RECUPERADO ---
      final restoredBalanceAcc1 =
          await getAccountCurrentBalance(accountRepo, acc1Id);
      final restoredBalanceAcc2 =
          await getAccountCurrentBalance(accountRepo, acc2Id);

      expect(restoredBalanceAcc1, balanceAcc1Snapshot);
      expect(restoredBalanceAcc2, balanceAcc2Snapshot);

      final restoredTxs = (await transactionRepo.getTransactions(limit: 100))
          .getOrElse(() => []);
      expect(restoredTxs.length, 4);

      // Invariante FASE 11: Transaction.subscriptionId intacta y enlazada
      final restoredPaymentTx = restoredTxs.firstWhere(
        (tx) => tx.subscriptionId == 'sub-netflix-99',
      );
      expect(restoredPaymentTx.description, 'Netflix Premium');
      expect(restoredPaymentTx.amount, -50.0);

      final restoredSubs = await subscriptionDataSource.getSubscriptions();
      expect(restoredSubs.any((s) => s.id == 'sub-netflix-99'), isTrue);

      final restoredGoals = await goalDataSource.getGoals();
      expect(restoredGoals.any((g) => g.id == 'goal-vacaciones-01'), isTrue);
      expect(
          restoredGoals
              .firstWhere((g) => g.id == 'goal-vacaciones-01')
              .targetAmount,
          5000.0);

      expect(prefs.getDouble('BUDGET_LIMIT'), 1800.0);
    });

    test(
        'E2E-02: Whitelist de preferencias se restaura y blacklist permanece local',
        () async {
      // SharedPreferences de origen
      SharedPreferences.setMockInitialValues({
        // Whitelist
        'USER_NAME': 'Carlos Mendoza',
        'CURRENCY': 'EUR',
        'BUDGET_LIMIT': 3200.0,
        'USER_AVATAR': '🦁',
        'THEME_MODE': false,
        'EXCHANGE_RATES': '{"EUR":1.0,"USD":1.08}',
        'LAST_KNOWN_TIMEZONE': 'Europe/Madrid',
        // Blacklist (no deben exportarse ni restaurarse)
        'FIRST_TIME': false,
        'ENABLE_NOTIFICATIONS': false,
        'PROFILE_IMAGE_PATH': '/origin/avatar/carlos.jpg',
        'SCHEDULER_MIGRATION_VERSION': 50,
      });

      var prefs = await SharedPreferences.getInstance();
      var backupPrefsService = BackupPreferencesService(prefs);
      final attachmentService = AttachmentStorageServiceImpl(
        getDocsDirProvider: () async => tempDir,
      );
      final cryptoService = BackupCryptoService();
      final appInfoProvider = FakeAppInfoProvider();
      final snapshotService = SnapshotService(localDatabase: localDatabase);
      final restoreService = RestoreService(localDatabase: localDatabase);

      final creationService = BackupCreationServiceImpl(
        snapshotService: snapshotService,
        preferencesService: backupPrefsService,
        attachmentService: attachmentService,
        cryptoService: cryptoService,
        appInfoProvider: appInfoProvider,
        getDocsDirProvider: () async => tempDir,
      );

      final createBackupUseCase = CreateBackupUseCase(creationService);

      const password = 'PrefsPassword123!';
      final createResult = await createBackupUseCase(
        CreateBackupParams(password: password),
      );
      expect(createResult.isRight(), isTrue);
      final backupFilePath =
          createResult.getOrElse(() => throw Exception('')).backupFilePath;

      // Dispositivo Destino previo al restore (valores distintos)
      SharedPreferences.setMockInitialValues({
        'USER_NAME': 'Usuario Inicial',
        'CURRENCY': 'PEN',
        'BUDGET_LIMIT': 500.0,
        'USER_AVATAR': '👤',
        'THEME_MODE': true,
        // Blacklist local del destino que debe permanecer intocada
        'FIRST_TIME': true,
        'ENABLE_NOTIFICATIONS': true,
        'PROFILE_IMAGE_PATH': '/dest/local_avatar.png',
        'SCHEDULER_MIGRATION_VERSION': 1,
      });

      prefs = await SharedPreferences.getInstance();
      backupPrefsService = BackupPreferencesService(prefs);

      final backupRestoreService = BackupRestoreServiceImpl(
        restoreService: restoreService,
        preferencesService: backupPrefsService,
        attachmentService: attachmentService,
        cryptoService: cryptoService,
        appInfoProvider: appInfoProvider,
        getDocsDirProvider: () async => tempDir,
      );

      final restoreBackupUseCase = RestoreBackupUseCase(backupRestoreService);
      final restoreResult =
          await restoreBackupUseCase(backupFilePath, password);
      if (restoreResult.isLeft()) {
        fail(
            'E2E-02 restore falló: ${restoreResult.fold((l) => l.message, (r) => '')}');
      }
      expect(restoreResult.isRight(), isTrue);

      // Verificación Whitelist: restauradas
      expect(prefs.getString('USER_NAME'), 'Carlos Mendoza');
      expect(prefs.getString('CURRENCY'), 'EUR');
      expect(prefs.getDouble('BUDGET_LIMIT'), 3200.0);
      expect(prefs.getString('USER_AVATAR'), '🦁');
      expect(prefs.getBool('THEME_MODE'), false);
      expect(prefs.getString('EXCHANGE_RATES'), '{"EUR":1.0,"USD":1.08}');
      expect(prefs.getString('LAST_KNOWN_TIMEZONE'), 'Europe/Madrid');

      // Verificación Blacklist: conservan valores locales del destino
      expect(prefs.getBool('FIRST_TIME'), true);
      expect(prefs.getBool('ENABLE_NOTIFICATIONS'), true);
      expect(prefs.getString('PROFILE_IMAGE_PATH'), '/dest/local_avatar.png');
      expect(prefs.getInt('SCHEDULER_MIGRATION_VERSION'), 1);
    });

    test(
        'E2E-03: Invariante de seguridad (PIN y Biometría no son alterados por restore)',
        () async {
      // Origen con PIN y biometría desactivada
      SharedPreferences.setMockInitialValues({
        'USER_NAME': 'Origen Seguro',
        'SECURITY_PIN': '1234',
        'ENABLE_BIOMETRICS': false,
      });

      var prefs = await SharedPreferences.getInstance();
      var backupPrefsService = BackupPreferencesService(prefs);
      final attachmentService = AttachmentStorageServiceImpl(
        getDocsDirProvider: () async => tempDir,
      );
      final cryptoService = BackupCryptoService();
      final appInfoProvider = FakeAppInfoProvider();
      final snapshotService = SnapshotService(localDatabase: localDatabase);
      final restoreService = RestoreService(localDatabase: localDatabase);

      final creationService = BackupCreationServiceImpl(
        snapshotService: snapshotService,
        preferencesService: backupPrefsService,
        attachmentService: attachmentService,
        cryptoService: cryptoService,
        appInfoProvider: appInfoProvider,
        getDocsDirProvider: () async => tempDir,
      );

      final createBackupUseCase = CreateBackupUseCase(creationService);
      const password = 'SecurityPass123!';
      final createResult = await createBackupUseCase(
        CreateBackupParams(password: password),
      );
      expect(createResult.isRight(), isTrue);
      final backupFilePath =
          createResult.getOrElse(() => throw Exception('')).backupFilePath;

      // Destino con PIN diferente y biometría activada
      SharedPreferences.setMockInitialValues({
        'USER_NAME': 'Destino Previo',
        'SECURITY_PIN': '9999',
        'ENABLE_BIOMETRICS': true,
      });

      prefs = await SharedPreferences.getInstance();
      backupPrefsService = BackupPreferencesService(prefs);

      final backupRestoreService = BackupRestoreServiceImpl(
        restoreService: restoreService,
        preferencesService: backupPrefsService,
        attachmentService: attachmentService,
        cryptoService: cryptoService,
        appInfoProvider: appInfoProvider,
        getDocsDirProvider: () async => tempDir,
      );

      final restoreBackupUseCase = RestoreBackupUseCase(backupRestoreService);
      final restoreResult =
          await restoreBackupUseCase(backupFilePath, password);
      if (restoreResult.isLeft()) {
        fail(
            'E2E-03 restore falló: ${restoreResult.fold((l) => l.message, (r) => '')}');
      }
      expect(restoreResult.isRight(), isTrue);

      // Invariante de seguridad demostrada: Destino conserva su configuración local
      expect(prefs.getString('SECURITY_PIN'), '9999');
      expect(prefs.getBool('ENABLE_BIOMETRICS'), true);
      // Whitelist sí se actualizó
      expect(prefs.getString('USER_NAME'), 'Origen Seguro');
    });

    test('E2E-04: Ciclo completo de Attachments reales con bytes verificados',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final backupPrefsService = BackupPreferencesService(prefs);

      final attachmentService = AttachmentStorageServiceImpl(
        getDocsDirProvider: () async => tempDir,
      );
      final cryptoService = BackupCryptoService();
      final appInfoProvider = FakeAppInfoProvider();
      final snapshotService = SnapshotService(localDatabase: localDatabase);
      final restoreService = RestoreService(localDatabase: localDatabase);

      final creationService = BackupCreationServiceImpl(
        snapshotService: snapshotService,
        preferencesService: backupPrefsService,
        attachmentService: attachmentService,
        cryptoService: cryptoService,
        appInfoProvider: appInfoProvider,
        getDocsDirProvider: () async => tempDir,
      );

      final backupRestoreService = BackupRestoreServiceImpl(
        restoreService: restoreService,
        preferencesService: backupPrefsService,
        attachmentService: attachmentService,
        cryptoService: cryptoService,
        appInfoProvider: appInfoProvider,
        getDocsDirProvider: () async => tempDir,
      );

      final createBackupUseCase = CreateBackupUseCase(creationService);
      final restoreBackupUseCase = RestoreBackupUseCase(backupRestoreService);

      final accountRepo = AccountRepositoryImpl(
        localDatabase: localDatabase,
        preferencesLocalDataSource: fakePrefsDs,
      );
      final transactionLocalDataSource =
          TransactionLocalDataSourceImpl(localDatabase: localDatabase);
      final transactionRepo = TransactionRepositoryImpl(
        localDatabase: localDatabase,
        transactionLocalDataSource: transactionLocalDataSource,
      );

      final accResult = await accountRepo.createAccount(
        const AccountEntity(
          id: 0,
          name: 'Cuenta Recibos',
          isCash: true,
          initialBalance: 500.0,
          colorValue: 0xFF0000,
          iconCode: 1,
          currencySymbol: 'S/',
        ),
      );
      final accId = accResult.getOrElse(() => throw Exception(''));

      // Crear 2 archivos físicos con bytes deterministas
      final bytesA =
          Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 11, 22, 33, 44]);
      final bytesB =
          Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 55, 66, 77, 88]);

      final sourceFileA = File(p.join(tempDir.path, 'source_receipt_a.jpg'));
      final sourceFileB = File(p.join(tempDir.path, 'source_receipt_b.png'));
      await sourceFileA.writeAsBytes(bytesA);
      await sourceFileB.writeAsBytes(bytesB);

      // Guardar en attachment service para obtener rutas relativas canónicas
      final relPathA =
          await attachmentService.saveTransactionAttachment(sourceFileA.path);
      final relPathB =
          await attachmentService.saveTransactionAttachment(sourceFileB.path);

      await transactionRepo.addTransaction(
        TransactionEntity(
          accountId: accId,
          categoryId: 1,
          amount: -50.0,
          date: DateTime(2026, 10, 4),
          description: 'Recibo Supermercado',
          type: TransactionType.expense,
          imagePath: relPathA,
        ),
        updateBalance: true,
      );

      await transactionRepo.addTransaction(
        TransactionEntity(
          accountId: accId,
          categoryId: 2,
          amount: -75.0,
          date: DateTime(2026, 10, 5),
          description: 'Recibo Farmacia',
          type: TransactionType.expense,
          imagePath: relPathB,
        ),
        updateBalance: true,
      );

      // CREATE
      const password = 'AttachmentPass123!';
      final createResult = await createBackupUseCase(
        CreateBackupParams(password: password),
      );
      expect(createResult.isRight(), isTrue);
      final backupFilePath =
          createResult.getOrElse(() => throw Exception('')).backupFilePath;

      // Mutación física: Eliminar attachments del disco y de DB
      await attachmentService.deleteAttachment(relPathA);
      await attachmentService.deleteAttachment(relPathB);
      expect(await attachmentService.exists(relPathA), isFalse);
      expect(await attachmentService.exists(relPathB), isFalse);

      final db = await localDatabase.database;
      await db.delete('transactions');

      // RESTORE
      final restoreResult =
          await restoreBackupUseCase(backupFilePath, password);
      if (restoreResult.isLeft()) {
        fail(
            'E2E-04 restore falló: ${restoreResult.fold((l) => l.message, (r) => '')}');
      }
      expect(restoreResult.isRight(), isTrue);

      await localDatabase.closeAndRelease();
      await localDatabase.database;

      // Verificación: Transacciones tienen su imagePath y los archivos existen con bytes idénticos
      final restoredTxs = (await transactionRepo.getTransactions(limit: 10))
          .getOrElse(() => []);
      expect(restoredTxs.length, 2);

      final txA =
          restoredTxs.firstWhere((t) => t.description == 'Recibo Supermercado');
      final txB =
          restoredTxs.firstWhere((t) => t.description == 'Recibo Farmacia');

      expect(txA.imagePath, relPathA);
      expect(txB.imagePath, relPathB);

      final absPathA =
          await attachmentService.resolveAbsolutePath(txA.imagePath!);
      final absPathB =
          await attachmentService.resolveAbsolutePath(txB.imagePath!);

      expect(absPathA, isNotNull);
      expect(absPathB, isNotNull);

      final restoredBytesA = await File(absPathA!).readAsBytes();
      final restoredBytesB = await File(absPathB!).readAsBytes();

      expect(restoredBytesA, bytesA);
      expect(restoredBytesB, bytesB);
    });

    test(
        'E2E-05: Negativo: Contraseña incorrecta mantiene estado previo intacto',
        () async {
      SharedPreferences.setMockInitialValues(
          {'USER_NAME': 'Usuario Inmutable'});
      final prefs = await SharedPreferences.getInstance();
      final backupPrefsService = BackupPreferencesService(prefs);

      final attachmentService = AttachmentStorageServiceImpl(
        getDocsDirProvider: () async => tempDir,
      );
      final cryptoService = BackupCryptoService();
      final appInfoProvider = FakeAppInfoProvider();
      final snapshotService = SnapshotService(localDatabase: localDatabase);
      final restoreService = RestoreService(localDatabase: localDatabase);

      final creationService = BackupCreationServiceImpl(
        snapshotService: snapshotService,
        preferencesService: backupPrefsService,
        attachmentService: attachmentService,
        cryptoService: cryptoService,
        appInfoProvider: appInfoProvider,
        getDocsDirProvider: () async => tempDir,
      );

      final backupRestoreService = BackupRestoreServiceImpl(
        restoreService: restoreService,
        preferencesService: backupPrefsService,
        attachmentService: attachmentService,
        cryptoService: cryptoService,
        appInfoProvider: appInfoProvider,
        getDocsDirProvider: () async => tempDir,
      );

      final createBackupUseCase = CreateBackupUseCase(creationService);
      final restoreBackupUseCase = RestoreBackupUseCase(backupRestoreService);

      final accountRepo = AccountRepositoryImpl(
        localDatabase: localDatabase,
        preferencesLocalDataSource: fakePrefsDs,
      );
      final accResult = await accountRepo.createAccount(
        const AccountEntity(
          id: 0,
          name: 'Cuenta Previa',
          isCash: true,
          initialBalance: 777.0,
          colorValue: 0,
          iconCode: 1,
          currencySymbol: 'S/',
        ),
      );
      final accId = accResult.getOrElse(() => throw Exception(''));

      const correctPassword = 'CorrectPass123!';
      final createResult = await createBackupUseCase(
        CreateBackupParams(password: correctPassword),
      );
      expect(createResult.isRight(), isTrue);
      final backupFilePath =
          createResult.getOrElse(() => throw Exception('')).backupFilePath;

      // Intentar restaurar con contraseña incorrecta
      const wrongPassword = 'WrongPass999!';
      final restoreResult =
          await restoreBackupUseCase(backupFilePath, wrongPassword);
      expect(restoreResult.isLeft(), isTrue);

      // Estado previo debe estar 100% intacto
      final balance = await getAccountCurrentBalance(accountRepo, accId);
      expect(balance, 777.0);
      expect(prefs.getString('USER_NAME'), 'Usuario Inmutable');
    });

    test('E2E-06: Negativo: Backup manipulado mantiene estado previo intacto',
        () async {
      SharedPreferences.setMockInitialValues({'USER_NAME': 'Usuario Original'});
      final prefs = await SharedPreferences.getInstance();
      final backupPrefsService = BackupPreferencesService(prefs);

      final attachmentService = AttachmentStorageServiceImpl(
        getDocsDirProvider: () async => tempDir,
      );
      final cryptoService = BackupCryptoService();
      final appInfoProvider = FakeAppInfoProvider();
      final snapshotService = SnapshotService(localDatabase: localDatabase);
      final restoreService = RestoreService(localDatabase: localDatabase);

      final creationService = BackupCreationServiceImpl(
        snapshotService: snapshotService,
        preferencesService: backupPrefsService,
        attachmentService: attachmentService,
        cryptoService: cryptoService,
        appInfoProvider: appInfoProvider,
        getDocsDirProvider: () async => tempDir,
      );

      final backupRestoreService = BackupRestoreServiceImpl(
        restoreService: restoreService,
        preferencesService: backupPrefsService,
        attachmentService: attachmentService,
        cryptoService: cryptoService,
        appInfoProvider: appInfoProvider,
        getDocsDirProvider: () async => tempDir,
      );

      final createBackupUseCase = CreateBackupUseCase(creationService);
      final restoreBackupUseCase = RestoreBackupUseCase(backupRestoreService);

      final accountRepo = AccountRepositoryImpl(
        localDatabase: localDatabase,
        preferencesLocalDataSource: fakePrefsDs,
      );
      final accResult = await accountRepo.createAccount(
        const AccountEntity(
          id: 0,
          name: 'Cuenta Intacta',
          isCash: true,
          initialBalance: 333.0,
          colorValue: 0,
          iconCode: 1,
          currencySymbol: 'S/',
        ),
      );
      final accId = accResult.getOrElse(() => throw Exception(''));

      const password = 'IntegrityPass123!';
      final createResult = await createBackupUseCase(
        CreateBackupParams(password: password),
      );
      expect(createResult.isRight(), isTrue);
      final backupFilePath =
          createResult.getOrElse(() => throw Exception('')).backupFilePath;

      // Manipular el archivo para romper integridad criptográfica
      final backupFile = File(backupFilePath);
      final originalBytes = await backupFile.readAsBytes();
      // Corromper bytes intermedios
      final corruptedBytes = Uint8List.fromList(originalBytes);
      for (int i = 50; i < 70 && i < corruptedBytes.length; i++) {
        corruptedBytes[i] = corruptedBytes[i] ^ 0xFF;
      }
      await backupFile.writeAsBytes(corruptedBytes);

      // Intentar restaurar con backup corrupto
      final restoreResult =
          await restoreBackupUseCase(backupFilePath, password);
      expect(restoreResult.isLeft(), isTrue);

      // Estado previo debe estar 100% intacto
      final balance = await getAccountCurrentBalance(accountRepo, accId);
      expect(balance, 333.0);
      expect(prefs.getString('USER_NAME'), 'Usuario Original');
    });
  });
}
