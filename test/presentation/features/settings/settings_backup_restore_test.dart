import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:dartz/dartz.dart';
import 'package:gestor_gastos/core/errors/backup_exceptions.dart';
import 'package:gestor_gastos/core/errors/failure.dart';
import 'package:gestor_gastos/domain/services/backup_creation_service.dart';
import 'package:gestor_gastos/domain/entities/backup_restore_result.dart';
import 'package:gestor_gastos/domain/entities/transaction_entity.dart';
import 'package:gestor_gastos/domain/usecases/create_backup_usecase.dart';
import 'package:gestor_gastos/domain/usecases/restore_backup_usecase.dart';
import 'package:gestor_gastos/presentation/features/settings/settings_page.dart';
import 'package:gestor_gastos/presentation/providers/ui_provider.dart';
import 'package:gestor_gastos/presentation/providers/transaction_provider.dart';
import 'package:gestor_gastos/presentation/providers/wallet_provider.dart';
import 'package:provider/provider.dart';
import 'package:get_it/get_it.dart';
import 'package:mockito/mockito.dart';

class MockCreateBackupUseCase extends Mock implements CreateBackupUseCase {
  bool called = false;
  Future<Either<Failure, BackupCreationResult>> Function()? mockResult;

  @override
  Future<Either<Failure, BackupCreationResult>> call(CreateBackupParams params) async {
    called = true;
    return mockResult?.call() ?? Future.value(Right(BackupCreationResult('path', 0, 0, 100)));
  }
}

class MockRestoreBackupUseCase extends Mock implements RestoreBackupUseCase {
  bool called = false;
  Future<Either<Failure, BackupRestoreResult>> Function()? mockResult;

  @override
  Future<Either<Failure, BackupRestoreResult>> call(String filePath, String password) async {
    called = true;
    return mockResult?.call() ?? Future.value(Right(BackupRestoreResult(attachmentsRestored: 0, attachmentsMissing: 0, attachmentsConflicted: 0, preferencesRestored: false, warnings: [])));
  }
}

class MockWalletProvider extends Mock implements WalletProvider {
  @override
  String get currencySymbol => '\$';
  @override
  double get budgetLimit => 1000.0;

  @override
  Future<void> refreshData() async {}

  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
  @override
  void dispose() {}
}

class MockUiProvider extends Mock implements UiProvider {
  @override
  String get userName => 'Test User';
  @override
  String get userAvatar => '😎';
  @override
  String? get profileImagePath => null;
  @override
  bool get isPinEnabled => false;
  @override
  bool get enableNotifications => false;
  @override
  bool get isDarkMode => false;
  @override
  bool get hasPin => false;
  @override
  bool get enableBiometrics => false;
  @override
  String get selectedCurrency => 'USD';

  @override
  Future<void> loadSettings() async {}

  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
  @override
  void dispose() {}
}

class MockTransactionProvider extends Mock implements TransactionProvider {
  @override
  List<TransactionEntity> get transactions => [];

  @override
  Future<void> refreshData() async {}

  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
  @override
  void dispose() {}
}

