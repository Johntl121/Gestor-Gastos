# Visión General del Proyecto: Gestor de Gastos

## 1. Introducción
**Gestor_Gastos** es una aplicación móvil de gestión financiera personal de última generación, diseñada para empoderar a los usuarios en la toma de decisiones económicas diarias. Construida sobre la robustez de **Flutter** y potenciada por la inteligencia artificial de **Google Gemini**, la App no solo registra gastos, sino que actúa como un verdadero **Coach Financiero** proactivo.

El enfoque principal de Gestor de Gastos es la **localización y relevancia cultural** para el mercado peruano, priorizando la moneda local (Nuevos Soles - S/) y entendiendo los contextos de gasto habituales en la región. Además, la aplicación adopta una filosofía **Local-First**, garantizando que los datos financieros sensibles del usuario permanezcan seguros en su dispositivo, utilizando la nube solo para el procesamiento anonimizado de IA.

## 2. Descripción Técnica
Gestor de Gastos combina una interfaz de usuario moderna y fluida con un backend lógico potente. La aplicación permite el registro de transacciones de forma **multimodal**: mediante entrada manual tradicional para precisión, y mediante **comandos de voz naturales** para rapidez y conveniencia.

### Características Clave
*   **Registro Multimodal:**
    *   **Manual:** Formularios intuitivos y rápidos.
    *   **Voz (VoiceInput):** Procesamiento de lenguaje natural para interpretar frases complejas como *"Gaste 20 soles en menú con Yape"* y convertirlas en transacciones estructuradas automáticamente.
*   **Coach Financiero Inteligente:** Un asistente virtual con memoria contextual que ofrece consejos personalizados, análisis de patrones de gasto y alertas proactivas, todo adaptado al contexto socioeconómico local.
*   **Soporte Offline (Local-First):** Funcionalidad completa sin conexión a internet (excepto funciones de IA), gracias a una base de datos SQLite integrada.
*   **Gestión de Cuentas Personalizable:** Soporte para múltiples tipos de cuentas (Efectivo, Bancos, Billeteras Digitales como Yape/Plin) con seguimiento de saldos en tiempo real.
*   **Modo Oscuro/Claro:** Adaptabilidad visual automática o manual según la preferencia del usuario.

## 3. Technology Stack (Pila Tecnológica)

### Frontend & Framework
*   **Framework:** [Flutter](https://flutter.dev/) (Dart) - Para desarrollo multiplataforma nativo.
*   **Arquitectura:** Clean Architecture simplificada + Provider.
*   **Gestión de Estado:** `provider` - Para una gestión de estado eficiente y escalable.

### Backend & Persistencia
*   **Base de Datos Local:** `sqflite` - SQLite para almacenamiento persistente, seguro y rápido en el dispositivo.
*   **Preferencias:** `shared_preferences` - Para configuración de usuario y flags rápidos.

### Inteligencia Artificial (AI Core)
*   **Motor:** Google Gemini 1.5 Flash / 2.5 Flash Lite.
*   **Integración:** HTTP REST API directa (mejor control) y `google_generative_ai`.
*   **Capacidades:**
    *   Procesamiento de Lenguaje Natural (NLP) para categorización de gastos.
    *   Generación de consejos financieros (RAG ligero).
    *   Extracción de entidades (NER) en comandos de voz.

### Servicios Adicionales
*   **Voz a Texto:** `speech_to_text` - Para transcripción en tiempo real.
*   **Gráficos:** `fl_chart` - Para visualización de datos financieros.
*   **Notificaciones:** `flutter_local_notifications` - Para recordatorios y alertas locales.
*   **Seguridad:** `flutter_dotenv` - Para gestión de variables de entorno y claves API.

## 4. Estado del Proyecto
El proyecto se encuentra en una fase activa de desarrollo y refinamiento. Las funcionalidades core (registro, visualización, IA básica) están implementadas y estables. Se está trabajando en la optimización de la experiencia de voz y la expansión de las capacidades predictivas del Coach.
