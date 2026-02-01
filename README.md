# Proyecto: Gestor de Gastos "Cash vs Digital"

## 1. Visión del Producto
Aplicación móvil de gestión financiera personal (y futura familiar) enfocada en cerrar la brecha de información entre el dinero digital (bancos) y el dinero en efectivo. La app debe funcionar 100% Offline, ser extremadamente rápida y proporcionar feedback emocional visual sobre el estado de las finanzas.

## 2. Diferencial Clave
A diferencia de las apps bancarias, esta aplicación trata al "Efectivo" como una cuenta de primera clase, permitiendo al usuario saber exactamente cuánto dinero físico debería tener en la billetera vs. sus cuentas digitales.

## 3. Funcionalidades Core (MVP)
* **Offline First:** Persistencia local de datos (SQLite). Sin dependencia de internet.
* **Gestión Dual:** Clasificación explícita de cuentas en tipos: `EFECTIVO` y `DIGITAL`.
* **Feedback Emocional (HUD):**
    * Indicador visual animado (Carita) basado en el cumplimiento del presupuesto.
    * *Lógica:* * <= 80% gastado: Feliz.
        * 80% - 100% gastado: Preocupada/Neutral.
        * > 100% gastado: Triste/Alerta.
* **Gastos Recurrentes:** Capacidad de marcar gastos como fijos (alquiler, servicios).
* **Seguridad:** Bloqueo de acceso mediante PIN local.
* **Moneda:** Inicialmente solo Soles (PEN).

## 4. Stack Tecnológico
* **Framework:** Flutter (Dart).
* **Arquitectura:** Clean Architecture (Presentation, Domain, Data).
* **Base de Datos Local:** sqflite.
* **Gestión de Estado:** Provider o Riverpod (a definir por el agente de arquitectura).