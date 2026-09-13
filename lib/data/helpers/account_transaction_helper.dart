import 'package:sqflite/sqflite.dart';
import '../../domain/entities/transaction_entity.dart';

class AccountTransactionHelper {
  /// Aplica el efecto de una transacción (suma/resta) a las cuentas correspondientes.
  static Future<void> applyTransaction(
      Transaction txn, TransactionEntity tx) async {
    if (tx.type == TransactionType.transfer &&
        tx.destinationAccountId != null) {
      // Restar de Origen
      final originUpdated = await txn.rawUpdate(
        'UPDATE accounts SET balance = balance - ? WHERE id = ?',
        [tx.amount.abs(), tx.accountId],
      );
      if (originUpdated == 0) {
        throw Exception("Cuenta origen no encontrada o no actualizada");
      }

      // Sumar a Destino
      final destUpdated = await txn.rawUpdate(
        'UPDATE accounts SET balance = balance + ? WHERE id = ?',
        [tx.receivedAmount ?? tx.amount.abs(), tx.destinationAccountId],
      );
      if (destUpdated == 0) {
        throw Exception("Cuenta destino no encontrada o no actualizada");
      }
    } else {
      // Gasto (negativo) o Ingreso (positivo) -> sumar algebraicamente
      final updated = await txn.rawUpdate(
        'UPDATE accounts SET balance = balance + ? WHERE id = ?',
        [tx.amount, tx.accountId],
      );
      if (updated == 0) {
        throw Exception("Cuenta no encontrada o no actualizada");
      }
    }
  }

  /// Revierte el efecto de una transacción (resta lo sumado, suma lo restado) de las cuentas correspondientes.
  static Future<void> revertTransaction(
      Transaction txn, TransactionEntity tx) async {
    if (tx.type == TransactionType.transfer &&
        tx.destinationAccountId != null) {
      // Revertir: Sumar a Origen
      final originUpdated = await txn.rawUpdate(
        'UPDATE accounts SET balance = balance + ? WHERE id = ?',
        [tx.amount.abs(), tx.accountId],
      );
      if (originUpdated == 0) {
        throw Exception("Cuenta origen no encontrada o no actualizada");
      }

      // Revertir: Restar de Destino
      final destUpdated = await txn.rawUpdate(
        'UPDATE accounts SET balance = balance - ? WHERE id = ?',
        [tx.receivedAmount ?? tx.amount.abs(), tx.destinationAccountId],
      );
      if (destUpdated == 0) {
        throw Exception("Cuenta destino no encontrada o no actualizada");
      }
    } else {
      // Revertir: restar algebraicamente
      final updated = await txn.rawUpdate(
        'UPDATE accounts SET balance = balance - ? WHERE id = ?',
        [tx.amount, tx.accountId],
      );
      if (updated == 0) {
        throw Exception("Cuenta no encontrada o no actualizada");
      }
    }
  }
}
