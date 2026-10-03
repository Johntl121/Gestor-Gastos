import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

abstract class AttachmentStorageService {
  /// Copia un archivo origen hacia el almacenamiento canónico 
  /// y devuelve la ruta RELATIVA generada.
  Future<String> saveTransactionAttachment(String sourceAbsolutePath);

  /// Toma la ruta almacenada en DB (relativa nueva o absoluta legacy),
  /// la valida, comprueba su existencia física y devuelve la ruta 
  /// ABSOLUTA actual. Retorna null si no existe o es inválida.
  Future<String?> resolveAbsolutePath(String storedPath);

  /// Verifica la integridad referencial.
  Future<bool> exists(String storedPath);

  /// Borra el archivo físico best-effort. No lanza error si falla o no existe.
  Future<void> deleteAttachment(String storedPath);
}

class AttachmentStorageServiceImpl implements AttachmentStorageService {
  final Future<Directory> Function() _getDocsDirProvider;
  final Uuid _uuid;

  AttachmentStorageServiceImpl({
    Future<Directory> Function()? getDocsDirProvider,
    Uuid? uuid,
  })  : _getDocsDirProvider = getDocsDirProvider ?? getApplicationDocumentsDirectory,
        _uuid = uuid ?? const Uuid();

  static const String _transactionsNamespace = 'attachments/transactions';
  static const List<String> _allowedExtensions = ['.jpg', '.jpeg', '.png', '.webp'];
  static const String _defaultExtension = '.jpg';

  Future<Directory> _getDocsDir() async {
    return await _getDocsDirProvider();
  }

  String _sanitizeExtension(String originalExt) {
    final ext = originalExt.toLowerCase();
    if (_allowedExtensions.contains(ext)) {
      return ext;
    }
    return _defaultExtension; // fallback seguro para extensiones no permitidas o vacías
  }

  bool _isSafeRelativePath(String relativePath) {
    // 1. Rechazo de puntos de navegación evidentes
    if (relativePath.contains('..')) return false;
    
    // 2. Normalización de path (resuelve secuencias espurias)
    final normalized = p.normalize(relativePath).replaceAll('\\', '/');
    
    // 3. Verificación de escape hacia arriba
    if (normalized.startsWith('..')) return false;

    // 4. Debe pertenecer estrictamente a nuestro namespace
    if (!normalized.startsWith('$_transactionsNamespace/')) return false;

    return true;
  }

  @override
  Future<String> saveTransactionAttachment(String sourceAbsolutePath) async {
    final sourceFile = File(sourceAbsolutePath);
    if (!await sourceFile.exists()) {
      throw FileSystemException("El archivo origen no existe", sourceAbsolutePath);
    }

    final ext = p.extension(sourceAbsolutePath);
    final safeExt = _sanitizeExtension(ext);
    final fileName = '${_uuid.v4()}$safeExt';
    
    // Generar ruta relativa con slashes hacia adelante para estandarizar en DB
    final relativePath = '$_transactionsNamespace/$fileName';

    final docsDir = await _getDocsDir();
    final destAbsPath = p.join(docsDir.path, relativePath);

    final destFile = File(destAbsPath);
    await destFile.parent.create(recursive: true);
    await sourceFile.copy(destAbsPath);

    return relativePath;
  }

  @override
  Future<String?> resolveAbsolutePath(String storedPath) async {
    if (storedPath.isEmpty) return null;

    if (p.isAbsolute(storedPath)) {
      // Tratamiento legacy: si es absoluto, verificar su existencia
      if (await File(storedPath).exists()) {
        return storedPath;
      }
      return null; // Missing legacy
    }

    // Si es relativo, aplicar protección path traversal
    if (!_isSafeRelativePath(storedPath)) {
      return null;
    }

    final docsDir = await _getDocsDir();
    final absPath = p.join(docsDir.path, storedPath);

    if (await File(absPath).exists()) {
      return absPath;
    }
    return null; // Missing relativo
  }

  @override
  Future<bool> exists(String storedPath) async {
    final abs = await resolveAbsolutePath(storedPath);
    return abs != null;
  }

  @override
  Future<void> deleteAttachment(String storedPath) async {
    final absPath = await resolveAbsolutePath(storedPath);
    if (absPath == null) return; // Archivo ya no existe o path era inválido

    // Security check: solo borrar si el archivo está dentro de los directorios permitidos (sandbox)
    final docsDir = await _getDocsDir();
    final normalizedAbsPath = p.normalize(absPath).replaceAll('\\', '/');
    final normalizedDocsDirPath = p.normalize(docsDir.path).replaceAll('\\', '/');

    if (!normalizedAbsPath.startsWith(normalizedDocsDirPath)) {
      return; // Bloquea borrado fuera del entorno seguro
    }

    try {
      final file = File(absPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Best-effort cleanup, silenciar excepciones de I/O
    }
  }
}
