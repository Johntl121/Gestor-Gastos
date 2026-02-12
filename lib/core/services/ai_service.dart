import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/foundation.dart';
import '../../domain/entities/transaction_entity.dart';
import 'package:intl/intl.dart';

class AIService {
  // Singleton
  static final AIService _instance = AIService._internal();
  factory AIService() => _instance;
  AIService._internal();

  GenerativeModel? _model;

  void init() {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey != null) {
      _model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);
    } else {
      debugPrint("AIService: GEMINI_API_KEY not found in .env");
    }
  }

  Future<Map<String, dynamic>?> analyzeTransaction(
      String text, List<String> categories, List<String> accounts) async {
    // ... existing implementation ...
    if (_model == null) init();
    if (_model == null) return null;

    final prompt = """
Eres un experto contable. Analiza el siguiente texto: '$text'.
Extrae: monto, moneda (PEN/USD), cuenta, categoría y título.
Usa ESTAS categorías disponibles: ${categories.join(', ')}.
Usa ESTAS cuentas disponibles: ${accounts.join(', ')}.

Responde SOLAMENTE con un JSON válido (sin markdown ```json) con este formato:
{
  "amount": 0.0,
  "currency": "PEN",
  "category": "NombreExacto",
  "account": "NombreExacto",
  "title": "Descripción corta",
  "type": "expense" (o "income" o "transfer")
}
Si es un gasto, 'type' es 'expense'. Si es ingreso, 'income'. Si es transferencia, 'transfer'.
Si no encuentras algún dato, usa null o deduce lo más lógico.
""";

    try {
      final content = [Content.text(prompt)];
      final response = await _model!.generateContent(content);

      String? responseText = response.text;
      if (responseText == null) return null;

      // Limpieza
      responseText =
          responseText.replaceAll('```json', '').replaceAll('```', '').trim();

      // Decodificar
      try {
        final Map<String, dynamic> data = jsonDecode(responseText);
        return data;
      } catch (e) {
        debugPrint("AIService JSON Error: $e\nResponse: $responseText");
        return null; // O intentar reparar JSON
      }
    } catch (e) {
      debugPrint("AIService Google AI Error: $e");
      return null;
    }
  }

  Future<String> getFinancialAdvice(
      List<TransactionEntity> transactions, double budgetLimit) async {
    if (_model == null) init();
    if (_model == null) return "Error: IA no inicializada.";

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

      // Add to summary string (Limit to last 50 transactions to fit context)
      if (buffer.length < 10000) {
        // Safety limit
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
      final content = [Content.text(prompt)];
      final response = await _model!.generateContent(content);
      return response.text ?? "No pude generar un consejo en este momento.";
    } catch (e) {
      debugPrint("AIService Advice Error: $e");
      return "Hubo un error al conectar con tu asesor financiero. Intenta más tarde.";
    }
  }
}
