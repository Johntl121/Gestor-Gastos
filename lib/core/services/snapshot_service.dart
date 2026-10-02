import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'database_helper.dart';
import '../errors/backup_exceptions.dart';

class SnapshotService {
  final LocalDatabase _localDatabase;

  SnapshotService({LocalDatabase? localDatabase}) 
      : _localDatabase = localDatabase ?? LocalDatabase();

  /// Crea una copia consistente de la base de datos de producción
  /// bloqueando accesos concurrentes mientras se hace la copia física.
  Future<File> createDatabaseSnapshot(String destinationPath) async {
    final String activeDbPath = join(await getDatabasesPath(), 'gestor_gastos.db');

    try {
      return await _localDatabase.executeMaintenance(() async {
        // 1. Cierra y libera la base de datos activa para volcar buffers a disco
        await _localDatabase.closeAndRelease();

        final activeFile = File(activeDbPath);
        if (!await activeFile.exists()) {
          throw BackupFormatException('La base de datos principal no existe.');
        }

        // 2. Copia el archivo físico de SQLite de forma segura (journal_mode = delete)
        final snapshotFile = await activeFile.copy(destinationPath);

        // 3. Valida la integridad del archivo copiado independientemente
        await _validateSnapshot(destinationPath);

        return snapshotFile;
      });
    } finally {
      // 4. Reapertura garantizada: Incluso si falló la copia o la validación,
      // la base de datos productiva vuelve a levantarse después de liberar el mutex.
      // Aquí el mutex ya está liberado por lo que getter 'database' no causará deadlock.
      await _localDatabase.database; 
    }
  }

  Future<void> _validateSnapshot(String path) async {
    Database? snapshotDb;
    try {
      // Usamos singleInstance: false para no interferir con la conexión principal de sqflite
      snapshotDb = await openDatabase(
        path,
        singleInstance: false,
      );

      final quickCheck = await snapshotDb.rawQuery('PRAGMA quick_check;');
      if (quickCheck.isEmpty || quickCheck.first['quick_check'] != 'ok') {
        throw BackupFormatException('La copia de seguridad está corrupta (quick_check falló).');
      }

      final versionResult = await snapshotDb.rawQuery('PRAGMA user_version;');
      if (versionResult.isEmpty) {
         throw BackupFormatException('No se pudo leer la versión de la base de datos.');
      }
      
      final userVersion = versionResult.first.values.first as int?;
      if (userVersion == null || userVersion <= 0) {
        throw BackupFormatException('Versión de esquema inválida en la snapshot.');
      }
    } finally {
      await snapshotDb?.close();
    }
  }
}
