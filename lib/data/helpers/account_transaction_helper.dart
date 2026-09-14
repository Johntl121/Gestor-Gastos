import 'package:sqflite/sqflite.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../core/utils/money_utils.dart';

class AccountTransactionHelper {
  static Future<String> _getCurrencySymbol(
      Transaction txn, int accountId) async {
    final result = await txn.query('accounts',
        columns: ['currencySymbol'], where: 'id = ?', whereArgs: [accountId]);
    if (result.isNotEmpty) {
      return result.first['currencySymbol'] as String? ?? 'S/';
    }
    return 'S/';
  }

  /// Aplica el efecto de una transacción (suma/resta) a las cuentas correspondientes.
  static Future<void> applyTransaction(
      Transaction txn, TransactionEntity tx) async {
    final sourceCurrency = await _getCurrencySymbol(txn, tx.accountId);

    if (tx.type == TransactionType.transfer &&
        tx.destinationAccountId != null) {
      final destCurrency =
          await _getCurrencySymbol(txn, tx.destinationAccountId!);

      final originAmount =
          MoneyUtils.normalize(tx.amount.abs(), sourceCurrency);
      final destAmount = MoneyUtils.normalize(
          tx.receivedAmount ?? tx.amount.abs(), destCurrency);

      // Restar de Origen
      final originUpdated = await txn.rawUpdate(
        'UPDATE accounts SET balance = balance - ? WHERE id = ?',
        [originAmount, tx.accountId],
      );
      if (originUpdated == 0) {
        throw Exception("Cuenta origen no encontrada o no actualizada");
      }

      // Sumar a Destino
      final destUpdated = await txn.rawUpdate(
        'UPDATE accounts SET balance = balance + ? WHERE id = ?',
        [destAmount, tx.destinationAccountId],
      );
      if (destUpdated == 0) {
        throw Exception("Cuenta destino no encontrada o no actualizada");
      }
    } else {
      final amount = MoneyUtils.normalize(tx.amount, sourceCurrency);
      // Gasto (negativo) o Ingreso (positivo) -> sumar algebraicamente
      final updated = await txn.rawUpdate(
        'UPDATE accounts SET balance = balance + ? WHERE id = ?',
        [amount, tx.accountId],
      );
      if (updated == 0) {
        throw Exception("Cuenta no encontrada o no actualizada");
      }
    }
  }

  /// Revierte el efecto de una transacción (resta lo sumado, suma lo restado) de las cuentas correspondientes.
  static Future<void> revertTransaction(
      Transaction txn, TransactionEntity tx) async {
    final sourceCurrency = await _getCurrencySymbol(txn, tx.accountId);

    if (tx.type == TransactionType.transfer &&
        tx.destinationAccountId != null) {
      final destCurrency =
          await _getCurrencySymbol(txn, tx.destinationAccountId!);

      final originAmount =
          MoneyUtils.normalize(tx.amount.abs(), sourceCurrency);
      final destAmount = MoneyUtils.normalize(
          tx.receivedAmount ?? tx.amount.abs(), destCurrency);

      // Revertir: Sumar a Origen
      final originUpdated = await txn.rawUpdate(
        'UPDATE accounts SET balance = balance + ? WHERE id = ?',
        [originAmount, tx.accountId],
      );
      if (originUpdated == 0) {
        throw Exception("Cuenta origen no encontrada o no actualizada");
      }

      // Revertir: Restar de Destino
      final destUpdated = await txn.rawUpdate(
        'UPDATE accounts SET balance = balance - ? WHERE id = ?',
        [destAmount, tx.destinationAccountId],
      );
      if (destUpdated == 0) {
        throw Exception("Cuenta destino no encontrada o no actualizada");
      }
    } else {
      final amount = MoneyUtils.normalize(tx.amount, sourceCurrency);
      // Revertir: restar algebraicamente
      final updated = await txn.rawUpdate(
        'UPDATE accounts SET balance = balance - ? WHERE id = ?',
        [amount, tx.accountId],
      );
      if (updated == 0) {
        throw Exception("Cuenta no encontrada o no actualizada");
      }
    }
  }
}
