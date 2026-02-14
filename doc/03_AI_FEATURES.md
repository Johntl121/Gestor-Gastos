# Especificaciones de Inteligencia Artificial

## 1. Gestión de Cuota y RPD (The 20 RPD Challenge)
El proyecto opera bajo el modelo **Gemini 2.5 Flash Lite** con un límite estricto de **20 Peticiones Por Día (RPD)**.

### Estrategia de Mitigación
Para garantizar la funcionalidad sin exceder la cuota, se implementan los siguientes mecanismos:

*   **Validación Previa (Gatekeeper):** El botón de "Consultar Coach" verifica localmente si existen suficientes transacciones nuevas para justificar una llamada. Si no hay cambios significativos, se bloquea la solicitud mostrada un progreso visual.
*   **Caché de Respuestas:** El sistema almacena la última respuesta exitosa del Coach. Si el usuario vuelve a consultar dentro del mismo periodo (Semanal/Mensual), se sirve el contenido desde la Caché (SQLite/SharedPrefs) sin tocar la API.
*   **Feedback de Error:** Si la API devuelve error **429 (Too Many Requests)**, la UI informa amigablemente al usuario que "El Coach está descansando" y sugiere intentar mañana.

## 2. Ingeniería de Prompts (Voice Service)
El éxito del reconocimiento de voz radica en un prompt estructurado que fuerza una salida **JSON estricta**, minimizando errores de parseo.

### Prompt del Sistema (Extracto)
El siguiente prompt se inyecta en cada petición de voz:

```plaintext
"Actúa como un parser de datos financieros. Tu entrada es lenguaje natural, tu salida es SIEMPRE JSON.
Reglas:
1. Si no hay moneda, asume 'S/'.
2. Detecta cuentas dinámicas (ej: 'Caja Piura').
3. Estructura: {
     'tipo': 'gasto'|'ingreso'|'transferencia',
     'monto': float,
     'cuenta_origen': string
   }"
```

### Flujo de Datos (Pipeline)
1.  **Audio** (Usuario habla)
2.  -> **SpeechToText** (Transcripción String)
3.  -> **Gemini Flash Lite** (Procesamiento Semántico)
4.  -> **JSON Parsing** (Validación de estructura)
5.  -> **Dart Object** (Mapeo a Entidad)
6.  -> **SQLite** (Persistencia)
