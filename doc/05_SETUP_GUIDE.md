# Guía de Instalación y Configuración (Setup Guide)

## 1. Requisitos Previos

Antes de comenzar, asegúrate de tener instalado el siguiente software en tu entorno de desarrollo:

*   **Flutter SDK:** Versión estable más reciente (>= 3.22.x).
    *   [Instalar Flutter](https://docs.flutter.dev/get-started/install)
*   **Editor de Código:**
    *   **VS Code** (Recomendado) con las extensiones oficiales de Flutter y Dart.
    *   **Android Studio** (Opcional, pero útil para emuladores y gestión de SDKs).
*   **Git:** Para control de versiones.
*   **Emulador o Dispositivo Físico:**
    *   **Android:** Configurado y autorizado para depuración USB. (Versión mínima: Android 8.0 - API 26).
    *   **iOS:** (Experimental/No probado exhaustivamente, requiere macOS + Xcode).

## 2. Clonar el Repositorio

Abre tu terminal y ejecuta:

```bash
git clone https://github.com/Johntl121/Gestor-Gastos.git
cd Gestor-Gastos
```

## 3. Configuración de Entorno (.env)

El proyecto utiliza `flutter_dotenv` para gestionar claves API y configuraciones sensibles. **Es obligatorio crear un archivo `.env` en la raíz del proyecto.**

1.  Copia la plantilla de ejemplo `env.template` (si existe) o crea un nuevo archivo llamado `.env`.
2.  Abre el archivo `.env` y añade tu clave de API de Google Gemini:

```env
GEMINI_API_KEY=AIzaSy...Tu_Clave_Real_Aqui...
```

### Obtener una API Key de Google Gemini
1.  Ve a [Google AI Studio](https://aistudio.google.com/).
2.  Inicia sesión con tu cuenta de Google.
3.  Haz clic en **"Get API key"** -> **"Create API key in new project"**.
4.  Copia la clave generada y pégala en tu archivo `.env`.

**IMPORTANTE:** Nunca subas tu archivo `.env` real al repositorio público. Asegúrate de que esté incluido en `.gitignore`.

## 4. Instalación de Dependencias

Ejecuta el siguiente comando para descargar e instalar los paquetes necesarios:

```bash
flutter pub get
```

## 5. Ejecución (Debug)

Para iniciar la aplicación en modo de depuración:

1.  Conecta tu dispositivo o inicia un emulador.
2.  Ejecuta:

```bash
flutter run
```

Si tienes múltiples dispositivos conectados, selecciona el deseado con `flutter run -d <device_id>`.

## 6. Compilación (Release - Android APK)

Para generar un archivo APK instalable y optimizado para producción:

1.  Asegúrate de haber configurado las firmas de la aplicación si deseas subirla a la Play Store (consulta la [documentación oficial](https://docs.flutter.dev/deployment/android#signing-the-app)). Para pruebas locales, el APK de depuración o un *release* sin firmar (debug key) es suficiente.
2.  Ejecuta:

```bash
flutter build apk --release
```
El archivo generado se encontrará en: `build/app/outputs/flutter-apk/app-release.apk`.

## 7. Solución de Problemas Comunes

### Error: "API Key not found" o "Invalid API Key"
*   Verifica que el archivo `.env` exista en la raíz y tenga el formato correcto.
*   Asegúrate de haber añadido `.env` a los `assets` en tu `pubspec.yaml` (aunque `flutter_dotenv` suele manejarlo, a veces es necesario).
*   Reinicia la aplicación completamente (`Shift + R` o detener y volver a ejecutar `flutter run`) para recargar las variables de entorno.

### Error de Compilación en Android
*   Verifica que tienes instalada la versión correcta del NDK y SDK de Android en *Android Studio -> SDK Manager*.
*   Prueba ejecutar `flutter clean` y luego `flutter pub get` antes de volver a compilar.

### El Reconocimiento de Voz no funciona
*   Asegúrate de haber concedido los permisos de **Micrófono** en el dispositivo. (Android > Ajustes > Aplicaciones > Gestor Gastos > Permisos).
*   Verifica que tienes conexión a internet (algunos motores de voz requieren red, aunque `speech_to_text` intenta usar el motor offline si está disponible).
