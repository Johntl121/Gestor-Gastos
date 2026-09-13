import 'package:sqflite/sqflite.dart';
import '../../core/services/database_helper.dart';
import '../models/subscription.dart';

abstract class SubscriptionLocalDataSource {
  Future<List<Subscription>> getSubscriptions();
  Future<void> saveSubscription(Subscription subscription);
  Future<void> deleteSubscription(String id);
}

class SubscriptionLocalDataSourceImpl implements SubscriptionLocalDataSource {
  final LocalDatabase localDatabase;

  SubscriptionLocalDataSourceImpl({required this.localDatabase});

  @override
  Future<List<Subscription>> getSubscriptions() async {
    final db = await localDatabase.database;
    final List<Map<String, dynamic>> maps =
        await db.query('fixed_expenses', orderBy: 'orderIndex ASC');
    return maps.map((j) => Subscription.fromJson(j)).toList();
  }

  @override
  Future<void> saveSubscription(Subscription subscription) async {
    final db = await localDatabase.database;
    await db.insert('fixed_expenses', subscription.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> deleteSubscription(String id) async {
    final db = await localDatabase.database;
    await db.delete('fixed_expenses', where: 'id = ?', whereArgs: [id]);
  }
}
