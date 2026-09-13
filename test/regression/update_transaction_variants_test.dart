import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_gastos/core/services/database_helper.dart';
import 'package:gestor_gastos/data/datasources/preferences_local_data_source.dart';
import 'package:gestor_gastos/data/datasources/transaction_local_data_source.dart';
import 'package:gestor_gastos/data/repositories/account_repository_impl.dart';
import 'package:gestor_gastos/data/repositories/transaction_repository_impl.dart';
import 'package:gestor_gastos/domain/entities/account_entity.dart';
import 'package:gestor_gastos/domain/entities/transaction_entity.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/test_helper.dart';

class MockPreferencesLocalDataSource extends Mock
    implements PreferencesLocalDataSource {}

void main() {
  late LocalDatabase localDatabase;
  late AccountRepositoryImpl accountRepository;
  late TransactionRepositoryImpl transactionRepository;
  late MockPreferencesLocalDataSource mockPreferences;

  setUpAll(() async {
    await setupTestDatabase();
  });

  setUp(() async {
    localDatabase = LocalDatabase();
    await localDatabase.clearAllTables();

    mockPreferences = MockPreferencesLocalDataSource();
    accountRepository = AccountRepositoryImpl(
      localDatabase: localDatabase,
      preferencesLocalDataSource: mockPreferences,
    );

    final transactionDataSource =
        TransactionLocalDataSourceImpl(localDatabase: localDatabase);
    transactionRepository = TransactionRepositoryImpl(
      localDatabase: localDatabase,
      transactionLocalDataSource: transactionDataSource,
    );
  });

  group('UpdateTransaction Variants', () {
    test('Editar movimiento: Ingreso -> Egreso', () async {
      final acc = AccountEntity(
          id: 0,
          name: 'Acc',
          isCash: false,
          initialBalance: 1000.0,
          colorValue: 0,
          iconCode: 0,
          currencySymbol: 'S/');
      final accId =
          (await accountRepository.createAccount(acc)).getOrElse(() => 0);

      // Ingreso de 200 => 1200
      final tx = TransactionEntity(
          accountId: accId,
          categoryId: 1,
          amount: 200.0,
          date: DateTime.now(),
          description: 'Inc',
          type: TransactionType.income);
      await transactionRepository.addTransaction(tx);

      var txId = (await transactionRepository.getTransactions())
          .getOrElse(() => [])
          .first
          .id!;

      // Editar a Egreso de 100 => 1000 - 100 = 900
      final updatedTx = TransactionEntity(
          id: txId,
          accountId: accId,
          categoryId: 1,
          amount: -100.0,
          date: DateTime.now(),
          description: 'Exp',
          type: TransactionType.expense);
      await transactionRepository.updateTransaction(updatedTx);

      final accounts =
          (await accountRepository.getAccounts()).getOrElse(() => []);
      expect(accounts.firstWhere((a) => a.id == accId).currentBalance, 900.0);
    });

    test('Editar movimiento: Egreso -> Ingreso', () async {
      final acc = AccountEntity(
          id: 0,
          name: 'Acc',
          isCash: false,
          initialBalance: 1000.0,
          colorValue: 0,
          iconCode: 0,
          currencySymbol: 'S/');
      final accId =
          (await accountRepository.createAccount(acc)).getOrElse(() => 0);

      // Egreso de 300 => 700
      final tx = TransactionEntity(
          accountId: accId,
          categoryId: 1,
          amount: -300.0,
          date: DateTime.now(),
          description: 'Exp',
          type: TransactionType.expense);
      await transactionRepository.addTransaction(tx);

      var txId = (await transactionRepository.getTransactions())
          .getOrElse(() => [])
          .first
          .id!;

      // Editar a Ingreso de 200 => 1000 + 200 = 1200
      final updatedTx = TransactionEntity(
          id: txId,
          accountId: accId,
          categoryId: 1,
          amount: 200.0,
          date: DateTime.now(),
          description: 'Inc',
          type: TransactionType.income);
      await transactionRepository.updateTransaction(updatedTx);

      final accounts =
          (await accountRepository.getAccounts()).getOrElse(() => []);
      expect(accounts.firstWhere((a) => a.id == accId).currentBalance, 1200.0);
    });

    test('Editar movimiento: Cambio de cuenta en ingreso/egreso', () async {
      final acc1 = AccountEntity(
          id: 0,
          name: 'Acc1',
          isCash: false,
          initialBalance: 1000.0,
          colorValue: 0,
          iconCode: 0,
          currencySymbol: 'S/');
      final acc1Id =
          (await accountRepository.createAccount(acc1)).getOrElse(() => 0);
      final acc2 = AccountEntity(
          id: 0,
          name: 'Acc2',
          isCash: false,
          initialBalance: 500.0,
          colorValue: 0,
          iconCode: 0,
          currencySymbol: 'S/');
      final acc2Id =
          (await accountRepository.createAccount(acc2)).getOrElse(() => 0);

      // Egreso en acc1 de 200 => acc1: 800, acc2: 500
      final tx = TransactionEntity(
          accountId: acc1Id,
          categoryId: 1,
          amount: -200.0,
          date: DateTime.now(),
          description: 'Exp',
          type: TransactionType.expense);
      await transactionRepository.addTransaction(tx);

      var txId = (await transactionRepository.getTransactions())
          .getOrElse(() => [])
          .first
          .id!;

      // Cambiar a acc2 (sigue siendo egreso de 200) => acc1: 1000, acc2: 300
      final updatedTx = TransactionEntity(
          id: txId,
          accountId: acc2Id,
          categoryId: 1,
          amount: -200.0,
          date: DateTime.now(),
          description: 'Exp',
          type: TransactionType.expense);
      await transactionRepository.updateTransaction(updatedTx);

      final accounts =
          (await accountRepository.getAccounts()).getOrElse(() => []);
      expect(accounts.firstWhere((a) => a.id == acc1Id).currentBalance, 1000.0);
      expect(accounts.firstWhere((a) => a.id == acc2Id).currentBalance, 300.0);
    });

    test('Editar movimiento: Transferencia cambiando origen', () async {
      final acc1 = AccountEntity(
          id: 0,
          name: 'Acc1',
          isCash: false,
          initialBalance: 1000.0,
          colorValue: 0,
          iconCode: 0,
          currencySymbol: 'S/');
      final acc1Id =
          (await accountRepository.createAccount(acc1)).getOrElse(() => 0);
      final acc2 = AccountEntity(
          id: 0,
          name: 'Acc2',
          isCash: false,
          initialBalance: 500.0,
          colorValue: 0,
          iconCode: 0,
          currencySymbol: 'S/');
      final acc2Id =
          (await accountRepository.createAccount(acc2)).getOrElse(() => 0);
      final acc3 = AccountEntity(
          id: 0,
          name: 'Acc3',
          isCash: false,
          initialBalance: 200.0,
          colorValue: 0,
          iconCode: 0,
          currencySymbol: 'S/');
      final acc3Id =
          (await accountRepository.createAccount(acc3)).getOrElse(() => 0);

      // Transferencia acc1 -> acc2 (100) => acc1: 900, acc2: 600, acc3: 200
      final tx = TransactionEntity(
          accountId: acc1Id,
          destinationAccountId: acc2Id,
          categoryId: 1,
          amount: 100.0,
          date: DateTime.now(),
          description: 'Trf',
          type: TransactionType.transfer);
      await transactionRepository.addTransaction(tx);

      var txId = (await transactionRepository.getTransactions())
          .getOrElse(() => [])
          .first
          .id!;

      // Cambiar origen a acc3 -> acc2 (100) => acc1: 1000, acc2: 600, acc3: 100
      final updatedTx = TransactionEntity(
          id: txId,
          accountId: acc3Id,
          destinationAccountId: acc2Id,
          categoryId: 1,
          amount: 100.0,
          date: DateTime.now(),
          description: 'Trf',
          type: TransactionType.transfer);
      await transactionRepository.updateTransaction(updatedTx);

      final accounts =
          (await accountRepository.getAccounts()).getOrElse(() => []);
      expect(accounts.firstWhere((a) => a.id == acc1Id).currentBalance, 1000.0);
      expect(accounts.firstWhere((a) => a.id == acc2Id).currentBalance, 600.0);
      expect(accounts.firstWhere((a) => a.id == acc3Id).currentBalance, 100.0);
    });

    test('Editar movimiento: Transferencia cambiando destino', () async {
      final acc1 = AccountEntity(
          id: 0,
          name: 'Acc1',
          isCash: false,
          initialBalance: 1000.0,
          colorValue: 0,
          iconCode: 0,
          currencySymbol: 'S/');
      final acc1Id =
          (await accountRepository.createAccount(acc1)).getOrElse(() => 0);
      final acc2 = AccountEntity(
          id: 0,
          name: 'Acc2',
          isCash: false,
          initialBalance: 500.0,
          colorValue: 0,
          iconCode: 0,
          currencySymbol: 'S/');
      final acc2Id =
          (await accountRepository.createAccount(acc2)).getOrElse(() => 0);
      final acc3 = AccountEntity(
          id: 0,
          name: 'Acc3',
          isCash: false,
          initialBalance: 200.0,
          colorValue: 0,
          iconCode: 0,
          currencySymbol: 'S/');
      final acc3Id =
          (await accountRepository.createAccount(acc3)).getOrElse(() => 0);

      // Transferencia acc1 -> acc2 (100) => acc1: 900, acc2: 600, acc3: 200
      final tx = TransactionEntity(
          accountId: acc1Id,
          destinationAccountId: acc2Id,
          categoryId: 1,
          amount: 100.0,
          date: DateTime.now(),
          description: 'Trf',
          type: TransactionType.transfer);
      await transactionRepository.addTransaction(tx);

      var txId = (await transactionRepository.getTransactions())
          .getOrElse(() => [])
          .first
          .id!;

      // Cambiar destino a acc1 -> acc3 (100) => acc1: 900, acc2: 500, acc3: 300
      final updatedTx = TransactionEntity(
          id: txId,
          accountId: acc1Id,
          destinationAccountId: acc3Id,
          categoryId: 1,
          amount: 100.0,
          date: DateTime.now(),
          description: 'Trf',
          type: TransactionType.transfer);
      await transactionRepository.updateTransaction(updatedTx);

      final accounts =
          (await accountRepository.getAccounts()).getOrElse(() => []);
      expect(accounts.firstWhere((a) => a.id == acc1Id).currentBalance, 900.0);
      expect(accounts.firstWhere((a) => a.id == acc2Id).currentBalance, 500.0);
      expect(accounts.firstWhere((a) => a.id == acc3Id).currentBalance, 300.0);
    });

    test('Editar movimiento: Transferencia cambiando monto', () async {
      final acc1 = AccountEntity(
          id: 0,
          name: 'Acc1',
          isCash: false,
          initialBalance: 1000.0,
          colorValue: 0,
          iconCode: 0,
          currencySymbol: 'S/');
      final acc1Id =
          (await accountRepository.createAccount(acc1)).getOrElse(() => 0);
      final acc2 = AccountEntity(
          id: 0,
          name: 'Acc2',
          isCash: false,
          initialBalance: 500.0,
          colorValue: 0,
          iconCode: 0,
          currencySymbol: 'S/');
      final acc2Id =
          (await accountRepository.createAccount(acc2)).getOrElse(() => 0);

      // Transferencia acc1 -> acc2 (100) => acc1: 900, acc2: 600
      final tx = TransactionEntity(
          accountId: acc1Id,
          destinationAccountId: acc2Id,
          categoryId: 1,
          amount: 100.0,
          date: DateTime.now(),
          description: 'Trf',
          type: TransactionType.transfer);
      await transactionRepository.addTransaction(tx);

      var txId = (await transactionRepository.getTransactions())
          .getOrElse(() => [])
          .first
          .id!;

      // Cambiar monto a 200 => acc1: 800, acc2: 700
      final updatedTx = TransactionEntity(
          id: txId,
          accountId: acc1Id,
          destinationAccountId: acc2Id,
          categoryId: 1,
          amount: 200.0,
          date: DateTime.now(),
          description: 'Trf',
          type: TransactionType.transfer);
      await transactionRepository.updateTransaction(updatedTx);

      final accounts =
          (await accountRepository.getAccounts()).getOrElse(() => []);
      expect(accounts.firstWhere((a) => a.id == acc1Id).currentBalance, 800.0);
      expect(accounts.firstWhere((a) => a.id == acc2Id).currentBalance, 700.0);
    });

    test('Editar movimiento: Transferencia con receivedAmount', () async {
      final acc1 = AccountEntity(
          id: 0,
          name: 'Acc1',
          isCash: false,
          initialBalance: 1000.0,
          colorValue: 0,
          iconCode: 0,
          currencySymbol: 'USD');
      final acc1Id =
          (await accountRepository.createAccount(acc1)).getOrElse(() => 0);
      final acc2 = AccountEntity(
          id: 0,
          name: 'Acc2',
          isCash: false,
          initialBalance: 500.0,
          colorValue: 0,
          iconCode: 0,
          currencySymbol: 'EUR');
      final acc2Id =
          (await accountRepository.createAccount(acc2)).getOrElse(() => 0);

      // Transferencia acc1 -> acc2 (100 USD -> 90 EUR) => acc1: 900, acc2: 590
      final tx = TransactionEntity(
          accountId: acc1Id,
          destinationAccountId: acc2Id,
          categoryId: 1,
          amount: 100.0,
          receivedAmount: 90.0,
          date: DateTime.now(),
          description: 'Trf',
          type: TransactionType.transfer);
      await transactionRepository.addTransaction(tx);

      var txId = (await transactionRepository.getTransactions())
          .getOrElse(() => [])
          .first
          .id!;

      // Cambiar amount y receivedAmount: acc1 -> acc2 (200 USD -> 180 EUR) => acc1: 800, acc2: 680
      final updatedTx = TransactionEntity(
          id: txId,
          accountId: acc1Id,
          destinationAccountId: acc2Id,
          categoryId: 1,
          amount: 200.0,
          receivedAmount: 180.0,
          date: DateTime.now(),
          description: 'Trf',
          type: TransactionType.transfer);
      await transactionRepository.updateTransaction(updatedTx);

      final accounts =
          (await accountRepository.getAccounts()).getOrElse(() => []);
      expect(accounts.firstWhere((a) => a.id == acc1Id).currentBalance, 800.0);
      expect(accounts.firstWhere((a) => a.id == acc2Id).currentBalance, 680.0);
    });
  });
}
