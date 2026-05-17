# Visión General: Gestor de Gastos

## 1. Introducción
**Gestor de Gastos** es una aplicación móvil nativa desarrollada en Flutter para la gestión de finanzas personales, optimizada para el mercado peruano (moneda Sol `S/`). Su principal diferenciador es la integración de un **Coach Financiero** basado en Inteligencia Artificial (Google Gemini) que opera bajo un modelo de "Escasez de Recursos" (bajo consumo de datos y cuota de API).

El proyecto sigue una filosofía **Local-First**, priorizando la privacidad y la velocidad al mantener la base de datos completa en el dispositivo del usuario mediante SQLite (versión de esquema actual: **v20**).

## 2. Tecnologías (Tech Stack)

A continuación, se detalla la pila tecnológica extraída del `pubspec.yaml` actual:

| Tecnología | Paquete / Librería | Versión | Uso Principal |
| :--- | :--- | :--- | :--- |
| **Framework UI** | `flutter` | 3.x | Desarrollo multiplataforma nativo. |
| **Base de Datos** | `sqflite` | ^2.3.0 | Persistencia relacional local (SQLite v20). |
| **Estado** | `provider` | ^6.0.5 | Gestión de estado reactivo (ChangeNotifier). |
| **DI** | `get_it` | ^7.6.0 | Inyección de dependencias (Service Locator). |
| **FP** | `dartz` | ^0.10.1 | Tipos funcionales (`Either`, `Option`) para manejo de errores. |
| **Igualdad** | `equatable` | ^2.0.5 | Comparación por valor en Entities y Models. |
| **Preferencias** | `shared_preferences` | ^2.5.4 | Almacén clave-valor ligero (timers del Coach, onboarding). |
| **Seguridad** | `flutter_secure_storage` | ^10.0.0 | Almacenamiento seguro de PIN/credenciales. |
| **IA (Motor HTTP)** | `http` | ^1.6.0 | Comunicación directa con Gemini API (control granular). |
| **IA (SDK)** | `google_generative_ai` | ^0.4.7 | SDK oficial de Google Generative AI. |
| **IA (Render)** | `flutter_markdown_plus` | ^1.0.7 | Renderizado de Markdown para respuestas del Coach. |
| **Voz** | `speech_to_text` | ^7.3.0 | Transcripción de audio a texto (STT). |
| **Permisos** | `permission_handler` | ^12.0.1 | Gestión unificada de permisos del sistema. |
| **Gráficos** | `fl_chart` | ^0.66.0 | Visualización de estadísticas financieras (pie, bar). |
| **Calendario** | `table_calendar` | ^3.2.0 | Selector de fechas avanzado. |
| **Internacionalización** | `intl` | ^0.20.2 | Formateo de fechas y monedas. |
| **Notificaciones** | `flutter_local_notifications` | ^17.2.2 | Recordatorios locales de pagos. |
| **Zona Horaria** | `timezone` | ^0.9.2 | Soporte de zonas horarias para notificaciones. |
| **Imágenes** | `image_picker` | ^1.0.4 | Adjuntar comprobantes fotográficos a transacciones. |
| **Archivos** | `path_provider` | ^2.1.1 | Rutas del sistema de archivos del dispositivo. |
| **UUID** | `uuid` | ^4.5.2 | Generación de IDs únicos para gastos fijos y metas. |
| **Íconos** | `font_awesome_flutter` | ^10.12.0 | Iconografía complementaria. |
| **Celebración** | `confetti` | ^0.8.0 | Animación de confeti al completar metas de ahorro. |
| **Entorno** | `flutter_dotenv` | ^6.0.0 | Gestión segura de API Keys (.env). |

## 3. Módulos Funcionales

| Módulo | Descripción |
| :--- | :--- |
| **Dashboard** | Resumen financiero, saldo total, humor presupuestario (Mood) y transacciones recientes. |
| **Transacciones** | Registro manual o por voz de gastos, ingresos y transferencias entre cuentas. |
| **Historial** | Listado completo con buscador, filtros por tipo/cuenta/categoría y calendario. |
| **Estadísticas** | Gráficas desglosadas por categoría con Coach Financiero (IA). |
| **Billetera** | Gestión de cuentas (Efectivo/Digital), gastos fijos recurrentes y metas de ahorro. |
| **Configuración** | Tema oscuro/claro, seguridad PIN, exportación y reset de datos. |
| **Onboarding** | Flujo de bienvenida para nuevos usuarios con configuración inicial. |


