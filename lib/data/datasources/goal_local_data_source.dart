import 'package:sqflite/sqflite.dart';
import '../../core/services/database_helper.dart';
import '../models/goal_model.dart';

abstract class GoalLocalDataSource {
  Future<List<GoalModel>> getGoals();
  Future<void> saveGoal(GoalModel goal);
  Future<void> deleteGoal(String id);
}

class GoalLocalDataSourceImpl implements GoalLocalDataSource {
  final LocalDatabase localDatabase;

  GoalLocalDataSourceImpl({required this.localDatabase});

  @override
  Future<List<GoalModel>> getGoals() async {
    final db = await localDatabase.database;
    final List<Map<String, dynamic>> maps = await db.query('goals');
    return maps.map((j) => GoalModel.fromJson(j)).toList();
  }

  @override
  Future<void> saveGoal(GoalModel goal) async {
    final db = await localDatabase.database;
    await db.insert('goals', goal.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> deleteGoal(String id) async {
    final db = await localDatabase.database;
    await db.delete('goals', where: 'id = ?', whereArgs: [id]);
  }
}
