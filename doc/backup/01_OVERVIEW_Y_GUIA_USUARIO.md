# 01 — Visión General y Guía de Usuario

## ¿Qué es el Backup de Gestor de Gastos?

El backup es una copia de seguridad cifrada de todos tus datos financieros: cuentas, movimientos, categorías, metas de ahorro, gastos fijos, recordatorios, preferencias e imágenes adjuntas.

Se genera como un archivo único con extensión `.gestorbackup` que puedes guardar donde desees: Google Drive, una carpeta local, un disco externo o cualquier servicio de almacenamiento.

### Características

- **Cifrado con contraseña.** Nadie puede leer tus datos sin la contraseña que elegiste al crearlo.
- **Portátil.** Es un archivo independiente que puedes mover, copiar o enviar.
- **Restauración completa.** Recupera todos tus datos en el mismo dispositivo o en uno nuevo.
- **Sin conexión a internet.** Todo el proceso ocurre en tu dispositivo.

---

## Crear una copia de seguridad

1. Abre **Ajustes** desde el menú principal.
2. Pulsa **"Crear copia de seguridad"**.
3. Escribe una contraseña y confírmala en el segundo campo.
   - El botón "Aceptar" permanece inactivo hasta que ambas contraseñas coincidan y no estén vacías.
4. Pulsa **"Aceptar"**.
   - Aparece un indicador de progreso mientras se prepara el archivo (puede tomar entre 5 y 20 segundos dependiendo del dispositivo).
5. Se abre el **panel para compartir** del sistema operativo.
6. Elige dónde guardar el archivo: Google Drive, Files, Bluetooth, etc.

### Recomendaciones

- Usa una contraseña que puedas recordar. **Si la olvidas, no hay forma de recuperar los datos.**
- Guarda el archivo en al menos dos ubicaciones diferentes (por ejemplo, Google Drive y una carpeta local).
- La aplicación no sube automáticamente el archivo a ningún servicio en la nube. Tú decides dónde guardarlo mediante el panel de compartir de Android.

---

## Restaurar una copia de seguridad

1. Abre **Ajustes** desde el menú principal.
2. Pulsa **"Restaurar copia de seguridad"**.
3. Se abre el **selector de archivos** del sistema, filtrado por la extensión `.gestorbackup`.
4. Selecciona el archivo que deseas restaurar.
5. Escribe la contraseña con la que fue creado y pulsa **"Aceptar"**.
6. Lee la **advertencia destructiva** y confirma pulsando **"Sí, restaurar"**.
   - Los botones se deshabilitan durante el proceso para evitar acciones duplicadas.
7. La aplicación se reinicia internamente y muestra los datos restaurados.

### ¿Qué datos se reemplazan?

La restauración **sobrescribe completamente** los siguientes datos:

| Componente | Acción |
|---|---|
| Base de datos SQLite | Se reemplaza íntegramente (cuentas, movimientos, categorías, metas, gastos fijos, recordatorios). |
| Preferencias de usuario | Se restauran las 7 claves portables incluidas en el backup (nombre, moneda, presupuesto, avatar, tema, tasas de cambio, zona horaria). Las preferencias no incluidas en el backup se conservan. |
| Imágenes adjuntas | Se copian los archivos de imagen referenciados por los movimientos del backup. |

### ¿Qué NO se modifica?

| Dato | Motivo |
|---|---|
| **PIN de seguridad** | Permanece el PIN configurado en el dispositivo actual. No se exporta ni importa. |
| **Biometría (huella dactilar)** | La configuración biométrica es del dispositivo, no de la aplicación. |
| **Permisos de notificaciones** | Son configuraciones del sistema operativo, no portables entre dispositivos. |
| **Estado de primer inicio** | No se exporta para evitar que la restauración interfiera con el flujo de bienvenida. |

---

## Si la contraseña es incorrecta

Se muestra un mensaje indicando que la contraseña es incorrecta o el archivo no es válido. Los datos actuales del dispositivo permanecen intactos.

Puedes intentar de nuevo las veces que necesites. No hay límite de intentos.

## Si la contraseña se olvidó

**No existe mecanismo de recuperación.** El archivo está cifrado con AES-256-GCM y la clave se deriva de tu contraseña. Sin ella, los datos son irrecuperables.

Crea copias de seguridad periódicas con una contraseña que puedas recordar.

## Si ocurre un error durante la restauración

La aplicación implementa un mecanismo de protección automático:

1. Antes de reemplazar la base de datos, se crea una copia de respaldo temporal (fallback).
2. Si el proceso falla a mitad de camino, al siguiente inicio la aplicación detecta el estado inconsistente y restaura automáticamente la copia anterior.
3. Tus datos previos se recuperan sin intervención manual.

Si el error persiste, verifica que el archivo `.gestorbackup` no esté corrupto o incompleto.

---

## Limitaciones actuales

| Limitación | Detalle |
|---|---|
| Tamaño máximo del contenido comprimido | 50 MiB |
| Tamaño máximo del contenedor cifrado | 52 MiB |
| Tamaño máximo por archivo individual | 100 MiB |
| Número máximo de archivos en el backup | 2 000 |
| Cifrado de la base de datos en reposo | No implementado (SQLCipher diferido). La base de datos se protege únicamente durante la exportación mediante el cifrado GGBK V1. |
| Backup incremental | No disponible. Cada backup es una copia completa. |
| Sincronización automática | No disponible. El archivo se comparte manualmente. |
| Progreso detallado | El indicador actual es un spinner indefinido. No muestra el avance por etapas. |

---

## Preguntas frecuentes

**¿Puedo restaurar un backup en un dispositivo diferente?**
Sí. El archivo `.gestorbackup` es portable. La única condición es que la versión de la aplicación en el dispositivo destino sea igual o superior a la que creó el backup.

**¿Se pierden datos al restaurar?**
Sí. La restauración reemplaza completamente la base de datos y las preferencias portables. Crea un backup de tus datos actuales antes de restaurar si deseas conservarlos.

**¿Google Drive guarda automáticamente mis datos?**
No. La aplicación excluye explícitamente todos sus datos del sistema de respaldo automático de Android. Solo el mecanismo GGBK V1, iniciado manualmente por el usuario, genera copias de seguridad.

**¿Qué extensión tiene el archivo?**
`.gestorbackup`. El nombre incluye un timestamp para identificar cuándo fue creado.
