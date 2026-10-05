class BackupRestoreResult {
  final int attachmentsRestored;
  final int attachmentsMissing;
  final int attachmentsConflicted;
  final bool preferencesRestored;
  final List<String> warnings;

  BackupRestoreResult({
    required this.attachmentsRestored,
    required this.attachmentsMissing,
    required this.attachmentsConflicted,
    required this.preferencesRestored,
    required this.warnings,
  });
}
