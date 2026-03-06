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

| 🏠 Home | 📊 Estadísticas | 📜 Historial | 👛 Billetera & ⚙️ Config. |
|:---:|:---:|:---:|:---:|
| Resumen de saldo, estado de ánimo y actividad reciente. | Gráficos de dona interactivos, metas y el **Coach IA**. | Lista detallada de transacciones con calendario en español. | Gestión de cuentas, tarjetas premium, temática y presupuesto. |

---

## ✨ Características Principales

### 1. 💵 Gestión Híbrida (Efectivo y Digital)
No pierdas de vista el dinero que llevas en la billetera.
*   **Saldo Unificado:** Vista combinada de tus cuentas bancarias y efectivo físico.
*   **Diseño Premium UI/UX:** Inputs fusionados inteligentemente (divisa + monto) y diseño de "tarjetas bancarias" in-app.
*   **Billetera Completa:** Gestiona múltiples cuentas, pagos recurrentes y metas de ahorro visuales reordenables (Drag & Drop).

### 2. 😐 Feedback Emocional (Smart HUD)
La interfaz reacciona a tus hábitos de gasto.
*   🟢 **Feliz:** Si estás gastando responsablemente (dentro del 80% de tu presupuesto).
*   🟡 **Neutral:** Cuando te acercas al límite (80% - 100%).
*   🔴 **Alerta:** Si has excedido tu presupuesto mensual.

### 3. 🎨 Personalización y Experiencia (UX/UI)
Adapta la app a tu estilo visual y disfruta de flujos de trabajo sin fricción.
*   **Temas Dinámicos:** Cambia instantáneamente entre un modo claro limpio ("Paper Style") y un modo oscuro sofisticado ("Midnight Blue").
*   **Consistencia a Nivel Pixel:** Todos los Modals y Bottom Sheets (formularios) comparten la misma paleta profunda y reglas de diseño estandarizadas.
*   **Localización (es_ES):** Soporte regional configurado, incluyendo calendarios 100% traducidos al español.

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
    *   **Zero-Data State:** Protege la cuota de API bloqueando consultas si eres usuario nuevo, desactivando las animaciones hasta que haya data real.
    *   **Persistencia Inteligente:** Guarda tus consejos localmente. Si ya pediste el análisis hoy, te lo muestra al instante.
*   **Diseño Viva (Motion UI):** El botón del Coach presenta un estado _Idle_ (desactivado) y una animación de _Respiración Fluida (Pulse)_ para indicarte en tiempo real que tiene un análisis listo para ti.

---

## 🛠️ Stack Tecnológico

Este proyecto utiliza las mejores prácticas de desarrollo en Flutter:

