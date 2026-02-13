import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiBridge {
  // Usamos un endpoint base. Nota: Si la key viene en el query, no la pongas aquí.
  static const String _baseUrl =
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent";

  Future<String> askGemini(String prompt) async {
    // Recuperar clave. Fallback hardcoded para pruebas.
    final apiKey = dotenv.env['GEMINI_API_KEY'] ??
        'AIzaSyAn6iyDavno_Pq9OHQkYljPXuxa4KoXedI';

    // Construir URL con la key
    final url = Uri.parse("$_baseUrl?key=$apiKey");

    try {
      print("🚀 GeminiBridge: Enviando prompt...");
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {"text": prompt}
              ]
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        try {
          return data['candidates'][0]['content']['parts'][0]['text'];
        } catch (e) {
          return "Error parseando respuesta: $e \n JSON: ${response.body}";
        }
      } else {
        return "Error de Google (${response.statusCode}): ${response.body}";
      }
    } catch (e) {
      return "Error de conexión: $e";
    }
  }
}
