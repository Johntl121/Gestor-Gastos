class BackupException implements Exception {
  final String message;
  BackupException(this.message);

  @override
  String toString() => message;
}

class BackupFormatException extends BackupException {
  BackupFormatException([String message = 'Formato de copia de seguridad inválido.']) : super(message);
}

class BackupVersionException extends BackupException {
  BackupVersionException([String message = 'Versión de copia de seguridad no soportada.']) : super(message);
}

class BackupAuthenticationException extends BackupException {
  BackupAuthenticationException([String message = 'No se pudo desbloquear la copia de seguridad.']) : super(message);
}

class InvalidDatabaseException extends BackupException {
  InvalidDatabaseException([String message = 'El archivo de base de datos es inválido o no pertenece a Gestor de Gastos.']) : super(message);
}

class IncompatibleSchemaException extends BackupException {
  IncompatibleSchemaException([String message = 'La copia de seguridad fue creada por una versión más nueva de la aplicación.']) : super(message);
}

class RestoreFailedException extends BackupException {
  RestoreFailedException(String message) : super('Fallo durante la restauración: $message');
}

class RollbackFailedException extends BackupException {
  RollbackFailedException(String message) : super('ERROR CRÍTICO: Fallo al restaurar y fallo al recuperar la copia de seguridad previa: $message');
}
