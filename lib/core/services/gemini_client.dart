import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiClient {
  // Usamos la versión estable v1, NO la v1beta
  // Modelos 2026: Usamos gemini-2.5-flash por estabilidad.
  // Alternativa (si falla): gemini-3-flash-preview
  static const String _urlOficial =
      "https://generativelanguage.googleapis.com/v1/models/gemini-2.5-flash-lite:generateContent";

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
Eres un Coach Financiero. Es la primera vez que el usuario abre la app.
Dale una bienvenida cálida, breve (máximo 2 frases) y anímalo a registrar su primer gasto para empezar a trabajar juntos.
No des cifras, solo motivación y cercanía.
""";
    } else if (periodType == 'weekly') {
      instruction = """
Actúa como un Coach Financiero en modo 'Flash'.
Sé extremadamente breve. Máximo 60 palabras.
Dame 3 puntos bala rápidos sobre correcciones inmediatas o felicitaciones cortas.
Estilo directo y accionable.
""";
    } else {
      instruction = """
Actúa como un Coach Financiero experto. Realiza un 'Balance Mensual de Metas'.
1. Analiza el ahorro acumulado vs la meta.
2. Compara ingresos totales vs gastos totales.
3. Felicita por los logros y ajusta las metas del próximo mes.
Usa el formato detallado con Markdown, negritas y análisis profundo.
""";
    }

    final fullPrompt = """
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
