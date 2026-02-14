# Arquitectura del Sistema

## 1. Diseño de Software (Frontend vs. Backend)
Aunque **Gestor de Gastos** es una app monolítica en Flutter, su código está estrictamente separado en dos capas lógicas para facilitar el mantenimiento y la escalabilidad.

### 🎨 Frontend (Capa de Presentación)
*   **Ubicación:** `lib/presentation/`
*   **Función:** Es la cara visible de la aplicación. Se encarga de pintar la UI y reaccionar a las interacciones del usuario. No contiene lógica de negocio compleja.
*   **Componentes:**
    *   **Pages:** Pantallas completas (`HomePage`, `StatsPage`, `CoachModal`).
    *   **Widgets:** Componentes reutilizables (`ExpenseCard`, `VoiceFloatingButton`).
    *   **Providers:** Gestores de estado (`DashboardProvider`) que actúan como puente. Reciben eventos de la UI y llaman al Backend.

### ⚙️ Backend Local (Capa de Datos y Lógica)
*   **Ubicación:** `lib/core/` y `lib/data/`
*   **Función:** Es el "cerebro" que opera tras bambalinas. Aquí residen las reglas de negocio, la IA y la base de datos.
*   **Core Services (`lib/core/services/`):**
    *   **GeminiClient:** Cliente HTTP encargado de hablar con la AI de Google. Maneja los Prompts del Sistema y la tolerancia a fallos.
    *   **VoiceService:** Lógica de Speech-to-Text y limpieza de JSON.
*   **Data Layer (`lib/data/`):**
    *   **DatabaseHelper:** Gestión directa de SQLite (tablas `transactions`, `accounts`).
    *   **Models:** Clases Dart (`TransactionModel`) que transforman los datos crudos de la BD en objetos usables.

## 2. Flujo de Datos (Data Flow)
1.  Usuario habla al micrófono en el **Frontend**.
2.  Provider llama a **VoiceService** para obtener texto.
3.  Backend envía texto a **GeminiClient**.
4.  IA responde con un JSON estructurado (ej. `{ "monto": 20, "cuenta": "Yape" }`).
5.  Backend guarda el resultado en **DatabaseHelper** (SQLite).
6.  Frontend recibe la notificación y actualiza la lista de gastos en pantalla.
