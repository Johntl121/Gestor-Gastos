# Modo Administrador (Dev Tools)

## 1. Acceso al Modo Administrador
Para facilitar el desarrollo, pruebas y depuración en vivo, la aplicación incorpora un **Panel de Administrador (Developer Panel)** oculto. Este panel permite acceder a herramientas avanzadas sin compilar una nueva versión de la app.

### Cómo Activar
1.  En la pantalla principal (`HomePage`), localiza el **Botón Flotante (FAB) de Agregar** o un área de título específica.
2.  Realiza un gesto de **Pulsación Larga (Long Press)** sobre el elemento designado (generalmente el título "Hola, [Usuario]" o el saldo total).
3.  Ingresa el **PIN de Seguridad (Dev PIN)** si está configurado (por defecto: `1234` en entornos de desarrollo).
4.  El Panel de Administrador se desplegará.

---

## 2. Herramientas Disponibles

### A. Factory Reset (Borrado Total)
Borra **TODA** la base de datos local y restablece la configuración de la aplicación a sus valores de fábrica.
*   **⚠️ Advertencia:** Esta acción es irreversible. Se perderán todas las transacciones, cuentas, presupuestos y ajustes.
*   **Uso:** Pruebas de instalación desde cero (`Onboarding`), limpieza tras pruebas de estrés.

### B. Reset Coach Timers (Reinicio de Temporizadores)
Restablece los contadores de tiempo (semanal/mensual) que limitan las consultas al Coach Financiero.
*   **Utilidad:** Permite probar múltiples respuestas del Coach en una sola sesión sin esperar 7 o 30 días reales.
*   **Efecto:** Muestra el botón de "Análisis Semanal" o "Balance Mensual" como disponible inmediatamente.

### C. Seed Fake Data (Generación de Datos de Prueba)
Puebla la base de datos con un conjunto de datos ficticios pero realistas.
*   **Contenido Generado:**
    *   3 Cuentas (Efectivo, BCP, Interbank).
    *   20-50 Transacciones variadas (Gastos hormiga, Servicios, Transporte, Ingresos).
    *   Fechas distribuidas en el último mes.
*   **Uso:** Pruebas de visualización de gráficos (`StatsPage`), rendimiento de listas largas y análisis del Coach Financiero con datos suficientes.

### D. Toggle Debug Mode (Modo Depuración Visual)
Activa/Desactiva superposiciones visuales (`Overlay`) con información técnica en tiempo real.
*   **Información Mostrada:** FPS, Uso de Memoria, Consultas SQL recientes, Respuestas crudas de la API de IA.
*   **Estado:** Experimental.

---

## 3. Seguridad del Modo Administrador
El código que gestiona estas herramientas se encuentra protegido por verificaciones de compilación (`kDebugMode`) o mediante flags de configuración (`bool enableAdminMode = false` en `DashboardProvider`).
*   **Producción:** En versiones *Release*, este modo está deshabilitado por defecto y el gesto de acceso no tiene efecto, garantizando que el usuario final no acceda a funciones destructivas.
*   **Seguridad Adicional:** El acceso requiere confirmación explícita (diálogo de alerta) antes de ejecutar acciones críticas como el *Factory Reset*.
