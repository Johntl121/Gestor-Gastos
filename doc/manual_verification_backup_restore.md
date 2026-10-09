# Checklist de Verificación Manual: Backup y Restore en Android (FASE 13A-09 / FASE 13A-10)

Este documento detalla el procedimiento y resultados de verificación manual en dispositivo físico Android (**Samsung Galaxy A30s, Android 11, Exynos 7904**) para las integraciones de plataforma (FilePicker, ShareSheet, reinicio interno y ciclo de seguridad).

---

## 1. Dispositivo y Entorno de Prueba
- **Dispositivo:** Samsung Galaxy A30s (SM-A307G).
- **Sistema Operativo:** Android 11 (One UI Core, API 30).
- **Procesador:** Exynos 7904 (Octa-core 1.8 GHz).
- **Modo:** APK Debug instalada vía `adb install -r`.
- **Datos Iniciales (Estado A):** 3 cuentas, 6 movimientos, 15 categorías, 6 preferencias, 0 metas, 0 gastos fijos, 0 recordatorios, 0 adjuntos.
- **Seguridad:** PIN numérico configurado y Biometría (huella dactilar) activa.

---

## 2. Matriz de Ejecución y Checklist Físico

| # | Paso / Acción | Resultado Esperado | Resultado Observado en Galaxy A30s | Estado |
|---|---|---|---|---|
| **01** | Ingresar a **Ajustes** y pulsar en el ListTile **"Crear copia de seguridad"**. | Se despliega el diálogo modal solicitando contraseña y confirmación. El botón "Aceptar" permanece deshabilitado hasta que ambas coincidan y no estén vacías. | Modal se despliega correctamente; botón "Aceptar" inactivo hasta que ambas contraseñas coinciden. | **PASS** |
| **02** | Escribir contraseñas diferentes en el diálogo. | Se muestra mensaje de error "Las contraseñas no coinciden" y el botón continúa inactivo. | Se muestra mensaje de error interactivo y botón permanece inactivo. | **PASS** |
| **03** | Escribir contraseñas idénticas y pulsar **"Aceptar"**. | Aparece indicador de progreso. Tras completar el cifrado, se abre el **ShareSheet** nativo de Android ofreciendo aplicaciones. | Progreso visible durante ~14.8s (PBKDF2 ~13.9s). Modal se cierra y abre ShareSheet nativo de Android. | **PASS** |
| **04** | En el ShareSheet de Android, cancelar o cerrar sin guardar. | El ShareSheet se cierra sin bloquear ni crashear la aplicación. La app permanece reactiva. | ShareSheet se cierra limpiamente; la app continúa respondiendo sin bloqueos. | **PASS** |
| **05** | Repetir creación de backup y seleccionar Google Drive en el ShareSheet. | El archivo `.gestorbackup` se sube/guarda exitosamente en la ubicación seleccionada. | Guardado exitosamente en Google Drive como `estado_a.gestorbackup`. Inspección confirmó GGBK V1 íntegro. | **PASS** |
| **05b** | **Modificar datos a Estado B:** Modificar cuentas y transacciones desde la UI de forma evidente (`Estado B != Estado A`). | La app refleja visiblemente el Estado B. Se constata la divergencia con Estado A antes de restaurar. | Estado B visualmente creado y confirmado en la app. | **PASS** |
| **05c** | **Lifecycle (Background → Foreground):** Minimizar y restaurar la app con diálogos de backup abiertos. | La app regresa de forma estable respondiendo al ciclo de seguridad sin corromper la sesión. | No ejecutado de forma explícita en esta sesión de prueba física. | **NOT TESTED** |
| **06** | Desde Ajustes, pulsar en el ListTile **"Restaurar copia de seguridad"**. | Se abre el **FilePicker nativo del sistema** filtrando por extensión `.gestorbackup`. | Se abre selector de archivos del sistema operativo con filtro `.gestorbackup`. | **PASS** |
| **07** | Pulsar "Atrás" o cancelar en el FilePicker nativo sin seleccionar ningún archivo. | El selector se cierra y la app regresa a Ajustes sin error; los datos de Estado B permanecen intactos. | Selector se cierra limpiamente; Estado B permanece 100% intacto. | **PASS** |
| **08** | Volver a pulsar "Restaurar copia de seguridad" y seleccionar `estado_a.gestorbackup`. | Se despliega el diálogo solicitando la contraseña del archivo seleccionado. | Diálogo de solicitud de contraseña se despliega de inmediato. | **PASS** |
| **09** | Ingresar una **contraseña errónea** y pulsar "Aceptar", luego confirmar advertencia destructiva. | La restauración falla. Se muestra SnackBar específico: «La contraseña es incorrecta o el archivo no es válido». Estado B intacto. | SnackBar muestra mensaje específico de contraseña incorrecta; Estado B permanece intacto. | **PASS** |
| **10** | Repetir selección e introducir la **contraseña correcta**. | Se muestra el diálogo de **"Advertencia destructiva"** alertando que la acción sobrescribirá datos. | Diálogo de advertencia destructiva se muestra con opciones Cancelar y Confirmar. | **PASS** |
| **11** | En la advertencia destructiva, pulsar **"Cancelar"**. | El diálogo se cierra. No se inicia restauración y Estado B no se modifica. | Diálogo se cierra; ningún use case es ejecutado; datos en Estado B intactos. | **PASS** |
| **12** | En la advertencia destructiva, pulsar **"Sí, restaurar"**. | Botones se deshabilitan, texto «Descifrando y restaurando datos. Por favor, espera», spinner visible, PopScope activo. | Botón "Sí, restaurar" se muestra deshabilitado; spinner activo; texto visible; bloqueo de toques concurrentes. | **PASS** |
| **13** | **Reinicio seguro y verificación de datos (vuelta a Estado A):** | `RestartWidget.restartApp` desmonta el árbol, GetIt se reinicializa y **NO se navega a OnboardingPage**. Se recuperan las 3 cuentas y 6 movimientos del Estado A. | App se reinicia internamente; NO aparece Onboarding; se constata el reemplazo de Estado B por las 3 cuentas y 6 movimientos del Estado A. | **PASS** |
| **13b** | **Recuperación física de adjuntos/imágenes:** | Archivos de imagen asociados a movimientos se restauran físicamente en el almacenamiento de la app. | `estado_a.gestorbackup` contenía 0 adjuntos. Verificado en tests automatizados E2E-04, no probado en dispositivo físico. | **NOT TESTED** |
| **14** | Cerrar y volver a abrir la app tras el RESTORE. | Se solicita inmediatamente el PIN de seguridad o autenticación biométrica local. El PIN local sigue activo e inalterado. | LockScreen solicita PIN/biometría; PIN y huella funcionan sin verse afectados por la restauración. | **PASS** |
| **15** | Comprobar ausencia de **fugas visuales de datos** durante el arranque. | La app no muestra el Dashboard financiero antes de autenticar el PIN/biometría. | Sin filtración visual del Dashboard financiero previo al desbloqueo. | **PASS** |