*   **Frontend:** [Flutter](https://flutter.dev/) (Diseño responsivo y animaciones fluidas).
*   **Arquitectura:** **Clean Architecture** (Capas separadas: Domain, Data, Presentation).
*   **Inteligencia Artificial:** **Google Gemini API** (Análisis financiero) + `flutter_markdown_plus`.
*   **Gestión de Estado:** `Provider` para una gestión reactiva y eficiente.
*   **Inyección de Dependencias:** `GetIt` para desacoplar componentes y facilitar testing.
*   **Persistencia de Datos:** `sqflite` (SQLite) + `shared_preferences`.
*   **Gráficos e UI:** `fl_chart` para visualizaciones, animaciones dinámicas (`TweenAnimationBuilder`).
*   **Internacionalización:** Módulo `intl` y `flutter_localizations` fijados a Español (es_ES).

---

## 🏗️ Estructura del Proyecto

El código está organizado siguiendo estrictamente Clean Architecture para garantizar escalabilidad:

```text
lib/
├── core/                                   # Capa de Infraestructura y Utilidades Compartidas
│   ├── constants/                          # Constantes globales de la app
│   ├── errors/                             # Definición de Errores y Excepciones
│   │   └── failure.dart                    # Clases base para manejo de fallos (ServerFailure, CacheFailure)
│   ├── services/                           # Servicios Externos e Implementaciones Técnicas
│   │   ├── database_helper.dart            # Gestión de Base de Datos Local (SQLite)
│   │   ├── gemini_client.dart              # Cliente para IA (Gemini): Análisis y Entrenador Financiero
│   │   ├── notification_service.dart       # Gestión de Notificaciones Locales (gastos fijos)
│   │   └── speech_service.dart             # Servicio de Reconocimiento de Voz (Voz a Texto)
│   └── usecases/                           # Definiciones Base para Casos de Uso
│       └── usecase.dart                    # Interfaz abstracta genérica
│
├── data/                                   # Capa de Datos (Implementación de Repositorios)
│   ├── models/                             # Modelos de Datos (Mapeo DB <-> Entidades)
│   │   ├── account_model.dart              # Modelo de Cuenta Financiera (BD)
│   │   ├── category_model.dart             # Modelo de Categoría de Gasto (BD)
│   │   ├── subscription.dart               # Modelo de Gasto Recurrente / Suscripción (BD)
│   │   └── transaction_model.dart          # Modelo de Transacción (BD)
│   └── repositories/                       # Lógica de Acceso a Datos
│       ├── transaction_data_source.dart    # DAO local para manipular transacciones SQLite
│       └── transaction_repository_impl.dart # Implementación concreta del repositorio del Dominio
│
├── domain/                                 # Capa de Dominio (Reglas de Negocio Centrales)
│   ├── entities/                           # Entidades de Negocio Puras
│   │   ├── account_entity.dart             # Entidad Cuenta (Efectivo, Bancos, Ahorros)
│   │   ├── balance_breakdown.dart          # Desglose de saldos
│   │   ├── budget_mood.dart                # Enum/Entidad del Estado de Ánimo Financiero
│   │   ├── category_entity.dart            # Entidad Categoría base
│   │   ├── goal_entity.dart                # Entidad Meta de Ahorro
│   │   └── transaction_entity.dart         # Entidad Transacción
│   ├── repositories/                       # Contratos (Interfaces) de Repositorios
│   │   └── transaction_repository.dart     # Interfaz abstracta del Repositorio de Transacciones
│   └── usecases/                           # Casos de Uso (Lógica de Aplicación Específica)
│       └── ...                             # Diversos casos de uso modulares (CRUD, balances, etc.)
│
├── presentation/                           # Capa de UI y Gestión de Estado (Features-First)
│   ├── features/                           # Módulos Funcionales (Pantallas + Lógica específica local)
│   │   ├── auth/                           # Flujos de Autenticación y Bienvenida
│   │   │   ├── intro_page.dart             # Pantalla de Introducción inicial
│   │   │   ├── lock_screen.dart            # Pantalla de Bloqueo por PIN de seguridad
│   │   │   └── onboarding_page.dart        # Flujo de bienvenida y configuración de perfil (Rediseño Premium)
│   │   ├── dashboard/                      # Pantalla de Inicio y Navegación Principal
│   │   │   ├── main_page.dart              # Contenedor raíz con BottomNavigationBar animado
│   │   │   └── home_page.dart              # Tablero principal de saldos y transacciones recientes
│   │   ├── settings/                       # Panel de Configuración
│   │   │   └── settings_page.dart          # Tema visual, moneda base, presupuestos y reseteo de app
│   │   ├── stats/                          # Análisis Inteligente y Estadísticas
│   │   │   ├── stats_page.dart             # Gráficos con Coach Inteligente (animación de respiración fluida)
│   │   │   └── financial_coach_sheet.dart  # Modal persistente del Coach IA con consejos en texto enriquecido
│   │   ├── transactions/                   # Gestión Activa de Movimientos
│   │   │   ├── add_transaction_page.dart   # Formulario veloz pre-categorizado e interactivo
│   │   │   ├── history_page.dart           # Lista de operaciones con componente central de Calendario (es_ES)
│   │   │   └── transaction_search...       # Delegado nativo para búsquedas in-app de movimientos
│   │   └── wallet/                         # Gestión Macro de Patrimonio
│   │       ├── wallet_page.dart            # Pantalla central de cuentas, abonos fijos visuales y metas reordenables
│   │       └── widgets/                    # Sub-Componentes Premium de Billetera
│   │           ├── add_account_sheet.dart  # Input fusionado con selector de divisa interactivo a la izquierda
│   │           ├── add_fixed_expense_sheet.dart # Modals unificados UI/UX para pagos recurrentes
│   │           ├── goal_card.dart          # Tarjetas expansibles físicas (ProxyDrag) para ahorros
│   │           └── goal_form_sheet.dart    # Creador ágil de metas de alcance monetario animado
│   ├── providers/                          # State Management Central (Providers globales)
│   │   ├── stats_provider.dart             # Orquesta análisis, fechas del IA Coach y gráficos
│   │   ├── transaction_provider.dart       # Acciona la DB de gastos corrientes y suscripciones fijas
│   │   ├── ui_provider.dart                # Preferencias visuales inyectadas dinámicamente
│   │   └── wallet_provider.dart            # Mantiene y persiste en vivo saldos base y metas de ahorro
│   └── widgets/                            # Módulos Visuales Compartidos (Cross-Feature)
│       └── budget_mood_widget.dart         # Indicador de salud financiera (Alerta roja dinámica / Neutral / Feliz)
│
├── injection_container.dart                # Desacoplador de Dependencias (Service Locator enlazado vía GetIt)
└── main.dart                               # Wrapper raíz con Localizaciones, MultiProviders y ThemeData
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

*   [x] **Temas & UI:** Soporte completo Light/Dark Mode y Modals unificados.
*   [x] **Billetera Modificada:** Componentes reordenables, divisas interactivas y tarjetas bancarias.
*   [x] **Localización:** Calendarios e interfaz en español (es_ES).
*   [ ] **Refactor de Código:** Migrar propiedades deprecadas de Flutter 3.x (`withOpacity` a `withValues`).
*   [ ] **Sincronización Opcional:** Backup cifrado en Google Drive.

---

## 🤝 Contribución

¡Las contribuciones son bienvenidas! Si tienes ideas para mejorar la gestión financiera offline, no dudes en abrir un **Issue** o enviar un **Pull Request**.

---

Hecho con ❤️ en Dart & Flutter.