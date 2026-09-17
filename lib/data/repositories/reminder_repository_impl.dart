import 'package:dartz/dartz.dart';
import '../../../core/errors/failure.dart';
import '../../../core/utils/money_utils.dart';
import '../../../core/constants/app_currencies.dart';
import '../../../domain/entities/reminder.dart';
import '../../../domain/repositories/reminder_repository.dart';
import '../datasources/local/reminder_local_data_source.dart';

class ReminderRepositoryImpl implements ReminderRepository {
  final ReminderLocalDataSource localDataSource;

  ReminderRepositoryImpl({required this.localDataSource});

  @override
  Future<Either<Failure, void>> createReminder(Reminder reminder) async {
    try {
      final model = _toModel(reminder);
      await localDataSource.createReminder(model);
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure('Error al crear el recordatorio: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> updateReminder(Reminder reminder) async {
    try {
      final model = _toModel(reminder);
      await localDataSource.updateReminder(model);
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure('Error al actualizar el recordatorio: $e'));
    }
  }

  @override
  Future<Either<Failure, Reminder?>> getReminderById(String id) async {
    try {
      final data = await localDataSource.getReminderById(id);
      if (data == null) return const Right(null);
      return Right(_fromModel(data));
    } catch (e) {
      return Left(DatabaseFailure('Error al obtener el recordatorio: $e'));
    }
  }

  @override
  Future<Either<Failure, List<Reminder>>> getAllReminders() async {
    try {
      final data = await localDataSource.getAllReminders();
      final reminders = <Reminder>[];
      for (final map in data) {
        reminders.add(_fromModel(map));
      }
      return Right(reminders);
    } catch (e) {
      return Left(DatabaseFailure('Error al obtener los recordatorios: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteReminder(String id) async {
    try {
      await localDataSource.deleteReminder(id);
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure('Error al eliminar el recordatorio: $e'));
    }
  }

  Map<String, dynamic> _toModel(Reminder reminder) {
    double? amountToSave;
    if (reminder.amount != null && reminder.currencyCode != null) {
      // Validar que la moneda existe (lanzará excepción si no existe en fromCodeOrSymbol)
      final currency = AppCurrencies.fromCodeOrSymbol(reminder.currencyCode!);
      // Normalizar el monto antes de persistir
      amountToSave = MoneyUtils.normalize(reminder.amount!, currency.code);
    } else if (reminder.amount != null || reminder.currencyCode != null) {
      throw Exception(
          'amount y currencyCode deben ser ambos null o ambos no null');
    }

    // Validar invariantes adicionales antes de persistir
    if (reminder.completedAt != null) {
      if (reminder.recurrence != ReminderRecurrence.none) {
        throw Exception('Recordatorio recurrente no puede tener completedAt');
      }
      if (reminder.active) {
        throw Exception('Recordatorio completado debe estar inactivo');
      }
    }

    return {
      'id': reminder.id,
      'title': reminder.title,
      'description': reminder.description,
      'type': reminder.type.name,
      'amount': amountToSave,
      'currencyCode': reminder.currencyCode,
      'categoryId': reminder.categoryId,
      'date': reminder.date.toIso8601String(),
      'hour': reminder.hour,
      'minute': reminder.minute,
      'recurrence': reminder.recurrence.name,
      'active': reminder.active ? 1 : 0,
      'completedAt': reminder.completedAt?.toIso8601String(),
      'createdAt': reminder.createdAt.toIso8601String(),
      'updatedAt': reminder.updatedAt.toIso8601String(),
    };
  }

  Reminder _fromModel(Map<String, dynamic> map) {
    final typeStr = map['type'] as String;
    final type = ReminderType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => throw FormatException('Invalid ReminderType: $typeStr'),
    );

    final recurrenceStr = map['recurrence'] as String;
    final recurrence = ReminderRecurrence.values.firstWhere(
      (e) => e.name == recurrenceStr,
      orElse: () =>
          throw FormatException('Invalid ReminderRecurrence: $recurrenceStr'),
    );

    return Reminder(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      type: type,
      amount: map['amount'] != null ? (map['amount'] as num).toDouble() : null,
      currencyCode: map['currencyCode'] as String?,
      categoryId: map['categoryId'] as int?,
      date: DateTime.parse(map['date'] as String),
      hour: map['hour'] as int,
      minute: map['minute'] as int,
      recurrence: recurrence,
      active: (map['active'] as int) == 1,
      completedAt: map['completedAt'] != null
          ? DateTime.parse(map['completedAt'] as String)
          : null,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}
