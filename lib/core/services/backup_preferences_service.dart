import 'package:shared_preferences/shared_preferences.dart';

class BackupPreferencesService {
  final SharedPreferences _prefs;

  BackupPreferencesService(this._prefs);

  /// Whitelist de claves funcionales y portables permitidas para backup.
  /// Cualquier clave no listada aquí será ignorada durante la exportación
  /// e importación.
  static const Map<String, Type> _whitelist = {
    'USER_NAME': String,
    'CURRENCY': String,
    'BUDGET_LIMIT': double,
    'USER_AVATAR': String,
    'THEME_MODE': bool,
    'EXCHANGE_RATES': String, // Se guarda como JSON String
    'LAST_KNOWN_TIMEZONE': String,
  };

  /// Exporta únicamente las preferencias en la whitelist que estén presentes.
  Future<Map<String, dynamic>> exportPreferences() async {
    final Map<String, dynamic> data = {};
    for (final entry in _whitelist.entries) {
      final key = entry.key;
      if (_prefs.containsKey(key)) {
        data[key] = _prefs.get(key);
      }
    }
    return data;
  }

  /// Restaura las preferencias de forma defensiva y atómica a nivel lógico.
  /// 
  /// Política de restauración:
  /// - Key ausente en el backup: Se conserva el valor actual del dispositivo.
  /// - Key desconocida (no en whitelist): Se ignora.
  /// - Tipo incorrecto: Al ser todas las preferencias de la app opcionales 
  ///   (con fallbacks seguros en la capa de datos), si el valor del backup 
  ///   viene con tipo inválido, se ignora esa clave específica (no se importa),
  ///   preservando la integridad del proceso. No interrumpe el restore global.
  Future<void> restorePreferences(Map<String, dynamic> data) async {
    // 1. Validar el Map y construir conjunto seguro antes de modificar SharedPreferences
    final Map<String, dynamic> validatedData = {};

    for (final entry in data.entries) {
      final key = entry.key;
      var value = entry.value;

      // 1.1 Ignorar keys fuera de la whitelist
      if (!_whitelist.containsKey(key)) continue;
      
      if (value == null) continue; // Ignorar nulos (conservamos valor actual)

      final expectedType = _whitelist[key];

      // 1.2 Validación y corrección de tipos
      bool isValid = false;

      if (expectedType == String && value is String) {
        isValid = true;
      } else if (expectedType == double) {
        if (value is double) {
          isValid = true;
        } else if (value is int) {
          // Fallback seguro: JSON parser a veces convierte 2400.0 a 2400 (int)
          value = value.toDouble();
          isValid = true;
        }
      } else if (expectedType == bool && value is bool) {
        isValid = true;
      }

      // 1.3 Si el tipo es válido, lo agregamos al batch
      if (isValid) {
        validatedData[key] = value;
      }
    }

    // 2. Aplicar todos los valores validados (escritura final)
    for (final entry in validatedData.entries) {
      final key = entry.key;
      final value = entry.value;

      if (value is String) {
        await _prefs.setString(key, value);
      } else if (value is double) {
        await _prefs.setDouble(key, value);
      } else if (value is bool) {
        await _prefs.setBool(key, value);
      }
    }
  }
}
