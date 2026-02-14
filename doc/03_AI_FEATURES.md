# Inteligencia Artificial en FinIA (AI Core)

## 1. Módulo de Procesamiento de Voz (VoiceInput)
El módulo de voz transforma comandos verbales en transacciones estructuradas. Es el componente central de la experiencia "multimodal".

### Flujo de Datos
1.  **Entrada de Audio (Speech-to-Text):** El usuario habla. `speech_to_text` convierte el audio a una cadena de texto (*transcript*).
    *   *Ejemplo:* "Gaste 20 soles en menú con Yape".
2.  **Análisis Semántico (Gemini 1.5/2.5):** El texto transcrito se envía a la API de Google Gemini con un **Prompt de Ingeniería** específico.
    *   **Objetivo:** Extraer entidades (NER) y clasificar la intención.
    *   **Prompt (Simplificado):**
        ```text
        Eres un asistente financiero experto. Analiza: "$TEXTO".
        Extrae: Monto (default PEN/S/), Categoría (Comida, Transporte...), Cuenta (BCP, Yape, Efectivo...), Título, Tipo (Gasto/Ingreso).
        Salida: JSON estricto.
        ```
3.  **Extracción de Entidades & Matching:**
    *   **Monto:** Detecta números y símbolos de moneda.
    *   **Categoría:** Mapea palabras clave ("menú", "restaurant") a categorías predefinidas ("Comida"). Si no hay coincidencia clara, usa "Otros".
    *   **Cuentas Dinámicas (Fuzzy Matching):** El sistema busca coincidencias parciales entre la cuenta mencionada ("Yape") y la lista de cuentas activas del usuario (`provider.accounts`). Si encuentra una coincidencia, la preselecciona. Si no, usa la cuenta por defecto.
4.  **Confirmación de Usuario:** Muestra un *Modal de Confirmación* `AddTransactionPage` con los datos extraídos prellenados para revisión rápida antes de guardar.

### Capacidades Detectadas
*   Gastos ("Gaste...", "Compre...", "Pague...").
*   Ingresos ("Cobre...", "Me pagaron...", "Gane...").
*   Transferencias ("Movi...", "Pase...", "Transferi...").
*   Cuentas ("...con BCP", "...desde mi Ahorro").

---

## 2. Coach Financiero (Financial Coach)
Un asistente conversacional proactivo que analiza los datos financieros históricos para ofrecer *insights* personalizados.

### Arquitectura del Coach
*   **Modelo Base:** Google Gemini 1.5 Flash (Optimizado para latencia y costo).
*   **RAG Ligero (Retrieval-Augmented Generation):**
    1.  El sistema consulta la base de datos local para obtener un resumen estadístico (gastos por categoría, transacciones recientes, balance mensual).
    2.  Inyecta este resumen en el *Contexto del Prompt* del modelo.
    3.  El modelo genera una respuesta personalizada basada en estos datos reales.

### Estrategia de Tokens y Costos (Rate Limiting)
Para evitar el consumo excesivo de la API (y mantener el tier gratuito/bajo costo):
*   **Análisis Semanal:** Solo se permite solicitar un análisis profundo una vez por semana.
*   **Balance Mensual:** Disponible una vez al mes (generalmente al cierre).
*   **Caché Local:** Las respuestas del Coach se guardan localmente (`SharedPreferences` o BD) para evitar regenerar el mismo consejo múltiples veces.

### Personalización y Localización (Perú)
*   **Persona:** "Asesor Financiero Empático y Directo".
*   **Moneda:** Prioridad absoluta a **Nuevos Soles (S/)**. El prompt del sistema fuerza este formato.
*   **Contexto Cultural:** Entiende términos locales como "menú", "combi", "mototaxi", "yapear".
*   **Bienvenida (Onboarding):** Para usuarios nuevos sin datos suficientes, el sistema genera una respuesta predefinida (*Fake Response*) cálida y motivadora, evitando llamadas innecesarias a la API y errores por falta de contexto.

---

## 3. Seguridad y Privacidad (AI)
*   **Datos Anonimizados:** Solo se envían metadatos financieros (montos, categorías, fechas) al modelo. No se envía información personal identificable (PII) como nombres completos, correos o ubicaciones exactas, salvo lo que el usuario diga explícitamente en la nota de voz.
*   **No Entrenamiento:** Se utiliza la API empresarial de Gemini/Vertex AI (si aplica) con la configuración de *no utilizar datos para entrenamiento* activada por defecto en la política de Google Cloud.
*   **Claves API:** La API Key de Gemini se almacena de forma segura en `flutter_dotenv` (.env) y no se expone en el repositorio público.
