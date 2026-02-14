# Arquitectura del Sistema

## 1. Estructura de Directorios
El proyecto sigue una arquitectura por capas (**Clean Architecture** simplificada) para separar responsabilidades y facilitar el mantenimiento a largo plazo:

```plaintext
lib/
├── core/                  # Núcleo de la aplicación
│   ├── services/          # Comunicación con el exterior
│   │   ├── gemini_client.dart  # Cliente AI (Manejo de Quotas y Prompts)
│   │   └── voice_service.dart  # Procesamiento de Audio y Speech-to-Text
│   └── utils/             # Utilidades generales (Formatos, Fechas)
├── data/                  # Capa de Datos (Backend Local)
│   ├── repositories/      # Repositorios (TransactionDataSource)
│   └── models/            # Modelos de Datos (DTOs)
│       ├── transaction_model.dart
│       └── account_model.dart
├── presentation/          # Capa de UI (Frontend)
│   ├── pages/             # Pantallas (Scaffolds: Home, Stats, Add)
│   ├── widgets/           # Componentes Reutilizables (Cards, Buttons)
│   └── providers/         # Lógica de Estado (ViewModel: DashboardProvider)
└── main.dart              # Punto de Entrada e Inyección de Dependencias
```

## 2. Desglose de Capas

### Capa de Presentación (Frontend)
*   Encargada exclusivamente del renderizado. **No manipula datos persistentes directamente**.
*   **Patrón:** Utiliza `ChangeNotifierProvider` para escuchar cambios en la BD y reconstruir la vista reactivamente.
*   **Responsabilidad:** Captura inputs (teclado/micrófono), muestra estados de carga (`_isLoading`) y feedback de error.

### Capa de Datos (Backend Local)
*   **SQLite:** Actúa como la fuente de verdad única del sistema.
*   **Tablas Principales:**
    *   `transactions`: Almacena monto, tipo, categoría, fecha, cuenta_id, notas.
    *   `accounts`: Almacena saldo actual, nombre, tipo de cuenta, moneda.

### Capa de Servicios (External)
*   **GeminiClient:**
    *   Encapsula la lógica de reintentos y manejo de errores HTTP 503/429.
    *   Inyecta el **System Prompt** que define la personalidad del Coach Financiero.
*   **VoiceService:**
    *   Gestiona la escucha activa y la limpieza de transcripciones antes de enviarlas a la IA.
