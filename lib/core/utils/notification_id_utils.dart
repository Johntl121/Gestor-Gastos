import 'dart:convert';

class NotificationIdUtils {
  /// Generates a deterministic 32-bit positive integer hash using FNV-1a.
  /// Always prefix with the namespace, e.g., 'subscription', '123'.
  static int generateId(String namespace, String entityId) {
    final source = '$namespace:$entityId';
    int hash = 0x811c9dc5; // FNV_offset_basis for 32-bit
    final bytes = utf8.encode(source);

    for (int i = 0; i < bytes.length; i++) {
      hash ^= bytes[i];
      hash = (hash * 0x01000193) & 0xFFFFFFFF; // FNV_prime
    }

    // Retain only positive 31 bits to ensure compatibility across all platforms
    // where max 32-bit signed int is 2147483647
    return hash & 0x7FFFFFFF;
  }
}
