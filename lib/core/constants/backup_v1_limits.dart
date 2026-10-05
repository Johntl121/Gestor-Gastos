class BackupV1Limits {
  static const int maxPlaintextZipBytes = 50 * 1024 * 1024; // 50 MiB
  static const int maxUncompressedPayloadBytes = 100 * 1024 * 1024; // 100 MiB
  static const int maxEntries = 2000;
  static const int maxSingleFileBytes = 100 * 1024 * 1024; // 100 MiB
  static const int maxEncryptedContainerBytes = 52 * 1024 * 1024; // 52 MiB
}
