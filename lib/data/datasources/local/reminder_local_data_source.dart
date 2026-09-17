import 'package:sqflite/sqflite.dart';
import '../../../core/services/database_helper.dart';

abstract class ReminderLocalDataSource {
  Future<void> createReminder(Map<String, dynamic> reminderMap);
  Future<Map<String, dynamic>?> getReminderById(String id);
  Future<List<Map<String, dynamic>>> getAllReminders();
  Future<void> updateReminder(Map<String, dynamic> reminderMap);
  Future<void> deleteReminder(String id);
}

class ReminderLocalDataSourceImpl implements ReminderLocalDataSource {
  final LocalDatabase localDatabase;

  ReminderLocalDataSourceImpl({required this.localDatabase});

  @override
  Future<void> createReminder(Map<String, dynamic> reminderMap) async {
    final db = await localDatabase.database;
    await db.insert(
      'reminders',
      reminderMap,
      conflictAlgorithm: ConflictAlgorithm
          .abort, // Para evitar sobreescribir si ya existe, throw constraint error
    );
  }

  @override
  Future<Map<String, dynamic>?> getReminderById(String id) async {
    final db = await localDatabase.database;
    final result = await db.query(
      'reminders',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }

  @override
  Future<List<Map<String, dynamic>>> getAllReminders() async {
    final db = await localDatabase.database;
    return await db.query('reminders');
  }

  @override
  Future<void> updateReminder(Map<String, dynamic> reminderMap) async {
    final db = await localDatabase.database;
    await db.update(
      'reminders',
      reminderMap,
      where: 'id = ?',
      whereArgs: [reminderMap['id']],
    );
  }

  @override
  Future<void> deleteReminder(String id) async {
    final db = await localDatabase.database;
    await db.delete(
      'reminders',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