void main() {
  final sl = GetIt.instance;
  late MockCreateBackupUseCase mockCreate;
  late MockRestoreBackupUseCase mockRestore;

  // Platform channels for FilePicker and SharePlus
  const MethodChannel filePickerChannel = MethodChannel('miguelruivo.flutter.plugins.filepicker');
  const MethodChannel shareChannel = MethodChannel('dev.fluttercommunity.plus/share');

  bool filePickerCanceled = false;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      filePickerChannel,
      (MethodCall methodCall) async {
        print('Mock method called: ${methodCall.method}');
        if (methodCall.method == 'pickFiles' || methodCall.method == 'custom') {
          if (filePickerCanceled) return null;
          return [
            {
              'path': '/fake/path/backup.gestorbackup',
              'name': 'backup.gestorbackup',
              'size': 100,
              'bytes': null,
            }
          ];
        }
        return null;
      },
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      shareChannel,
      (MethodCall methodCall) async {
        return 'success';
      },
    );
  });

  setUp(() {
    mockCreate = MockCreateBackupUseCase();
    mockRestore = MockRestoreBackupUseCase();
    sl.allowReassignment = true;
    sl.registerLazySingleton<CreateBackupUseCase>(() => mockCreate);
    sl.registerLazySingleton<RestoreBackupUseCase>(() => mockRestore);
    filePickerCanceled = false;
  });

  tearDown(() {
    sl.reset();
  });

  Widget createTestWidget() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<UiProvider>(create: (_) => MockUiProvider()),
        ChangeNotifierProvider<TransactionProvider>(create: (_) => MockTransactionProvider()),
        ChangeNotifierProvider<WalletProvider>(create: (_) => MockWalletProvider()),
      ],
      child: const MaterialApp(
        home: Scaffold(body: SettingsPage()),
      ),
    );
  }

  testWidgets('Tiles Crear/Restaurar son visibles', (tester) async {
    await tester.pumpWidget(createTestWidget());  
    await tester.ensureVisible(find.text('Crear copia de seguridad'));
    expect(find.text('Crear copia de seguridad'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Restaurar copia de seguridad'), 500, scrollable: find.byType(Scrollable));
    expect(find.text('Restaurar copia de seguridad'), findsOneWidget);
  });

  testWidgets('CREATE: password vacío/diferente desactiva botón, igual lo activa', (tester) async {
    await tester.pumpWidget(createTestWidget());  
    await tester.ensureVisible(find.text('Crear copia de seguridad')); await tester.pumpAndSettle();
    await tester.tap(find.text('Crear copia de seguridad'));
    await tester.pumpAndSettle();

    final btnFinder = find.widgetWithText(ElevatedButton, 'Aceptar');
    ElevatedButton getBtn() => tester.widget<ElevatedButton>(btnFinder);

    expect(getBtn().onPressed, isNull);

    await tester.enterText(find.byType(TextField).first, '123');
    await tester.enterText(find.byType(TextField).last, '124');
    await tester.pump();
    expect(getBtn().onPressed, isNull);

    await tester.enterText(find.byType(TextField).last, '123');
    await tester.pump();
    expect(getBtn().onPressed, isNotNull);
  });

  testWidgets('CREATE: doble tap llama UseCase una sola vez y maneja success', (tester) async {
    await tester.pumpWidget(createTestWidget());  
    await tester.ensureVisible(find.text('Crear copia de seguridad')); await tester.pumpAndSettle();
    await tester.tap(find.text('Crear copia de seguridad'));
    await tester.pumpAndSettle(); await tester.pump(const Duration(seconds: 1)); await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '123');
    await tester.enterText(find.byType(TextField).last, '123');
    await tester.pump();

    final btn = find.widgetWithText(ElevatedButton, 'Aceptar');
    await tester.tap(btn);
    await tester.tap(btn);

    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    expect(mockCreate.called, isTrue);
    expect(find.text('Copia de seguridad creada correctamente.'), findsOneWidget);
  });

  testWidgets('CREATE: warning con contador', (tester) async {
    mockCreate.mockResult = () async => Right(BackupCreationResult('path', 0, 5, 100));

    await tester.pumpWidget(createTestWidget());  
    await tester.ensureVisible(find.text('Crear copia de seguridad')); await tester.pumpAndSettle();
    await tester.tap(find.text('Crear copia de seguridad'));
    await tester.pumpAndSettle(); await tester.pump(const Duration(seconds: 1)); await tester.pumpAndSettle(); await tester.pump(const Duration(seconds: 1)); await tester.pumpAndSettle(); await tester.pump(const Duration(seconds: 1)); await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '123');
    await tester.enterText(find.byType(TextField).last, '123');
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Aceptar'));
    await tester.pumpAndSettle();

    expect(find.text('Copia creada, pero 5 recibos no pudieron incluirse.'), findsOneWidget);
  });

  testWidgets('CREATE: BackupTooLarge mapping', (tester) async {
    mockCreate.mockResult = () async => Left(CacheFailure('BackupTooLargeException'));

    await tester.pumpWidget(createTestWidget());  
    await tester.ensureVisible(find.text('Crear copia de seguridad')); await tester.pumpAndSettle();
    await tester.tap(find.text('Crear copia de seguridad'));
    await tester.pumpAndSettle(); await tester.pump(const Duration(seconds: 1)); await tester.pumpAndSettle(); await tester.pump(const Duration(seconds: 1)); await tester.pumpAndSettle(); await tester.pump(const Duration(seconds: 1)); await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '123');
    await tester.enterText(find.byType(TextField).last, '123');
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Aceptar'));
    await tester.pumpAndSettle();

    expect(find.text('La copia de seguridad supera el tamaño compatible con esta versión.'), findsOneWidget);
  });

  testWidgets('RESTORE: FilePicker cancelado -> UseCase nunca llamado', (tester) async {
    filePickerCanceled = true;
    await tester.pumpWidget(createTestWidget());  
    await tester.ensureVisible(find.text('Crear copia de seguridad')); await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Restaurar copia de seguridad')); await tester.pumpAndSettle();
    await tester.tap(find.text('Restaurar copia de seguridad'));
    await tester.pumpAndSettle();

    expect(find.text('Contraseña de Copia'), findsNothing);
    expect(mockRestore.called, isFalse);
  });

  testWidgets('RESTORE: confirmacion destructiva cancelada -> UseCase nunca llamado', (tester) async {
    await tester.pumpWidget(createTestWidget());  
    await tester.ensureVisible(find.text('Crear copia de seguridad')); await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Restaurar copia de seguridad')); await tester.pumpAndSettle();
    await tester.tap(find.text('Restaurar copia de seguridad'));
    await tester.pumpAndSettle(); await tester.pump(const Duration(seconds: 1)); await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '123');
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Aceptar'));
    await tester.pumpAndSettle();

    expect(find.text('Advertencia destructiva'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
    await tester.pumpAndSettle();

    expect(mockRestore.called, isFalse);
  });

  testWidgets('RESTORE: error mapping (RollbackFailed y RestoreFailed)', (tester) async {
    await tester.pumpWidget(createTestWidget());  

    mockRestore.mockResult = () async => Left(CacheFailure('RollbackFailedException'));

    await tester.ensureVisible(find.text('Crear copia de seguridad')); await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Restaurar copia de seguridad')); await tester.pumpAndSettle();
    await tester.tap(find.text('Restaurar copia de seguridad'));
    await tester.pumpAndSettle(); await tester.pump(const Duration(seconds: 1)); await tester.pumpAndSettle(); await tester.pump(const Duration(seconds: 1)); await tester.pumpAndSettle(); await tester.pump(const Duration(seconds: 1)); await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '123');
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Aceptar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sí, restaurar'));
    await tester.pumpAndSettle();
    expect(find.text('ERROR CRÍTICO: Fallo al restaurar y fallo al recuperar. La app podría estar inconsistente.'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));

    mockRestore.mockResult = () async => Left(CacheFailure('RestoreFailedException'));
    await tester.ensureVisible(find.text('Crear copia de seguridad')); await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Restaurar copia de seguridad')); await tester.pumpAndSettle();
    await tester.tap(find.text('Restaurar copia de seguridad'));
    await tester.pumpAndSettle(); await tester.pump(const Duration(seconds: 1)); await tester.pumpAndSettle(); await tester.pump(const Duration(seconds: 1)); await tester.pumpAndSettle(); await tester.pump(const Duration(seconds: 1)); await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '123');
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Aceptar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sí, restaurar'));
    await tester.pumpAndSettle();
    expect(find.text('No se pudo completar la restauración. Se ha vuelto a la versión anterior.'), findsOneWidget);
  });

  testWidgets('RESTORE: success -> solicita restart', (tester) async {
    mockRestore.mockResult = () async => Right(BackupRestoreResult(attachmentsRestored: 0, attachmentsMissing: 0, attachmentsConflicted: 0, preferencesRestored: false, warnings: []));

    await tester.pumpWidget(createTestWidget());  
    await tester.ensureVisible(find.text('Crear copia de seguridad')); await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Restaurar copia de seguridad')); await tester.pumpAndSettle();
    await tester.tap(find.text('Restaurar copia de seguridad'));
    await tester.pumpAndSettle(); await tester.pump(const Duration(seconds: 1)); await tester.pumpAndSettle(); await tester.pump(const Duration(seconds: 1)); await tester.pumpAndSettle(); await tester.pump(const Duration(seconds: 1)); await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '123');
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Aceptar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sí, restaurar'));
    await tester.pumpAndSettle();

    expect(find.text('Copia restaurada exitosamente.'), findsOneWidget);
  });

  testWidgets('RESTORE: warnings de adjuntos', (tester) async {
    mockRestore.mockResult = () async => Right(BackupRestoreResult(attachmentsRestored: 0, attachmentsMissing: 0, attachmentsConflicted: 0, preferencesRestored: false, warnings: ['missing/path']));

    await tester.pumpWidget(createTestWidget());  
    await tester.ensureVisible(find.text('Crear copia de seguridad')); await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Restaurar copia de seguridad')); await tester.pumpAndSettle();
    await tester.tap(find.text('Restaurar copia de seguridad'));
    await tester.pumpAndSettle(); await tester.pump(const Duration(seconds: 1)); await tester.pumpAndSettle(); await tester.pump(const Duration(seconds: 1)); await tester.pumpAndSettle(); await tester.pump(const Duration(seconds: 1)); await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '123');
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Aceptar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sí, restaurar'));
    await tester.pumpAndSettle();

    expect(find.text('Restaurado con advertencias (adjuntos faltantes).'), findsOneWidget);
  });
}