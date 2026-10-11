# Backup V1 — Documentación del Subsistema

Documentación técnica y de usuario del sistema de copias de seguridad cifradas de **Gestor de Gastos**.

---

## Índice

| Documento | Descripción |
|---|---|
| [01 — Visión General y Guía de Usuario](01_OVERVIEW_Y_GUIA_USUARIO.md) | Qué es el backup, cómo crear y restaurar copias, limitaciones y preguntas frecuentes. |
| [02 — Especificación Técnica](02_ESPECIFICACION_TECNICA.md) | Formato contenedor GGBK V1, criptografía, límites de tamaño y whitelist de preferencias. |
| [03 — Arquitectura y Recuperación](03_ARQUITECTURA_Y_RECUPERACION.md) | Pipeline de creación y restauración, snapshot SQLite, crash recovery y flujo de reinicio. |
| [04 — Políticas Android y Testing](04_POLITICAS_ANDROID_Y_TESTING.md) | Exclusión de Auto Backup, matriz de pruebas y escenarios pendientes. |

## Documentos Relacionados

| Documento | Ubicación |
|---|---|
| [Manual de Verificación Física](../manual_verification_backup_restore.md) | Resultados del smoke test en Galaxy A30s (Android 11). |
| [Herramienta de Inspección](../../tool/inspect_backup.dart) | Utilidad CLI para diagnóstico de archivos `.gestorbackup`. |

## Estado

- **Versión del formato:** GGBK V1
- **Versión del esquema SQLite:** 24
- **Rama de desarrollo:** `fix/stabilization-before-new-features`
- **Último commit de referencia:** `04af077`
