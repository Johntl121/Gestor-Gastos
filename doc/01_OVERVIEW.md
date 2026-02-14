# Visión General del Proyecto: Gestor de Gastos

## 1. Introducción
**Gestor de Gastos** es una solución financiera móvil desarrollada en Flutter, diseñada específicamente para el mercado peruano. Su propuesta de valor reside en la integración de un **Coach Financiero (IA)** que opera bajo restricciones severas de conectividad y cuota.

La aplicación sigue una arquitectura **Local-First**: el 100% de los datos transaccionales residen en el dispositivo (SQLite). La nube (**Gemini AI**) se utiliza estrictamente como un motor de razonamiento bajo demanda, no como almacenamiento.

## 2. Tech Stack (Tecnologías)
*   **Frontend:** Flutter (Dart) - Diseño responsivo y Modo Oscuro nativo.
*   **State Management:** `provider` (Gestión eficiente de reconstrucciones de UI).
*   **Base de Datos:** `sqflite` (SQLite) - Persistencia relacional local.
*   **Inteligencia Artificial:** **Google Gemini 2.5 Flash Lite** (vía `google_generative_ai`).
*   **Voz:** `speech_to_text` (Motor híbrido on-device/cloud).
*   **Entorno:** Gestión de secretos vía `flutter_dotenv`.

## 3. Características Clave y Optimización

### A. Registro Multimodal de Alta Eficiencia
*   **Motor de Voz:** Implementa un parser semántico que convierte lenguaje natural (*"Yapeé 15 soles a Juan por almuerzo"*) en transacciones estructuradas (JSON), detectando automáticamente:
    *   **Intención:** Gasto vs. Ingreso vs. Transferencia.
    *   **Instrumento Financiero:** Mapeo difuso de cuentas (ej. "Yape" -> Cuenta Digital).
    *   **Categorización Contextual:** Inferencia basada en descripción.

### B. Coach Financiero (Estrategia de Escasez)
Dado el límite estricto de **20 Requests Per Day (RPD)** de la API en su capa actual, el sistema implementa:
*   **Gatekeeper Logic:** Bloqueo de solicitudes si no hay suficientes datos nuevos para analizar.
*   **Bienvenida "Fake":** La primera interacción es generada localmente para no consumir cuota durante el onboarding.
*   **Timers de Enfriamiento:** Restricción de análisis semanal (7 días) y mensual (30 días) para forzar el ahorro de tokens y maximizar el valor de cada llamada.

## 4. Estado del Proyecto
*   **Versión:** Beta 1.0.
*   **Plataforma Objetivo:** Android (APK Release).
*   **Localización:** Perú (Moneda: PEN / S/).
