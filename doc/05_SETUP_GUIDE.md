# Guia de Configuración y Despliegue (Setup Guide)

## 1. Requisitos del Sistema
Antes de comenzar, asegúrate de que tu máquina cumpla con lo siguiente:

*   **Sistema Operativo:** Windows 10/11, macOS, o Linux.
*   **Git:** Instalado y configurado.
*   **Flutter SDK:** Versión estable más reciente (>= 3.22.x). [Guía de Instalación](https://docs.flutter.dev/get-started/install)
*   **Android Studio:** Configurado con Android SDK y emulador (API 30+ recomendada).
*   **Editor de Código:** VS Code (recomendado) con extensiones de Flutter/Dart.

## 2. Clonar el Proyecto

Abre tu terminal favorita (PowerShell, Terminal, Bash) y ejecuta:

```bash
git clone https://github.com/Johntl121/Gestor-Gastos.git
cd Gestor-Gastos
```

## 3. Configuración de API Keys (.env)

El proyecto utiliza `flutter_dotenv` para manejar secretos. **Es obligatorio configurar esto antes de compilar.**

1.  En la raíz del proyecto, busca el archivo `.env.template` (si no existe, crea uno nuevo).
2.  Renómbralo o crea una copia llamada **`.env`**.
3.  Abre el archivo `.env` y pega tu clave de API de Google Gemini:

```env
GEMINI_API_KEY=Tu_Clave_Real_Aqui_AIzaSy...
```

> **¡Importante!** Obtén tu propia API Key personal en [Google AI Studio](https://aistudio.google.com/). El límite gratuito es de **20 Peticiones/Día** por cuenta. No usar la clave de otro desarrollador para evitar bloqueos.

## 4. Instalación de Dependencias

Descarga las librerías necesarias ejecutando:

```bash
flutter pub get
```

## 5. Ejecución en Modo Debug

Para desarrollar y ver cambios en tiempo real:

1.  Abre tu emulador Android o conecta tu celular por USB.
2.  Ejecuta:

```bash
flutter run
```

*   **Tip:** Si tienes varios dispositivos conectados, usa `flutter run -d <id_dispositivo>`.
*   **Tip:** Presiona `r` en la terminal para *Hot Reload* o `R` para *Hot Restart*.

## 6. Compilación para Producción (APK)

Para generar el archivo instalable (.apk) optimizado:

```bash
flutter build apk --release
```

El archivo APK se generará en: `build/app/outputs/flutter-apk/app-release.apk`.
Este archivo puede ser enviado por WhatsApp o Drive e instalado en cualquier Android.

## 7. Solución de Problemas Comunes

### Error: "API Key not found"
*   Verifica que el archivo se llame exactamente `.env` (sin espacios extra).
*   Asegúrate de que está en la raíz del proyecto, al mismo nivel que `pubspec.yaml`.
*   Ejecuta `flutter clean` y vuelve a compilar.

### Error: "Gradle task assembleDebug failed"
*   Verifica tu conexión a internet (Gradle necesita descargar dependencias).
*   Abre la carpeta `android/` en Android Studio y deja que sincronice el proyecto ("Sync Project with Gradle Files").
*   Asegúrate de tener un JDK (Java Development Kit) versión 17 o superior configurado.

### La App no escucha mi voz
*   En el emulador: Habilita el micrófono en la configuración del emulador.
*   En dispositivo físico: Acepta el permiso de micrófono cuando la App lo solicite por primera vez.

## 8. Herramientas de Desarrollo (Admin Mode)
Si necesitas borrar la base de datos o probar el Coach Financiero sin esperar una semana:
1.  En la pantalla principal, mantén presionado tu **Avatar/Nombre**.
2.  Se abrirá un panel secreto.
3.  Usa "Reset Timers" o "Factory Reset" según necesites. (Solo funciona en modo Debug).
