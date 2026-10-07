# Checklist de Verificación Manual: Backup y Restore en Android (FASE 13A-09)

Este documento detalla el procedimiento de verificación manual en dispositivo físico o emulador Android para las integraciones de plataforma (FilePicker, ShareSheet y ciclo de seguridad) que no pueden ser automatizadas puramente en pruebas unitarias/FFI.

---

## 1. Prerrequisitos de la Prueba
1. Dispositivo físico o emulador Android con Android 10+ (API 29+).
2. Aplicación instalada en modo debug o release con datos iniciales (Estado A):
   - Al menos 2 cuentas con saldos positivos.
   - Categorías personalizadas o predeterminadas.
   - Transacciones de gasto, ingreso y transferencia con al menos un recibo (foto adjunta).
   - Metas financieras activas.
   - Suscripciones registradas y al menos un pago ejecutado.
   - Presupuesto mensual configurado.
   - **Seguridad:** PIN de 4 dígitos configurado ('1234') y Biometría habilitada (si el dispositivo la soporta).

---

## 2. Matriz de Ejecución y Checklist Manual

| # | Paso / Acción | Resultado Esperado | Resultado Observado | Estado (PASS/FAIL) |
|---|---|---|---|---|
| **01** | Ingresar a **Ajustes** y pulsar en el ListTile **"Crear copia de seguridad"**. | Se despliega el diálogo modal solicitando contraseña y confirmación de contraseña. El botón "Aceptar" permanece deshabilitado hasta que ambas contraseñas coincidan y no estén vacías. | | PENDING |
| **02** | Escribir contraseñas diferentes en el diálogo. | Se muestra mensaje de error "Las contraseñas no coinciden" y el botón "Aceptar" continúa inactivo. | | PENDING |
| **03** | Escribir contraseñas idénticas (ej. `BackupPass123!`) y pulsar **"Aceptar"**. | Aparece indicador de progreso. Tras completar el cifrado, se abre el **ShareSheet** nativo de Android ofreciendo aplicaciones (Drive, Gmail, Guardar en archivos, etc.) y se muestra SnackBar indicando éxito. | | PENDING |
| **04** | En el ShareSheet de Android, deslizar hacia abajo o pulsar atrás para **cancelar** sin guardar. | El ShareSheet se cierra sin bloquear ni crashear la aplicación. La app permanece reactiva y el archivo temporal no corrompe la sesión. | | PENDING |
| **05** | Repetir creación de backup y esta vez seleccionar **"Guardar en archivos"** o compartir a almacenamiento local. | El archivo `.gestorbackup` se guarda exitosamente en la carpeta seleccionada (ej. `Downloads/gestor_gastos_backup_...gestorbackup`). | | PENDING |
| **06** | Desde Ajustes, pulsar en el ListTile **"Restaurar copia de seguridad"**. | Se abre el **FilePicker nativo del sistema** filtrando por extensión `.gestorbackup`. | | PENDING |
| **07** | Pulsar "Atrás" o cancelar en el FilePicker nativo sin seleccionar ningún archivo. | El selector se cierra y la app regresa a Ajustes sin error, sin mostrar snackbars espurias y sin alterar la base de datos. | | PENDING |
| **08** | Volver a pulsar "Restaurar copia de seguridad" y seleccionar el archivo `.gestorbackup` generado en el paso 05. | Se despliega el diálogo solicitando la contraseña del archivo seleccionado. | | PENDING |
| **09** | Ingresar una **contraseña errónea** (ej. `WrongPass999`) y pulsar "Aceptar", luego confirmar advertencia destructiva. | La restauración falla. Se muestra SnackBar informando error al restaurar la copia. La base de datos actual y preferencias locales permanecen 100% intactas. | | PENDING |
| **10** | Repetir selección de archivo e introducir la **contraseña correcta** (`BackupPass123!`). | Se muestra el diálogo de **"Advertencia destructiva"** alertando que la acción sobrescribirá todos los datos y no se puede deshacer. | | PENDING |
| **11** | En la advertencia destructiva, pulsar **"Cancelar"**. | El diálogo se cierra. No se inicia ningún proceso de restauración y los datos actuales no se modifican. | | PENDING |
| **12** | Repetir proceso, ingresar contraseña correcta y en la advertencia destructiva pulsar **"Sí, restaurar"**. | Se muestra progreso. Tras completar, se muestra SnackBar "Copia restaurada exitosamente.", se recargan los providers y se navega fuera de la vista actual reiniciando la experiencia. | | PENDING |
| **13** | Verificar la integridad de los **datos financieros restaurados**. | Cuentas, balances, transacciones, recibos adjuntos, metas y suscripciones reflejan con exactitud el estado del backup. | | PENDING |
| **14** | Bloquear la pantalla del dispositivo o cerrar y volver a abrir la app. | Se solicita inmediatamente el PIN de seguridad o autenticación biométrica local. **El PIN local ('1234') sigue activo e inalterado** (no fue sobreescrito por el backup). | | PENDING |
| **15** | Comprobar ausencia de **fugas visuales de datos (frame financiero)** durante el arranque. | El SecurityGate mantiene la pantalla en negro/loading o LockScreen; en ningún momento se vislumbra el Dashboard financiero antes de autenticarse con éxito. | | PENDING |

---

## 3. Criterio de Aceptación Manual
- Todos los pasos del 01 al 15 deben ser evaluados con resultado **PASS**.
- En caso de presentarse algún comportamiento inesperado o excepción no controlada, documentar el stack trace y detener la validación.
