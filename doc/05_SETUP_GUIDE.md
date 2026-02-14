# Guía de Despliegue e Instalación

## 1. Configuración de API Keys
Debido al límite estricto de **20 Requests Per Day (RPD)**, es **CRÍTICO** que cada desarrollador utilice su propia llave de API para pruebas locales.

1.  **Generar Clave:** Visita [Google AI Studio](https://aistudio.google.com/) y crea un nuevo proyecto.
2.  **Modelo Recomendado:** Selecciona el modelo **Gemini 2.5 Flash Lite** (optimizado para latencia baja y consumo mínimo).
3.  **Configuración de Entorno:**
    *   Crea un archivo `.env` en la raíz del proyecto (toma `.env.template` como base).
    *   Añade tu clave: `GEMINI_API_KEY=AIzaSy_TU_CLAVE_AQUI`.

## 2. Compilación para Android
Para generar el ejecutable final (APK) optimizado para producción:

1.  **Limpiar Proyecto:**
    ```bash
    flutter clean
    flutter pub get
    ```

2.  **Compilar APK en Modo Release:**
    ```bash
    flutter build apk --release
    ```

**Nota:** El modo **--release** es necesario para un rendimiento óptimo del motor de renderizado Skia y para minimizar el tamaño de la aplicación final. El APK generado se encontrará en `build/app/outputs/flutter-apk/app-release.apk`.