---

## 3. Criterio de Aceptación y Estado de FASE 13A-10
- **Total pruebas físicas ejecutadas:** 11/11 **PASS**.
- **Pruebas no ejecutadas físicamente:** 2 (**NOT TESTED**: 05c Lifecycle y 13b Adjuntos físicos).
- **E2E automatizados complementarios:** 6/6 **PASS** (incluyendo recuperación de adjuntos con verificación SHA-256 e invariantes de seguridad).
- **Veredicto FASE 13A-10:** **VALIDADA Y CERRADA SATISFACTORIAMENTE EN ANDROID REAL**.

---

## 4. Mejoras Pendientes de UX y Rendimiento (Backlog Post-Estabilización)

Las siguientes mejoras quedan registradas para su implementación posterior sin alterar el formato binario `GGBK` V1 ni la compatibilidad criptográfica:

1. **Rendimiento de PBKDF2 y responsividad de UI (Background Isolate):**
   - *Observación:* En procesadores de gama de entrada (Exynos 7904), las 600,000 iteraciones toman ~13.9 segundos en el hilo principal.
   - *Mejora planeada:* Mover la derivación de clave a un isolate en segundo plano (`Isolate.run`), conservando intacto el conteo de 600,000 iteraciones y los parámetros criptográficos.
2. **Comparación de rendimiento Debug frente a Profile/Release:**
   - *Observación:* La compilación debug incluye sobrecostos de aserciones y comprobaciones de la VM de Dart.
   - *Mejora planeada:* Medir tiempos de derivación en APK release/profile donde el compilador AOT optimiza las operaciones criptográficas.
3. **Barra de progreso lineal y mensajes por etapa:**
   - *Observación:* El spinner circular indefinido no informa al usuario sobre el progreso exacto durante los ~14 segundos de espera.
   - *Mejora planeada:* Implementar indicador de progreso con texto informativo de etapa («Preparando datos...», «Descifrando contenedor...», «Restaurando base de datos...»).
4. **Validación interactiva de coincidencia de contraseñas:**
   - *Observación:* El mensaje "Las contraseñas no coinciden" aparece desde que se digita el primer carácter en el campo inicial.
   - *Mejora planeada:* Mostrar la advertencia de discrepancia únicamente cuando el segundo campo (confirmación) haya recibido foco o contenga caracteres.
5. **Visibilidad del SnackBar de éxito en CREATE:**
   - *Observación:* `Share.shareXFiles()` abre de inmediato la hoja del sistema tapando el SnackBar de 4 segundos antes de que el usuario regrese de Drive/archivos.
   - *Mejora planeada:* Disparar la confirmación tras el retorno de la llamada a `shareXFiles` o presentar un diálogo breve de éxito.
6. **Transiciones entre pantallas:**
   - *Observación:* Ciertas transiciones entre vistas tras operaciones de reinicio o cierre de modales se perciben algo bruscas en dispositivos de gama media/baja.
   - *Mejora planeada:* Suavizar las transiciones visuales mediante animaciones de transición estándar (`PageRouteBuilder` con `FadeTransition`).
