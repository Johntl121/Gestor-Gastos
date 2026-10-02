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
