import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'database_helper.dart';
import '../errors/backup_exceptions.dart';

class RestoreService {
  final LocalDatabase _localDatabase;

  RestoreService({LocalDatabase? localDatabase}) 
      : _localDatabase = localDatabase ?? LocalDatabase();

  static bool _isRestoring = false;

    Future<void> restoreDatabase(String candidatePath) async {
    if (_isRestoring) {
      throw RestoreFailedException('Ya hay una restauración en progreso.');
    }
    _isRestoring = true;

    try {
      final candidateFile = File(candidatePath);
      if (!await candidateFile.exists()) {
        throw RestoreFailedException('El archivo candidato no existe.');
      }

      final String activeDbPath = join(await getDatabasesPath(), 'gestor_gastos.db');
      final restoreFile = File('$activeDbPath.restore');
      final fallbackFile = File('$activeDbPath.fallback');
      final markerFile = File(join(await getDatabasesPath(), 'gestor_gastos.restore.pending'));

      await _validateCandidate(candidatePath);

      if (await markerFile.exists()) {
        throw RestoreFailedException('Ya hay una restauración en progreso.');
      }

      if (await restoreFile.exists()) await restoreFile.delete();
      await candidateFile.copy(restoreFile.path);

      await _validateCandidate(restoreFile.path);

      await markerFile.writeAsString('pending');

      bool fallbackCreated = false;

      try {
        await _localDatabase.executeMaintenance(() async {
          await _localDatabase.closeAndRelease();
          await _cleanAuxiliaryFiles(activeDbPath);

          final activeFile = File(activeDbPath);
          
          if (await activeFile.exists()) {
            await activeFile.rename(fallbackFile.path);
            fallbackCreated = true;
          }

          try {
            await restoreFile.rename(activeFile.path);
            await _cleanAuxiliaryFiles(activeDbPath);
            
            final newDb = await _localDatabase.forceOpen();
            
            final checkRes = await newDb.rawQuery('PRAGMA quick_check;');
            if (checkRes.isEmpty || checkRes.first.values.first.toString().toLowerCase() != 'ok') {
              throw Exception('PRAGMA quick_check falló post-swap');
            }

            final vRes = await newDb.rawQuery('PRAGMA user_version;');
            final version = int.tryParse(vRes.first.values.first.toString()) ?? 0;
            if (version != 24) { 
              throw Exception('La versión post-migración ($version) no coincide con la esperada (24)');
            }

            await newDb.rawQuery('SELECT COUNT(id) FROM accounts');

          } catch (e) {
            await _localDatabase.closeAndRelease();
            if (await activeFile.exists()) await activeFile.delete();
            await _cleanAuxiliaryFiles(activeDbPath);
            
            if (fallbackCreated && await fallbackFile.exists()) {
              await fallbackFile.rename(activeFile.path);
            }
            
            throw RestoreFailedException('Error durante swap o comprobación post-restore: $e');
          }
        });
        
        if (await fallbackFile.exists()) await fallbackFile.delete();
        if (await markerFile.exists()) await markerFile.delete();
        
      } catch (e) {
        if (e is RestoreFailedException) rethrow;
        
        try {
          if (fallbackCreated && !await File(activeDbPath).exists() && await fallbackFile.exists()) {
            await fallbackFile.rename(activeDbPath);
          }
        } catch (rollbackErr) {
          throw RollbackFailedException('Fallo al intentar re-aplicar fallback: $rollbackErr');
        }
        
        throw RestoreFailedException('Fallo inesperado durante el mantenimiento: $e');
      }
    } finally {
      _isRestoring = false;
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
