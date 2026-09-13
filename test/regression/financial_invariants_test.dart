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

class MockPreferencesLocalDataSource extends Mock implements PreferencesLocalDataSource {}

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

    final transactionDataSource = TransactionLocalDataSourceImpl(localDatabase: localDatabase);
    transactionRepository = TransactionRepositoryImpl(
      localDatabase: localDatabase,
      transactionLocalDataSource: transactionDataSource,
    );
  });

  group('INV-01: Edición de cuenta no altera saldo', () {
    test('Editar color e icono de cuenta conserva su saldo', () async {
      // 1. Crear cuenta
      final newAccount = AccountEntity(
        id: 0,
        name: 'Cuenta Inicial',
        isCash: true,
        initialBalance: 500.0, // Solo para la creación
        colorValue: 0xFF0000,
        iconCode: 1234,
        currencySymbol: 'S/',
      );
      final createResult = await accountRepository.createAccount(newAccount);
      final accountId = createResult.getOrElse(() => throw Exception('Failed to create account'));

      // Leer cuenta
      var accountsResult = await accountRepository.getAccounts();
      var accounts = accountsResult.getOrElse(() => []);
      var account = accounts.firstWhere((a) => a.id == accountId);

      expect(account.currentBalance, 500.0);

      // Simular cambio malicioso donde se intenta alterar el saldo editando la cuenta
      // (La lógica que vamos a corregir permitía que se sobrescribiera balance)
      final modifiedAccount = account.copyWith(
        name: 'Nombre Editado',
        colorValue: 0xFF00FF,
        currentBalance: 9999.0, // Un intento de alterar saldo
        currencySymbol: 'USD',  // Un intento de cambiar moneda
      );

      await accountRepository.updateAccount(modifiedAccount);

      // Volver a leer
      accountsResult = await accountRepository.getAccounts();
      accounts = accountsResult.getOrElse(() => []);
      final updatedAccount = accounts.firstWhere((a) => a.id == accountId);

      // Si P0-04 se implementó bien, updateAccount no debería tocar el saldo ni la moneda original
      expect(updatedAccount.name, 'Nombre Editado');
      expect(updatedAccount.colorValue, 0xFF00FF);
      
      // Estas aserciones podrían fallar AHORA antes de arreglar P0-04
      expect(updatedAccount.currentBalance, 500.0, reason: 'El saldo no debe cambiar por edición de metadatos');
      expect(updatedAccount.currencySymbol, 'S/', reason: 'La moneda no debe cambiar una vez creada');
    });
  });

  group('INV-02 y INV-04: Transacciones y atomicidad de edición', () {
    test('Eliminar movimiento revierte exactamente su efecto', () async {
      // 1. Crear cuenta
      final account = AccountEntity(id: 0, name: 'Principal', isCash: false, initialBalance: 1000.0, colorValue: 0, iconCode: 0, currencySymbol: 'S/');
      final accId = (await accountRepository.createAccount(account)).getOrElse(() => 0);

      // 2. Ingreso
      final transaction = TransactionEntity(
        id: 0,
        accountId: accId,
        categoryId: 11, // Sueldo
        amount: 200.0,
        date: DateTime.now(),
        type: TransactionType.income,
        description: 'Test',
      );
      await transactionRepository.addTransaction(transaction);

      // Validar saldo
      var accounts = (await accountRepository.getAccounts()).getOrElse(() => []);
      expect(accounts.firstWhere((a) => a.id == accId).currentBalance, 1200.0);

      // 3. Obtener transacciones para encontrar su ID
      final transactions = (await transactionRepository.getTransactions()).getOrElse(() => []);
      final insertedTx = transactions.first;

      // 4. Eliminar
      await transactionRepository.deleteTransaction(insertedTx.id!);

      // 5. Validar saldo revertido
      accounts = (await accountRepository.getAccounts()).getOrElse(() => []);
      expect(accounts.firstWhere((a) => a.id == accId).currentBalance, 1000.0);
    });

    test('Editar movimiento es lógicamente (revertir anterior + aplicar nuevo)', () async {
      final account1 = AccountEntity(id: 0, name: 'Acc1', isCash: false, initialBalance: 1000.0, colorValue: 0, iconCode: 0, currencySymbol: 'S/');
      final acc1Id = (await accountRepository.createAccount(account1)).getOrElse(() => 0);
      
      final account2 = AccountEntity(id: 0, name: 'Acc2', isCash: true, initialBalance: 500.0, colorValue: 0, iconCode: 0, currencySymbol: 'S/');
      final acc2Id = (await accountRepository.createAccount(account2)).getOrElse(() => 0);

      // Crear un gasto normal
      final expense = TransactionEntity(
        id: 0,
        accountId: acc1Id,
        categoryId: 1, 
        amount: -300.0,
        date: DateTime.now(),
        type: TransactionType.expense,
        description: 'Expense',
      );
      await transactionRepository.addTransaction(expense);

      var accounts = (await accountRepository.getAccounts()).getOrElse(() => []);
      expect(accounts.firstWhere((a) => a.id == acc1Id).currentBalance, 700.0);
      expect(accounts.firstWhere((a) => a.id == acc2Id).currentBalance, 500.0);

      final insertedExpense = (await transactionRepository.getTransactions())
          .getOrElse(() => [])
          .first;

      // Transformarlo a Transferencia hacia acc2 con monto distinto
      final updatedAsTransfer = TransactionEntity(
        id: insertedExpense.id,
        accountId: insertedExpense.accountId,
        categoryId: insertedExpense.categoryId,
        date: insertedExpense.date,
        description: insertedExpense.description,
        type: TransactionType.transfer,
        destinationAccountId: acc2Id,
        amount: 150.0, // Ahora es una transferencia de 150
      );

      await transactionRepository.updateTransaction(updatedAsTransfer);

      // Validar saldo
      // Originalmente acc1 tenía 1000.
      // 1. Revertimos el gasto de 300: acc1 => 1000.
      // 2. Aplicamos transferencia de 150: acc1 => 850.
      // 3. acc2 recibe 150: acc2 => 650.
      accounts = (await accountRepository.getAccounts()).getOrElse(() => []);
      expect(accounts.firstWhere((a) => a.id == acc1Id).currentBalance, 850.0);
      expect(accounts.firstWhere((a) => a.id == acc2Id).currentBalance, 650.0);
    });
  });
}
