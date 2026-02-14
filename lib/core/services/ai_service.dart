import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import '../../domain/entities/transaction_entity.dart';
import 'package:intl/intl.dart';

class AIService {
  // Singleton
  static final AIService _instance = AIService._internal();
  factory AIService() => _instance;
  AIService._internal();

  // API Key Management para obtenerla centralizadamente
  String _getApiKey() {
    String? key = dotenv.env['GEMINI_API_KEY'];
    if (key == null || key.isEmpty) {
      debugPrint("AIService: .env key not found, using fallback.");
      return 'AIzaSyAn6iyDavno_Pq9OHQkYljPXuxa4KoXedI';
    }
    return key;
  }

  void init() {
    final key = _getApiKey();
    if (key.isNotEmpty) {
      debugPrint("AIService: Ready (HTTP Mode) with key length: ${key.length}");
    } else {
      debugPrint("AIService: FATAL - No API KEY found.");
    }
  }

  Future<Map<String, dynamic>?> analyzeTransaction(
      String text, List<String> categories, List<String> accounts) async {
    final prompt = """
Eres un asistente financiero. Analiza la frase: '$text'.
Tu objetivo es estructurar la transacción en JSON.

TIPO DE TRANSACCIÓN:
"gasto": (gasté, compré, pagué, salida, costo).
"ingreso": (cobré, recibí, ingreso, ganancia, me pagaron).
"transferencia": (moví, pasé, transferí, envié).

CUENTA / MÉTODO DE PAGO (Dinámico):
Detecta si el usuario menciona explícitamente el origen del dinero.
Busca patrones como: "con [Nombre]", "desde [Nombre]", "por [Nombre]", "en [Nombre]".
Ejemplos: "con BCP", "por Yape", "de mi Ahorro", "en efectivo".
EXTRAE EL NOMBRE EXACTO que dijo el usuario (ej: "BCP", "Visa", "Efectivo").
Si NO menciona cuenta, devuelve null. NO adivines.

CATEGORÍA:
Deduce la categoría según el contexto (Comida, Transporte, Servicios, etc.).
Si no estás seguro, usa "Otros".

SALIDA JSON (Strict):
{
"tipo": "gasto" | "ingreso" | "transferencia",
"monto": 0.00,
"moneda": "S/" (default) | "\$",
"categoria": "String",
"descripcion": "String",
"cuenta_origen_detectada": "String" | null,
"cuenta_destino_detectada": "String" | null
}
""";

    try {
      final apiKey = _getApiKey();
      // 👇 ASEGURA QUE DIGA 'v1' Y NO 'v1beta'
      // Usamos gemini-pro (es el más compatible de la historia de Gemini)
      final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=$apiKey');
      // 👇 Agrega este print justo debajo para que veas en la consola si cambió:
      print("🔥🔥🔥 ESTOY USANDO LA URL: $url");

      final body = jsonEncode({
        "contents": [
          {
            "parts": [
              {"text": prompt}
            ]
          }
        ]
      });

      debugPrint(
          "🚀 AIService: Analyzing transaction with Gemini 1.5 Flash (HTTP)...");
      final response = await http.post(
        url,
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
          debugPrint("AIService JSON Parse Error: $e\nResponse: $responseText");
          return null;
        }
      } else {
        debugPrint(
            "❌ AIService HTTP Error: ${response.statusCode} - ${response.body}");
        return null;
      }
    } catch (e) {
      debugPrint("AIService Network Error: $e");
      return null;
    }
  }

  Future<String> getFinancialAdvice(
      List<TransactionEntity> transactions, double budgetLimit) async {
    // 1. Filter Last 30 Days
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    final recent = transactions
        .where((t) =>
            t.date.isAfter(thirtyDaysAgo) && t.type != TransactionType.transfer)
        .toList();

    if (recent.isEmpty) {
      return "No tienes suficientes transacciones recientes para un análisis. ¡Registra tus gastos y vuelve pronto! 📝";
    }

    // 2. Calculate Totals
    double totalIncome = 0;
    double totalExpense = 0;
    final buffer = StringBuffer();

    for (var t in recent) {
      if (t.type == TransactionType.income) {
        totalIncome += t.amount.abs();
      } else {
        totalExpense += t.amount.abs();
      }

      if (buffer.length < 10000) {
        buffer.writeln(
            "- ${DateFormat('dd/MM').format(t.date)}: ${t.description} (${t.amount < 0 ? 'Gasto' : 'Ingreso'} ${t.amount.abs().toStringAsFixed(2)})");
      }
    }

    final summary = buffer.toString();

    // 3. Prompt
    final prompt = """
Actúa como un asesor financiero personal, empático pero directo.
Analiza este resumen financiero del usuario (últimos 30 días):

- Presupuesto Mensual Definido: $budgetLimit
- Total Ingresos: $totalIncome
- Total Gastos: $totalExpense
- Balance: ${totalIncome - totalExpense}

Transacciones Detalladas:
$summary

Tu tarea:
1. Identifica la categoría o patrón donde más se está gastando innecesariamente.
2. Detecta patrones de gasto (ej: muchos gastos pequeños 'hormiga').
3. Dame 3 consejos accionables y breves para mejorar mi ahorro este mes.

Responde con formato Markdown (negritas, listas) y usa emojis. Sé breve y motivador.
""";

    try {
      final apiKey = _getApiKey();
      final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey');

      final body = jsonEncode({
        "contents": [
          {
            "parts": [
              {"text": prompt}
            ]
          }
        ]
      });

      debugPrint(
          "🚀 AIService: Getting financial advice from Gemini 1.5 Flash (HTTP)...");
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final text =
            jsonResponse['candidates']?[0]?['content']?['parts']?[0]?['text'];
        return text ?? "La IA respondió pero sin texto.";
      } else {
        debugPrint(
            "❌ AIService Advice Error: ${response.statusCode} - ${response.body}");
        return "Hubo un error al consultar tu coach financiero. Intenta más tarde.";
      }
    } catch (e) {
      debugPrint("❌ AIService Network Error: $e");
      return "Error de conexión. Verifica tu internet.";
    }
  }
}
