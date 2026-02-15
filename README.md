# 💰 Gestor de Gastos: Cash vs Digital

![Flutter](https://img.shields.io/badge/Flutter-3.0%2B-02569B?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.0%2B-0175C2?logo=dart)
![Architecture](https://img.shields.io/badge/Architecture-Clean-success)
![Status](https://img.shields.io/badge/Status-En%20Desarrollo-orange)

> **Tu salud financiera en tu bolsillo. Sin internet, sin nubes, 100% privado.**
> Una aplicación móvil diseñada para cerrar la brecha entre tus finanzas digitales y el dinero en efectivo, con un feedback emocional único.

---

## 📱 Vistazo Rápido a la Aplicación

La aplicación cuenta con una interfaz moderna adaptable a **Modo Claro ☀️** y **Modo Oscuro 🌙**, diseñada para ser elegante y funcional en cualquier entorno.

| 🏠 Home | 📊 Estadísticas | 📜 Historial | ⚙️ Configuración |
|:---:|:---:|:---:|:---:|
| Resumen de saldo, estado de ánimo y actividad reciente. | Gráficos de dona interactivos y desglose de gastos. | Lista detallada de transacciones agrupadas por fecha. | Gestión de perfil, presupuesto, temas y preferencias. |

---

## ✨ Características Principales

### 1. 💵 Gestión Híbrida (Efectivo y Digital)
No pierdas de vista el dinero que llevas en la billetera.
*   **Saldo Unificado:** Vista combinada de tus cuentas bancarias y efectivo físico.
*   **Entrada Rápida:** Agrega transacciones en segundos con un teclado numérico gigante y categorización intuitiva.
*   **Billetera Completa:** Gestiona múltiples cuentas, transferencias y metas de ahorro visuales.

### 2. 😐 Feedback Emocional (Smart HUD)
La interfaz reacciona a tus hábitos de gasto.
*   🟢 **Feliz:** Si estás gastando responsablemente (dentro del 80% de tu presupuesto).
*   🟡 **Neutral:** Cuando te acercas al límite (80% - 100%).
*   🔴 **Alerta:** Si has excedido tu presupuesto mensual.

### 3. 🎨 Personalización Visual (¡Nuevo!)
Adapta la app a tu estilo o condiciones de luz.
*   **Temas Dinámicos:** Cambia instantáneamente entre un modo claro limpio ("Paper Style") y un modo oscuro sofisticado ("Midnight Blue").
*   **Consistencia:** Desde los gráficos hasta los diálogos de calendario, todo elemento respeta tu elección visual.

### 4. 📊 Estadísticas Visuales
Entiende dónde se va tu dinero con un vistazo.
*   **Gráfico Circular (Donut Chart):** Visualización clara de porcentajes de gasto.
*   **Top Spending:** Lista de categorías donde más gastas, con alertas visuales.

### 5. ⚙️ Control Total y Privacidad
*   **Configuración de Presupuesto:** Define tu límite mensual fácilmente.
*   **Exportación de Datos:** Genera reportes CSV de tus transacciones (Copiar al portapapeles) para análisis externo.
*   **Offline First:** Todos los datos se guardan localmente en tu dispositivo usando **SQLite**. Cero rastreadores, cero nube.

### 6. 🧠 Coach Financiero con IA (Nuevo)
Tu asistente personal inteligente para tomar mejores decisiones.
*   **Análisis Dual:**
    *   📅 **Semanal (Flash):** Consejos rápidos y accionables para corregir el rumbo inmediato (Rumbo y Corrección).
    *   🗓️ **Mensual (Profundo):** Reporte detallado de metas, ahorro acumulado y balance general con formato Markdown rico visualmente.
*   **Interfaz Premium:** Respuestas renderizadas con negritas, emojis y secciones claras para una lectura agradable.
*   **Cero Costo Innecesario:**
    *   **Zero-Data State:** Protege la cuota de API bloqueando consultas si eres usuario nuevo (<= 5 transacciones) y te guía con mensajes locales.
    *   **Persistencia Inteligente:** Guarda tus consejos localmente. Si ya pediste el análisis hoy, te lo muestra al instante sin gastar datos ni tiempo.

---

## 🛠️ Stack Tecnológico

Este proyecto utiliza las mejores prácticas de desarrollo en Flutter:

*   **Frontend:** [Flutter](https://flutter.dev/) (Diseño responsivo y animaciones fluidas).
*   **Arquitectura:** **Clean Architecture** (Capas separadas: Domain, Data, Presentation).
*   **Inteligencia Artificial:** **Google Gemini API** (Análisis financiero) + `flutter_markdown_plus`.
*   **Gestión de Estado:** `Provider` para una gestión reactiva y eficiente.
*   **Inyección de Dependencias:** `GetIt` para desacoplar componentes y facilitar testing.
*   **Persistencia de Datos:** `sqflite` (SQLite) + `shared_preferences`.
*   **Gráficos:** `fl_chart` para visualizaciones de datos potentes.
*   **Internacionalización:** Soporte base para localización (actualmente en Español 🇪🇸).

---

## 🏗️ Estructura del Proyecto

El código está organizado siguiendo estrictamente Clean Architecture para garantizar escalabilidad:

```
lib/
├── core/                                   # Capa de Infraestructura y Utilidades Compartidas
│   ├── constants/                          # Constantes globales (si aplica)
│   ├── errors/                             # Definición de Errores y Excepciones
│   │   └── failure.dart                    # Clases base para manejo de fallos (ServerFailure, CacheFailure)
│   ├── services/                           # Servicios Externos e Implementaciones Técnicas
│   │   ├── database_helper.dart            # Gestión de Base de Datos Local (SQLite)
│   │   ├── gemini_client.dart              # Cliente para IA (Gemini): Análisis de voz y Consejos Financieros
│   │   ├── notification_service.dart       # Gestión de Notificaciones Locales
│   │   └── speech_service.dart             # Servicio de Reconocimiento de Voz (Speech-to-Text)
│   └── usecases/                           # Definiciones Base para Casos de Uso
│       └── usecase.dart                    # Interfaz abstracta para Casos de Uso
│
├── data/                                   # Capa de Datos (Implementación de Repositorios)
│   ├── models/                             # Modelos de Datos (Mapeo JSON/DB <-> Entidades)
│   │   ├── account_model.dart              # Modelo de Cuenta Financiera
│   │   ├── category_model.dart             # Modelo de Categoría de Gasto
│   │   ├── subscription.dart               # Modelo de Suscripción Recurrente
│   │   └── transaction_model.dart          # Modelo de Transacción (Ingreso/Gasto)
│   └── repositories/                       # Implementación concreta de los Repositorios del Dominio
│       ├── transaction_data_source.dart    # Fuente de Datos Local (DAO)
│       └── transaction_repository_impl.dart # Lógica de Acceso a Datos (Coordina DB local y lógica)
│
├── domain/                                 # Capa de Dominio (Reglas de Negocio Puras)
│   ├── entities/                           # Entidades de Negocio
│   │   ├── account_entity.dart             # Entidad Cuenta (Efectivo, Banco, Ahorro)
│   │   ├── balance_breakdown.dart          # Entidad para desglose de balance
│   │   ├── budget_mood.dart                # Enum/Entidad para Estado de Ánimo Financiero
│   │   ├── category_entity.dart            # Entidad Categoría
│   │   ├── goal_entity.dart                # Entidad Meta de Ahorro
│   │   └── transaction_entity.dart         # Entidad Transacción Principal
│   ├── repositories/                       # Contratos (Interfaces) de Repositorios
│   │   └── transaction_repository.dart     # Interfaz del Repositorio de Transacciones
│   └── usecases/                           # Casos de Uso (Lógica de Aplicación)
│       ├── account_usecases.dart           # Crear/Leer Cuentas
│       ├── add_transaction_usecase.dart    # Agregar Transacción
│       ├── delete_account_usecase.dart     # Eliminar Cuenta
│       ├── delete_transaction_usecase.dart # Eliminar Transacción
│       ├── get_account_balance_usecase.dart # Obtener Balance
│       ├── get_budget_mood_usecase.dart    # Calcular Estado de Ánimo
│       ├── get_monthly_budget_usecase.dart # Obtener Presupuesto Mensual
│       ├── get_transactions_usecase.dart   # Obtener Historial de Transacciones
│       ├── update_account_usecase.dart     # Actualizar Cuenta
│       └── update_transaction_usecase.dart # Actualizar Transacción
│
├── presentation/                           # Capa de Presentación (UI y Estado)
│   ├── pages/                              # Pantallas de la Aplicación
│   │   ├── add_transaction_page.dart       # Formulario para Agregar/Editar Transacción
│   │   ├── history_page.dart               # Historial Completo con Filtros y Calendario
│   │   ├── home_page.dart                  # Pantalla Principal (Dashboard)
│   │   ├── intro_page.dart                 # Pantalla de Introducción
│   │   ├── lock_screen.dart                # Pantalla de Bloqueo por PIN
│   │   ├── main_page.dart                  # Contenedor Principal (BottomNavigationBar + Navegación)
│   │   ├── onboarding_page.dart            # Flujo de Bienvenida
│   │   ├── settings_page.dart              # Configuración (Tema, Reset, Perfil)
│   │   ├── stats_page.dart                 # Estadísticas Gríficas y Coach Financiero
│   │   ├── transaction_search_delegate.dart # Lógica de Búsqueda
│   │   └── wallet_page.dart                # Gestión de Cuentas y Metas
│   ├── providers/                          # Gestión de Estado (Provider)
│   │   └── dashboard_provider.dart         # Provider Principal (ViewModel para toda la app)
│   └── widgets/                            # Widgets Reutilizables
│       └── budget_mood_widget.dart         # Widget indicador de salud financiera
│
├── injection_container.dart                # Inyección de Dependencias (Service Locator - GetIt)
└── main.dart                               # Punto de Entrada de la Aplicación
```

---

## 🚀 Instalación y Ejecución

Sigue estos pasos para correr el proyecto en tu entorno local:

1.  **Requisitos Previos:**
    *   Flutter SDK instalado (versión 3.0 o superior).
    *   VS Code o Android Studio configurado.

2.  **Clonar el Repositorio:**
    ```bash
    git clone https://github.com/tu-usuario/gestor-gastos.git
    cd gestor-gastos
    ```

3.  **Instalar Dependencias:**
    ```bash
    flutter pub get
    ```

4.  **Generar Código (si es necesario por builds):**
    ```bash
    # Opcional, solo si se usan generadores
    flutter pub run build_runner build
    ```

5.  **Ejecutar:**
    ```bash
    flutter run
    ```

---

## 📅 Próximos Pasos (Roadmap)

*   [x] **Temas:** Soporte completo para Light/Dark Mode.
*   [x] **Billetera:** Gestión de cuentas, transferencias y metas de ahorro.
*   [x] **Exportación:** Exportar reportes básicos (CSV).
*   [ ] **Sincronización Opcional:** Backup en Google Drive (cifrado).
*   [ ] **Notificaciones Inteligentes:** Avisos predictivos de gastos recurrentes.

---

## 🤝 Contribución

¡Las contribuciones son bienvenidas! Si tienes ideas para mejorar la gestión financiera offline, no dudes en abrir un **Issue** o enviar un **Pull Request**.

---

Hecho con ❤️ en Dart & Flutter.