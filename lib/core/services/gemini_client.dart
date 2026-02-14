import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiClient {
  // Model: Gemini 2.5 Flash Lite (v1beta)
  // Fallback: gemini-1.5-flash
  static const String _urlOficial =
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent";

  Future<String> obtenerConsejo({
    required String contextData,
    required String periodType,
    bool isNewUser = false,
  }) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ??
        'AIzaSyAn6iyDavno_Pq9OHQkYljPXuxa4KoXedI';

    String instruction;
    if (isNewUser) {
      instruction = """
Es la primera vez que el usuario abre la app.
Dale una bienvenida cálida, breve (máximo 2 frases) y anímalo a registrar su primer gasto.
No des cifras, solo motivación.
""";
    } else if (periodType == 'weekly') {
      instruction = """
TU MISIÓN: Dar un consejo 'FLASH' ULTRA-RÁPIDO.
REGLAS:
- Máximo 60 palabras en TOTAL.
- Solo 3 puntos clave (bullets).
- Directo al grano: Felicita o corrige sin rodeos.
NO uses saludos largos ni introducciones.
""";
    } else {
      instruction = """
TU MISIÓN: Generar un 'REPORTE MENSUAL DETALLADO'.
REGLAS:
- Analiza a fondo: Ahorro vs Meta, Ingresos vs Gastos.
- Usa Markdown rico: Negritas para cifras (**\$100**), emojis 📊 y listas.
- Estructura clara: 1. Resumen Global, 2. Análisis por Categoría, 3. Próximos pasos.
- Extiéndete lo necesario para dar valor real.
""";
    }

    final fullPrompt = """
Eres un Coach Financiero experto.

$instruction

${isNewUser ? "" : "Tus respuestas deben ser visualmente atractivas usando formato Markdown:"}
${isNewUser ? "" : "1. Resalta cantidades de dinero en negritas (ej: **\$50.00**)."}
${isNewUser ? "" : "2. Usa emojis al inicio de cada sección importante 🚀."}
${isNewUser ? "" : "3. Estructura la respuesta de forma clara."}

Datos para analizar (Moneda local):
$contextData
""";

    // Construir URI con key
    final uri = Uri.parse("$_urlOficial?key=$apiKey");

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {"text": fullPrompt}
              ]
            }
          ],
          "generationConfig": {
            "temperature": 0.7,
            "topP": 0.8,
            "topK": 40,
            "maxOutputTokens": 1000
          }
        }),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        try {
          String text = json['candidates'][0]['content']['parts'][0]['text'];
          return text;
        } catch (e) {
          return "Error leyendo respuesta de AI: $e";
        }
      } else {
        return "Error del servidor: ${response.statusCode}\n${response.body}";
      }
    } catch (e) {
      return "Fallo de conexión: $e";
    }
  }
}
