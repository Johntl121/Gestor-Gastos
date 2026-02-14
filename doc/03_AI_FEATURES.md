# Capacidades de Inteligencia Artificial

## 1. Módulo de Voz: "Detector Universal"
El sistema de voz de la aplicación no es un simple dictado. Es un motor de clasificación de intenciones basado en un **Prompt de Ingeniería** avanzado.

### Lógica de Procesamiento
El prompt del sistema (VoiceService) instruye a la IA para:

1.  **Clasificar el Tipo:**
    *   **Gasto:** "Compré", "Gasté", "Pagué".
    *   **Ingreso:** "Cobré", "Recibí", "Me depositaron".
    *   **Transferencia:** "Pasé a ahorros", "Moví a BCP".

2.  **Detección de Cuentas (Fuzzy Matching):**
    *   Identifica nombres de cuentas dinámicos: "con Yape", "desde mi Caja Chica".
    *   Si la cuenta detectada coincide con una existente en la BD, se asigna automáticamente.

3.  **Extracción de Datos:**
    *   **Moneda:** Por defecto S/ (Nuevos Soles).
    *   **Categoría:** Automática basada en contexto (ej. "Pollo a la brasa" -> *Comida*).

## 2. Coach Financiero: Lógica de Ahorro
Para optimizar la experiencia y los costos, el Coach implementa lógica condicional:

### Bienvenida Local (Zero-Cost)
*   **Condición:** Usuario con 0 transacciones.
*   **Acción:** Se muestra un mensaje pre-grabado en el dispositivo ("¡Hola! Empieza registrando un gasto..."). No se llama a la API.

### Análisis Real
*   **Condición:** Usuario con datos + intervalo de tiempo cumplido (7 días / 30 días).
*   **Acción:** Se envía un resumen estadístico anonimizado a **Gemini 1.5/2.5 Flash**.
*   **Output:** Consejo financiero personalizado en formato Markdown.
