import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class GeminiClient {
  final http.Client? _client;

  GeminiClient({http.Client? client}) : _client = client;

  // Model: Gemini 2.5 Flash Lite
  // Fallback: gemini-1.5-flash
  static const String _urlOficial =
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent";

  Future<String> obtenerConsejo({
    required String contextData,
    required String periodType,
    bool isNewUser = false,
  }) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (apiKey.isEmpty) return "Error: API KEY no configurada en .env";

    // --- System Instruction (comportamiento del modelo) ---
    const systemInstruction = """
Eres un Asesor Financiero personal de élite. Analiza los datos proporcionados y da insights accionables y directos.

REGLAS ESTRICTAS:
1. Basa tu análisis ÚNICAMENTE en los datos enviados. Cero alucinaciones.
2. Tono: Profesional, motivador, conciso y de tú a tú.
3. Usa SIEMPRE el símbolo de moneda indicado en los datos financieros del usuario.
4. ALERTA ROJA: Si un Gasto Fijo vence pronto (hoy o mañana), menciónalo primero. ALERTA AMARILLA: Si los gastos superan el 80% del presupuesto.
5. Comenta siempre el progreso de las Metas si existen.

ESTRUCTURA MARKDOWN OBLIGATORIA: 
- Usa emojis sutiles y resalta montos en negritas (ej: **S/ 500.00**). 
- Usa encabezados claros:
  🔴 Atención Inmediata (si aplica)
  📊 Radiografía del Periodo
  🎯 Tus Metas
  💡 El Consejo del Coach
""";

    // El turno del usuario contiene el contexto estructurado
    final userMessage = """
MODO: ${isNewUser ? 'NUEVO_USUARIO' : periodType.toUpperCase()}

$contextData
""";

    final uri = Uri.parse("$_urlOficial?key=$apiKey");

    try {
      final response = await (_client ?? http.Client()).post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "systemInstruction": {
            "parts": [
              {"text": systemInstruction}
            ]
          },
          "contents": [
            {
              "role": "user",
              "parts": [
                {"text": userMessage}
              ]
            }
          ],
          "generationConfig": {
            "temperature": 0.65,
            "topP": 0.85,
            "topK": 40,
            "maxOutputTokens": 1200
          }
        }),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        try {
          String text = json['candidates'][0]['content']['parts'][0]['text'];
          return text;
        } catch (e) {
          debugPrint("GeminiClient: Failed to parse JSON response. Operation: obtenerConsejo");
          return "No se pudo procesar la solicitud con IA.\nInténtalo nuevamente.";
        }
      } else {
        debugPrint("GeminiClient: HTTP Error ${response.statusCode}. Operation: obtenerConsejo");
        return "No se pudo procesar la solicitud con IA.\nInténtalo nuevamente.";
      }
    } catch (e) {
      debugPrint("GeminiClient: Network/Connection Exception. Operation: obtenerConsejo");
      return "No se pudo procesar la solicitud con IA.\nInténtalo nuevamente.";
    }
  }

  Future<Map<String, dynamic>?> analyzeTransaction(
      String text, List<String> categories, List<String> accounts) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      debugPrint("GeminiClient: FATAL - .env key not found.");
      return null;
    }

    final prompt = """
Eres un asistente financiero. Analiza la frase: '$text'.
Tu objetivo es estructurar la transacción en JSON.

TIPO DE TRANSACCIÓN:
"gasto": (gasté, compré, pagué, salida, costo). *REGLA ESTRICTA: Pagar a un amigo, transferir a un tercero o hacer un Yape/Plin a alguien es SIEMPRE un "gasto".*
"ingreso": (cobré, recibí, ingreso, ganancia, me pagaron).
"transferencia": *REGLA ESTRICTA: Una "transferencia" es ÚNICAMENTE mover dinero entre tus PROPIAS cuentas.*

CUENTA / MÉTODO DE PAGO (Estricto y Dinámico):
Detecta si el usuario menciona explícitamente el origen del dinero.
El nombre de la cuenta devuelta DEBE ser EXACTAMENTE uno de los nombres de esta lista de cuentas activas del usuario: [ ${accounts.join(', ')} ]. ESTÁ PROHIBIDO INVENTAR CUENTAS FUERA DE ESTA LISTA.

REGLA REGIONAL Y CONTEXTO LÓGICO DE CUENTAS:
1. "Yape", "yapeé" o "plin" significan transacción bancaria. Asócialo a la cuenta de tu lista que represente un banco (ej. "Banco" o el nombre que el usuario le haya dado).
2. "Pagar luz", "agua", "internet" = Categoría "Servicios".
3. "Retirar efectivo del cajero" = TIPO "transferencia". La cuenta_origen debe ser la cuenta bancaria, y la cuenta_destino debe ser la cuenta de efectivo (ej. "Efectivo").
4. Si el usuario dice 'billetera', 'mano' o 'físico', asócialo a la cuenta de la lista destinada al dinero físico. Si la cuenta fue eliminada y no hay coincidencia clara, devuelve null para que el usuario la seleccione manualmente.

CATEGORÍA:
Deduce la categoría según el contexto.
Las categorías disponibles son: [ ${categories.join(', ')} ].
La 'Categoría' DEBE ser una sola palabra corta o dos. ESTÁ ESTRICTAMENTE PROHIBIDO poner frases largas o descripciones.
REGLA ANTI-ALUCINACIÓN: Si no estás 100% seguro de la categoría o si la que deduces no está en la lista proporcionada, usa obligatoriamente "Otros".

SALIDA JSON (Strict):
Tu respuesta DEBE ser ÚNICA y EXCLUSIVAMENTE un objeto JSON válido. NO incluyas texto antes ni después, ni bloques de código markdown (```json). NUNCA rompas la estructura JSON.
{
"tipo": "gasto" | "ingreso" | "transferencia",
"monto": 0.00,
"moneda": "S/",
"categoria": "String",
"descripcion": "String",
"cuenta_origen_detectada": "String" | null,
"cuenta_destino_detectada": "String" | null
}
""";

    final uri = Uri.parse("$_urlOficial?key=$apiKey");

    try {
      final body = jsonEncode({
        "contents": [
          {
            "parts": [
              {"text": prompt}
            ]
          }
        ]
      });

      debugPrint("🚀 GeminiClient: Analyzing transaction...");
      final response = await (_client ?? http.Client()).post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        String? responseText =
            jsonResponse['candidates']?[0]?['content']?['parts']?[0]?['text'];

        if (responseText == null) return null;

        // Limpieza de Markdown si la IA lo pone
        responseText = responseText
            .replaceAll('```json', '')
            .replaceAll('```JSON', '')
            .replaceAll('```', '')
            .trim();

        try {
          final Map<String, dynamic> data = jsonDecode(responseText);
          return data;
        } catch (e) {
          debugPrint("GeminiClient: Failed to parse JSON response. Operation: analyzeTransaction");
          return null;
        }
      } else {
        debugPrint("GeminiClient: HTTP Error ${response.statusCode}. Operation: analyzeTransaction");
        return null;
      }
    } catch (e) {
      debugPrint("GeminiClient: Network/Connection Exception. Operation: analyzeTransaction");
      return null;
    }
  }
}
