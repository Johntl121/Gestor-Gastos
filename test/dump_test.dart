import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:gestor_gastos/presentation/features/settings/settings_page.dart';
import 'package:provider/provider.dart';
import 'package:gestor_gastos/presentation/providers/ui_provider.dart';
import 'package:gestor_gastos/presentation/providers/transaction_provider.dart';
import 'package:gestor_gastos/presentation/providers/wallet_provider.dart';
import 'package:mockito/mockito.dart';
import 'package:gestor_gastos/domain/entities/transaction_entity.dart';
import 'package:get_it/get_it.dart';
import 'package:gestor_gastos/domain/usecases/create_backup_usecase.dart';
import 'package:gestor_gastos/domain/usecases/restore_backup_usecase.dart';

class MockUiProvider extends Mock implements UiProvider {
  @override String get userName => 'Test User';
  @override String get userAvatar => '😎';
  @override String? get profileImagePath => null;
  @override bool get isPinEnabled => false;
  @override bool get enableNotifications => false;
  @override bool get isDarkMode => false;
  @override bool get hasPin => false;
  @override bool get enableBiometrics => false;
  @override String get selectedCurrency => 'USD';
  @override void addListener(VoidCallback listener) {}
  @override void removeListener(VoidCallback listener) {}
  @override void dispose() {}
}
class MockTransactionProvider extends Mock implements TransactionProvider {
  @override List<TransactionEntity> get transactions => [];
  @override void addListener(VoidCallback listener) {}
  @override void removeListener(VoidCallback listener) {}
  @override void dispose() {}
}
class MockWalletProvider extends Mock implements WalletProvider {
  @override String get currencySymbol => '\$';
  @override double get budgetLimit => 1000.0;
  @override void addListener(VoidCallback listener) {}
  @override void removeListener(VoidCallback listener) {}
  @override void dispose() {}
}
class MockCreateBackupUseCase extends Mock implements CreateBackupUseCase {}
class MockRestoreBackupUseCase extends Mock implements RestoreBackupUseCase {}

void main() {
  testWidgets('Dump tree', (tester) async {
    final sl = GetIt.instance;
    sl.allowReassignment = true;
    sl.registerLazySingleton<CreateBackupUseCase>(() => MockCreateBackupUseCase());
    sl.registerLazySingleton<RestoreBackupUseCase>(() => MockRestoreBackupUseCase());

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<UiProvider>(create: (_) => MockUiProvider()),
          ChangeNotifierProvider<TransactionProvider>(create: (_) => MockTransactionProvider()),
          ChangeNotifierProvider<WalletProvider>(create: (_) => MockWalletProvider()),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SettingsPage()),
        ),
      )
    );
    
    debugDumpApp();
  });
}