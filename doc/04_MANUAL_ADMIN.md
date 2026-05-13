# Manual de Modo Administrador (Peligro)

## 1. Introducción
**Gestor de Gastos** incluye un modo oculto para **Desarrolladores y QA** que permite reiniciar la base de datos y probar funcionalidades críticas sin reinstalar la aplicación.

**Advertencia de Seguridad:**
Este modo está disponible solo en entornos de desarrollo (`kDebugMode`). No estará activo en la versión de producción (Release) para proteger los datos del usuario final.

## 2. Cómo Acceder al Panel de Administrador

Para activar el **Panel de Desarrollador**, sigue estos pasos:

1.  Abre la aplicación y ve a la pantalla principal (`HomePage`).
2.  Mantén presionado (**Long Press**) el área superior izquierda, donde se muestra tu **Avatar** y **Nombre de Usuario**.
3.  Si estás en modo `Debug` (desarrollo), aparecerá un menú inferior (`BottomSheet`) con herramientas avanzadas.

## 3. Herramientas Disponibles

| Herramienta | Color del Botón | Función Principal | Advertencia |
| :--- | :--- | :--- | :--- |
| **Reset Timers (Coach)** | 🟠 Naranja | Reinicia los contadores de tiempo (Semanal/Mensual) para probar el Coach Financiero sin esperar. | Ninguna, solo afecta el límite de tiempo del Coach IA. |
| **Sembrar Datos (Test)** | 🔵 Azul | Crea una base de datos ficticia con transacciones y cuentas para pruebas de visualización. | Ideal para demos rápidas. |
| **Factory Reset** | 🔴 Rojo | **Borra TODA la base de datos (SQLite v20) y Preferencias**. La aplicación parecerá recién instalada. | **IRREVERSIBLE**. Se perderán todas las transacciones, gastos fijos y metas. |

## 4. Reset del Coach (Técnico)
El botón naranja "Reset Timers" invoca la función `resetCoachTimers()` del `StatsProvider`. Esto elimina las claves de `SharedPreferences` que controlan la última fecha de análisis, permitiendo llamar a la IA nuevamente de inmediato.

*Función interna:* `statsProvider.resetCoachTimers()`
*Impacto en API:* Incrementará el contador de llamadas a Gemini API si vuelves a consultar el Coach inmediatamente.
*Proveedor:* `StatsProvider` (`lib/presentation/providers/stats_provider.dart`)
