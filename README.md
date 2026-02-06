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

---

## 🛠️ Stack Tecnológico

Este proyecto utiliza las mejores prácticas de desarrollo en Flutter:

*   **Frontend:** [Flutter](https://flutter.dev/) (Diseño responsivo y animaciones fluidas).
*   **Arquitectura:** **Clean Architecture** (Capas separadas: Domain, Data, Presentation).
*   **Gestión de Estado:** `Provider` para una gestión reactiva y eficiente.
*   **Inyección de Dependencias:** `GetIt` para desacoplar componentes y facilitar testing.
*   **Persistencia de Datos:** `sqflite` (SQLite) + `shared_preferences`.
*   **Gráficos:** `fl_chart` para visualizaciones de datos potentes.
*   **Internacionalización:** Soporte base para localización (actualmente en Español 🇪🇸).

---

## 🏗️ Estructura del Proyecto

El código está organizado siguiendo estrictamente Clean Architecture para garantizar escalabilidad:

```text
lib/
├── core/                   # Bloques construcción base (Failures, Usecases, Utils)
├── data/                   # Capa de Datos
│   ├── datasources/        # Fuentes locales (SQLite, SharedPreferences)
│   ├── models/             # Modelos de datos (parseo JSON/Map)
│   └── repositories/       # Implementación concreta de repositorios
├── domain/                 # Capa de Dominio (Pura Dart)
│   ├── entities/           # Reglas de negocio y objetos fundamentales
│   ├── repositories/       # Contratos (Interfaces abstractas)
│   └── usecases/           # Casos de uso específicos (AddTransaction, GetBalance...)
├── presentation/           # Capa de UI
│   ├── pages/              # Pantallas (Home, Stats, Settings, AddTransaction)
│   ├── providers/          # ViewModels / State Management
│   └── widgets/            # Componentes reutilizables
└── main.dart               # Punto de entrada e inicialización (Dependency Injection)
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