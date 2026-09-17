import 'package:dartz/dartz.dart';
import '../../core/errors/failure.dart';
import '../entities/reminder.dart';

abstract class ReminderRepository {
  Future<Either<Failure, void>> createReminder(Reminder reminder);
  Future<Either<Failure, Reminder?>> getReminderById(String id);
  Future<Either<Failure, List<Reminder>>> getAllReminders();
  Future<Either<Failure, void>> updateReminder(Reminder reminder);
  Future<Either<Failure, void>> deleteReminder(String id);
}
