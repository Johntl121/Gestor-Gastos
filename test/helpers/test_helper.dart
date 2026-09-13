import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:gestor_gastos/core/services/database_helper.dart';

Future<void> setupTestDatabase() async {
  // Initialize FFI
  sqfliteFfiInit();
  // Change the default factory
  databaseFactory = databaseFactoryFfi;

  // Clear tables before starting tests to ensure a clean state
  await LocalDatabase().clearAllTables();
}
