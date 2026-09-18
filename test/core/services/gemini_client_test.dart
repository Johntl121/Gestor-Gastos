import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'package:gestor_gastos/core/services/gemini_client.dart';

void main() {
  setUpAll(() {
    dotenv.loadFromString(envString: 'GEMINI_API_KEY=test-key');
  });

  group('GeminiClient Tests', () {
    test('obtenerConsejo handles network errors gracefully', () async {
      final mockClient = MockClient((request) async {
        throw Exception("Network failure");
      });

      final client = GeminiClient(client: mockClient);
      final result = await client.obtenerConsejo(
        contextData: 'context',
        periodType: 'month',
      );

      expect(result, "No se pudo procesar la solicitud con IA.\nInténtalo nuevamente.");
    });

    test('obtenerConsejo handles server HTTP errors gracefully', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final client = GeminiClient(client: mockClient);
      final result = await client.obtenerConsejo(
        contextData: 'context',
        periodType: 'month',
      );

      expect(result, "No se pudo procesar la solicitud con IA.\nInténtalo nuevamente.");
    });

    test('analyzeTransaction handles network errors gracefully', () async {
      final mockClient = MockClient((request) async {
        throw Exception("Network failure");
      });

      final client = GeminiClient(client: mockClient);
      final result = await client.analyzeTransaction('text', [], []);

      expect(result, isNull);
    });

    test('analyzeTransaction handles invalid JSON gracefully', () async {
      final mockClient = MockClient((request) async {
        // Devuelve un JSON con la estructura correcta de Gemini pero con contenido que falla el parseo final
        final responsePayload = {
          "candidates": [
            {
              "content": {
                "parts": [
                  {"text": "Esto no es un json valido"}
                ]
              }
            }
          ]
        };
        return http.Response(jsonEncode(responsePayload), 200);
      });

      final client = GeminiClient(client: mockClient);
      final result = await client.analyzeTransaction('text', [], []);

      expect(result, isNull);
    });
  });
}
