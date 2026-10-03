import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'database_helper.dart';
import '../errors/backup_exceptions.dart';

class RestoreService {
  final LocalDatabase _localDatabase;

  RestoreService({LocalDatabase? localDatabase}) 
      : _localDatabase = localDatabase ?? LocalDatabase();

  Future<void> restoreDatabase(String candidatePath) async {
    final candidateFile = File(candidatePath);
    if (!await candidateFile.exists()) {
      throw RestoreFailedException('El archivo candidato no existe.');
    }

    final String activeDbPath = join(await getDatabasesPath(), 'gestor_gastos.db');
    final restoreFile = File('$activeDbPath.restore');
    final fallbackFile = File('$activeDbPath.fallback');
    final markerFile = File(join(await getDatabasesPath(), 'gestor_gastos.restore.pending'));

    // 1. Validar candidate original
    await _validateCandidate(candidatePath);

    // 2. Copiar candidate a .restore
    if (await restoreFile.exists()) await restoreFile.delete();
    await candidateFile.copy(restoreFile.path);

    // 3. Validar .restore
    await _validateCandidate(restoreFile.path);

    // 4. Crear marker de restore pending
    await markerFile.writeAsString('pending');

    bool fallbackCreated = false;

    try {
      await _localDatabase.executeMaintenance(() async {
        // 6. closeAndRelease
        await _localDatabase.closeAndRelease();

        // 7. Limpiar auxiliares de producción antiguos
        await _cleanAuxiliaryFiles(activeDbPath);

        final activeFile = File(activeDbPath);
        
        // 8. production -> fallback
        if (await activeFile.exists()) {
          await activeFile.rename(fallbackFile.path);
          fallbackCreated = true;
        }

        try {
          // 9. .restore -> production
          await restoreFile.rename(activeFile.path);
          await _cleanAuxiliaryFiles(activeDbPath); // Asegurar path limpio
          
          // 10 y 11. Reopen + migrations
          // Forzamos apertura usando el método nuevo interno
          final newDb = await _localDatabase.forceOpen();
          
          // 12, 13, 14. Health checks
          final checkRes = await newDb.rawQuery('PRAGMA quick_check;');
          if (checkRes.isEmpty || checkRes.first.values.first.toString().toLowerCase() != 'ok') {
            throw Exception('PRAGMA quick_check falló post-swap');
          }

          final vRes = await newDb.rawQuery('PRAGMA user_version;');
          final version = int.tryParse(vRes.first.values.first.toString()) ?? 0;
          if (version != 24) { // Actual _databaseVersion
            throw Exception('La versión post-migración ($version) no coincide con la esperada (24)');
          }

          // Identity check - accounts
          await newDb.rawQuery('SELECT COUNT(id) FROM accounts');

        } catch (e) {
          // Fallo durante el swap, apertura, migración o comprobación
          // Rollback interno de la sesión de mantenimiento
          await _localDatabase.closeAndRelease();
          if (await activeFile.exists()) await activeFile.delete();
          await _cleanAuxiliaryFiles(activeDbPath);
          
          if (fallbackCreated && await fallbackFile.exists()) {
            await fallbackFile.rename(activeFile.path);
          }
          
          throw RestoreFailedException('Error durante swap o comprobación post-restore: $e');
        }
      });
      
      // Si salimos de executeMaintenance sin throw, fue exitoso.
      // 15. COMMIT -> borrar fallback
      if (await fallbackFile.exists()) await fallbackFile.delete();
      
      // 16. Borrar marker
      if (await markerFile.exists()) await markerFile.delete();
      
    } catch (e) {
      if (e is RestoreFailedException) rethrow;
      
      // Si se lanzó algo no capturado dentro o el mismo maintenance falló
      // Verificamos si podemos asegurar el rollback final
      try {
        if (fallbackCreated && !await File(activeDbPath).exists() && await fallbackFile.exists()) {
          await fallbackFile.rename(activeDbPath);
        }
      } catch (rollbackErr) {
        throw RollbackFailedException('Fallo al intentar re-aplicar fallback: $rollbackErr');
      }
      
      throw RestoreFailedException('Fallo inesperado durante el mantenimiento: $e');
    }
  }

  Future<void> _validateCandidate(String path) async {
    Database? db;
    try {
      db = await openDatabase(path, singleInstance: false, readOnly: true);
      
      // quick_check
      final checkRes = await db.rawQuery('PRAGMA quick_check;');
      if (checkRes.isEmpty || checkRes.first.values.first.toString().toLowerCase() != 'ok') {
        throw InvalidDatabaseException('PRAGMA quick_check falló.');
      }

      // schema compatibility
      final vRes = await db.rawQuery('PRAGMA user_version;');
      final candidateVersion = int.tryParse(vRes.first.values.first.toString()) ?? 0;
      
      if (candidateVersion > 24) { // _databaseVersion en LocalDatabase
        throw IncompatibleSchemaException();
      }

      // identity
      final tablesQuery = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table';");
      final tables = tablesQuery.map((row) => row['name'] as String).toList();
      
      if (!tables.contains('accounts') || 
          !tables.contains('categories') || 
          !tables.contains('transactions')) {
        throw InvalidDatabaseException('Tablas principales ausentes. No es un respaldo válido de Gestor de Gastos.');
      }

    } catch (e) {
      if (e is BackupException) rethrow;
      throw InvalidDatabaseException('Error al validar base de datos: $e');
    } finally {
      if (db != null) await db.close();
    }
  }

  Future<void> _cleanAuxiliaryFiles(String basePath) async {
    final journal = File('$basePath-journal');
    final wal = File('$basePath-wal');
    final shm = File('$basePath-shm');
    if (await journal.exists()) await journal.delete();
    if (await wal.exists()) await wal.delete();
    if (await shm.exists()) await shm.delete();
  }
}
