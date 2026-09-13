# Plan de estabilización y correcciones previas a nuevas funcionalidades

**Proyecto:** Gestor de Gastos  
**Repositorio:** `Johntl121/Gestor-Gastos`  
**Rama revisada:** `main`  
**Fecha del análisis:** 2026-09-13  
**Objetivo de este documento:** servir como guía de ejecución para un agente de desarrollo antes de incorporar Recordatorios, un módulo de Presupuestos más completo, modificaciones a Metas de Ahorro y nuevos parámetros/validaciones en el registro de movimientos.

---

## 0. Contexto y decisiones ya tomadas

Este plan **NO busca reescribir la aplicación** ni copiar otra app. La intención es estabilizar el proyecto actual, conservar sus decisiones funcionales válidas y preparar una base segura para fusionar ideas nuevas.

### Decisiones del proyecto que deben respetarse

1. **La aplicación todavía está en desarrollo y no tiene usuarios reales.**
   - El `WIPE & REBUILD` histórico de la migración V20 se acepta temporalmente como decisión de desarrollo.
   - **NO modificar V20 solo para “salvar datos de usuarios” en esta etapa.**
   - A partir de la próxima migración que se cree para nuevas funcionalidades, las migraciones deben ser incrementales y no destructivas.

2. **La aplicación es multimoneda por decisión de producto.**
   - No reducir el sistema a PEN/USD.
   - Mantener las monedas ya soportadas y preparar la lógica para crecer.
   - El problema a corregir no es “tener muchas monedas”, sino asegurar que los cálculos entre monedas sean consistentes.

3. **El README no debe considerarse fuente absoluta de verdad.**
   - Está desactualizado en algunos puntos.
   - La prioridad de información debe ser:
     1. comportamiento real del código;
     2. documentación más reciente dentro de `/doc`;
     3. reglas del proyecto (`.agent_rules`);
     4. README como resumen general.

4. **No se debe volver a permitir editar directamente el saldo de una cuenta.**
   - Ya existió un bug donde modificar el dinero de una cuenta rompía cálculos y transacciones.
   - Este comportamiento debe quedar protegido también a nivel de dominio/repositorio, no solamente mediante UI.

5. **Las nuevas funcionalidades se implementarán después de esta estabilización.**
   - Recordatorios.
   - Presupuestos ampliados.
   - Evolución de Metas de Ahorro.
   - Nuevos parámetros y validaciones de movimientos.
   - No mezclar estas funcionalidades con las correcciones críticas descritas aquí.

---

# 1. Reglas de trabajo obligatorias para el agente

Estas reglas tienen como propósito evitar regresiones.

## 1.1. No realizar refactors masivos

No hacer en un mismo cambio:

- corrección contable;
- rediseño de Providers;
- migración de dinero;
- cambio visual;
- nueva funcionalidad.

Cada problema debe resolverse en cambios pequeños y verificables.

## 1.2. Un problema = un conjunto pequeño de commits

Ejemplo recomendado:

```text
fix: add accounting regression tests
fix: make transaction updates reversible
test: cover transfer edits and deletes
```

Evitar commits del tipo:

```text
refactor entire architecture
cleanup everything
improve database
```

porque dificultan localizar regresiones.

## 1.3. Antes de modificar código

El agente debe ejecutar primero:

```bash
flutter pub get
flutter analyze
flutter test
```

Si actualmente no existen pruebas suficientes, esto NO autoriza a modificar la lógica financiera directamente. Primero se deben crear pruebas de regresión mínimas.

También debe leer localmente:

```text
/README.md
/.agent_rules
/doc/*
```

La carpeta `/doc` del workspace debe revisarse antes de implementar cada fase. Si alguna regla reciente de `/doc` contradice este plan, el agente debe **detenerse y reportar la contradicción** en lugar de decidir unilateralmente.

## 1.4. No “arreglar” problemas que no estén demostrados

Si una observación de este documento ya fue corregida en la copia local:

- verificarla;
- marcarla como resuelta;
- no volver a tocarla innecesariamente.

El repositorio remoto puede estar algunos commits por detrás del workspace local.

## 1.5. Regla de oro contable

> **El saldo de una cuenta solo puede cambiar como consecuencia de una operación financiera explícita.**

No debe cambiar por:

- editar nombre de cuenta;
- cambiar icono;
- cambiar color;
- modificar preferencias visuales;
- reordenar elementos;
- editar metadatos.

Si en el futuro se necesita corregir manualmente un saldo, debe existir una operación explícita de **ajuste de saldo** que deje trazabilidad.

---

# 2. Invariantes que nunca deben romperse

El agente debe tratar las siguientes condiciones como contratos del sistema.

### INV-01 — Edición de cuenta

```text
editar_metadatos_cuenta
NO DEBE ALTERAR
saldo_actual
```

### INV-02 — Movimiento normal

Un ingreso o egreso debe afectar exactamente una cuenta y su efecto debe ser reversible.

### INV-03 — Transferencia

Una transferencia debe:

```text
restar del origen
+
sumar al destino
```

y una eliminación/reversión debe ejecutar exactamente lo contrario.

### INV-04 — Edición de movimiento

Editar un movimiento debe producir el mismo estado final que:

```text
revertir movimiento anterior
+
aplicar movimiento nuevo
```

### INV-05 — Atomicidad

Si una operación modifica más de una tabla o saldo, debe completarse completamente o no ejecutarse.

### INV-06 — Multimoneda

Nunca sumar valores monetarios de monedas distintas como si fueran la misma moneda.

### INV-07 — Metas

Un aporte, compra o reembolso de una meta no debe:

- crear dinero;
- duplicar dinero;
- perder dinero;
- actualizar solamente la meta dejando cuentas inconsistentes;
- actualizar solamente cuentas dejando la meta inconsistente.

### INV-08 — Categorías

Todo `categoryId` persistido debe existir en la tabla `categories`.

### INV-09 — Historial financiero

No usar `UPDATE accounts SET balance = ...` desde flujos de edición visual o configuración.

---

# 3. FASE 0 — Crear red de seguridad antes de tocar la lógica

**Prioridad: CRÍTICA**  
**Objetivo:** impedir que una corrección introduzca bugs financieros nuevos.

Actualmente las pruebas automatizadas son insuficientes para proteger operaciones contables. Antes de corregir lógica, crear pruebas enfocadas en invariantes, no en apariencia visual.

## 3.1. Crear una base de pruebas real

Crear una estructura similar a:

```text
test/
├── data/
│   └── repositories/
│       ├── transaction_repository_test.dart
│       ├── account_repository_test.dart
│       └── goal_finance_test.dart
├── domain/
│   └── money/
└── regression/
    └── financial_invariants_test.dart
```

No es obligatorio usar exactamente estos nombres; lo importante es la cobertura.

## 3.2. Casos mínimos de regresión

Antes de cualquier refactor, asegurar pruebas para:

### Cuentas

- crear cuenta con saldo inicial;
- editar nombre sin cambiar saldo;
- editar color sin cambiar saldo;
- editar icono sin cambiar saldo;
- cambiar `includeInTotal` sin cambiar saldo;
- confirmar que moneda y saldo no se alteran accidentalmente durante edición.

### Ingresos y egresos

- crear ingreso;
- crear egreso;
- eliminar ingreso;
- eliminar egreso;
- validar que eliminar revierte exactamente el efecto original.

### Transferencias

- crear transferencia;
- comprobar saldo origen;
- comprobar saldo destino;
- eliminar transferencia;
- validar reversión exacta;
- transferencia con `receivedAmount`.

### Edición

- cambiar monto de un egreso;
- cambiar monto de un ingreso;
- mover un movimiento de una cuenta a otra;
- cambiar ingreso → egreso;
- cambiar egreso → ingreso;
- editar transferencia;
- cambiar cuenta origen;
- cambiar cuenta destino;
- cambiar `receivedAmount`.

### Metas

- crear meta;
- aportar;
- comprar/completar;
- eliminar/reembolsar;
- comprobar que la suma de dinero antes/después no se inventa ni desaparece.

## 3.3. Smoke test manual inicial

Registrar el comportamiento actual antes de modificar:

1. crear cuenta;
2. registrar ingreso;
3. registrar egreso;
4. registrar transferencia;
5. editar cada uno;
6. eliminar cada uno;
7. crear meta;
8. aportar a meta;
9. completar meta;
10. revisar estadísticas;
11. cambiar moneda principal.

Guardar los resultados esperados en `/doc` o en un archivo de pruebas manuales.

### Criterio para avanzar

No continuar a FASE 1 si no existe al menos una prueba que detectaría una alteración incorrecta de saldos.

---

# 4. FASE 1 — Corregir edición de movimientos

**Prioridad: CRÍTICA**

Archivo principal observado:

```text
lib/data/repositories/transaction_repository_impl.dart
```

Actualmente la actualización calcula de forma aproximada:

```text
diff = newAmount - oldAmount
balance += diff
```

Esto no es suficiente cuando cambian:

- cuenta;
- tipo;
- origen/destino;
- transferencia;
- `receivedAmount`.

## 4.1. Comportamiento correcto

La actualización debe comportarse conceptualmente así:

```text
BEGIN SQL TRANSACTION

1. Leer movimiento anterior.
2. Revertir completamente sus efectos contables.
3. Validar movimiento nuevo.
4. Actualizar el registro.
5. Aplicar completamente los efectos del movimiento nuevo.

COMMIT
```

Si cualquier paso falla:

```text
ROLLBACK
```

## 4.2. Extraer helpers internos

Evitar duplicar reglas en `add`, `update` y `delete`.

Ejemplo conceptual:

```dart
Future<void> _applyFinancialEffect(
  DatabaseExecutor txn,
  TransactionModel transaction,
);

Future<void> _reverseFinancialEffect(
  DatabaseExecutor txn,
  TransactionModel transaction,
);
```

Los helpers deben conocer los tres casos actuales:

```text
INCOME
EXPENSE
TRANSFER
```

### Comentario para el agente

La razón de este cambio es evitar tener tres implementaciones diferentes de la misma regla contable. Si `add`, `update` y `delete` calculan saldos de manera distinta, tarde o temprano divergen.

## 4.3. Validaciones de transferencia

Antes de aplicar:

```text
sourceAccountId != destinationAccountId
destinationAccountId != null
amount > 0 en términos lógicos
receivedAmount > 0 si está definido
```

Respetar la convención actual del proyecto para signos, pero centralizarla.

## 4.4. No cambiar UI en esta fase

No rediseñar el formulario de movimientos.

Primero corregir la contabilidad.

### Criterio de aceptación

Todas las pruebas de FASE 0 deben pasar y:

```text
saldo_final_después_de_editar
==
saldo_esperado_si_se_hubiera_borrado_el_movimiento_antiguo_y_creado_el_nuevo
```

---

# 5. FASE 2 — Blindar el saldo de las cuentas

**Prioridad: CRÍTICA**

Archivos relevantes:

```text
lib/data/repositories/account_repository_impl.dart
lib/presentation/features/wallet/widgets/add_account_sheet.dart
```

La UI ya bloquea la edición directa del saldo y de la moneda al editar una cuenta. Eso es correcto y **debe conservarse**.

Sin embargo, el repositorio todavía actualiza:

```text
balance = account.currentBalance
```

durante `updateAccount()`.

## 5.1. Cambio recomendado

`updateAccount()` debe actualizar solo metadatos editables:

```text
name
type (solo si realmente es editable)
color
iconCode
includeInTotal
```

No debe escribir `balance`.

Tampoco modificar la moneda de una cuenta existente mientras el modelo actual dependa de la moneda de la cuenta para interpretar sus movimientos.

## 5.2. Antes de aplicar

Buscar todos los usos de:

```dart
updateAccount(...)
```

Si existe algún flujo que esté usando `updateAccount()` deliberadamente para cambiar saldo, no eliminar esa lógica silenciosamente.

Separarlo en una operación financiera explícita.

## 5.3. Ajuste futuro de saldo

Si se necesita:

```text
"Mi banco dice que tengo S/ 500, pero la app muestra S/ 490"
```

no habilitar el campo saldo.

Crear posteriormente:

```text
Ajuste de saldo
```

que genere una transacción trazable por la diferencia.

### Razón

Un saldo editable rompe el ledger porque la aplicación deja de poder explicar de dónde apareció o desapareció dinero.

### Criterio de aceptación

Editar una cuenta después de múltiples transacciones debe dejar el saldo exactamente igual.

---

# 6. FASE 3 — Corregir IDs de categorías y eliminar Magic IDs peligrosos

**Prioridad: ALTA**

Archivos observados:

```text
lib/core/constants/app_categories.dart
lib/core/constants/app_constants.dart
lib/presentation/features/dashboard/main_page.dart
lib/presentation/providers/wallet_provider.dart
```

La semilla actual contiene categorías:

```text
Gastos:   1..10
Ingresos: 11..15
```

Sin embargo, el procesamiento por voz conserva fallbacks históricos:

```text
20
25
```

Estos IDs ya no pertenecen al catálogo actual.

## 6.1. Corregir fallback de voz

Usar categorías válidas:

```text
Otros Gastos   = 10
Otros Ingresos = 15
```

No escribir los números directamente en `main_page.dart`.

## 6.2. Crear constantes semánticas

Ejemplo:

```dart
class SystemCategoryIds {
  static const int otherExpense = 10;
  static const int otherIncome = 15;
  static const int shopping = 8;
}
```

Preferible aún: obtenerlos de una fuente de verdad compartida con `AppCategories`.

## 6.3. Reembolso de metas

Actualmente un reembolso puede usar el ID `14`, que corresponde a `Regalos`.

Eso es semánticamente incorrecto.

Mientras no exista una categoría de sistema específica:

```text
usar Otros Ingresos (15)
```

o, si la contabilidad de metas se corrige como transferencia en la FASE 4, dejar de modelar el reembolso como ingreso.

## 6.4. Categoría de transferencias

Actualmente `transferCategoryId` coincide con `Compras`.

No cambiarla precipitadamente antes de corregir el flujo contable.

Después de FASE 1 y con tests verdes, evaluar una migración no destructiva que agregue una categoría interna de sistema para transferencias.

### Importante

No reutilizar una categoría visible de gasto únicamente para satisfacer una Foreign Key si luego esa categoría puede aparecer en reportes.

### Criterio de aceptación

Crear una prueba que recorra todas las constantes de categorías usadas por lógica interna y verifique que existen en el catálogo/BD.

---

# 7. FASE 4 — Corregir atomicidad y contabilidad de Metas

**Prioridad: ALTA / CRÍTICA cuando existe dinero real en una meta**

Archivos observados:

```text
lib/presentation/providers/wallet_provider.dart
lib/data/datasources/goal_local_data_source.dart
```

Actualmente Metas mezcla:

- transferencia financiera;
- saldo de cuenta;
- `Goal.currentAmount`;
- persistencia de meta;

en pasos separados.

Esto puede producir estados parciales.

## 7.1. Problema a evitar

Ejemplo:

```text
transferencia guardada ✅
saldo de cuentas actualizado ✅
guardar Goal.currentAmount ❌
```

Resultado:

```text
cuenta y meta ya no coinciden
```

## 7.2. Crear operaciones transaccionales de dominio

No ejecutar estos flujos directamente desde `WalletProvider`.

Crear casos de uso/repositorio para:

```text
DepositToGoal
CompleteGoal
RefundGoal
```

La implementación debe ejecutar dentro de **una sola transacción SQLite** las modificaciones relacionadas.

## 7.3. Caso especial: `goal.accountId == null`

Antes de transferir dinero a una meta:

```text
goal.accountId MUST NOT be null
```

Si actualmente existen metas sin cuenta:

- no inventar una cuenta destino;
- no usar la primera cuenta disponible;
- no aplicar la transferencia como movimiento normal;
- devolver un Failure comprensible.

### Razón

Una transferencia sin destino puede terminar aplicándose como una operación estándar y alterar incorrectamente el saldo de origen.

## 7.4. Reembolso de meta

Si los aportes a la meta realmente movieron dinero desde una cuenta origen hacia una cuenta de meta:

```text
reembolso = TRANSFERENCIA
```

desde la cuenta de la meta hacia la cuenta elegida.

No crear un `INCOME` nuevo, porque eso puede crear dinero contablemente.

## 7.5. Completar/comprar meta

No usar:

```text
primera cuenta disponible
```

como fallback silencioso.

Si la meta requiere cuenta asociada, debe validarse.

## 7.6. Mantener `currentAmount` temporalmente

No eliminar `Goal.currentAmount` todavía.

Aunque pueda considerarse información derivable, eliminarlo ahora sería un refactor grande.

Primero:

- mantenerlo sincronizado de forma atómica;
- cubrirlo con pruebas.

Más adelante se puede decidir si el saldo se deriva de un ledger de aportes.

### Criterio de aceptación

Para cada operación sobre una meta:

```text
dinero total antes
==
dinero total después
```

salvo cuando exista un gasto real de compra, donde la salida debe corresponder exactamente al gasto registrado.

---

# 8. FASE 5 — Corregir cálculos multimoneda sin reducir monedas

**Prioridad: ALTA**

La aplicación soporta múltiples monedas intencionalmente.

Actualmente las cuentas almacenan una moneda, pero las transacciones no poseen una moneda independiente. Mientras la moneda de una cuenta permanezca inmutable, una transacción puede interpretar su moneda a partir de su cuenta.

## 8.1. No añadir una migración agresiva todavía

Primero aprovechar:

```text
transaction.accountId
        ↓
account.currencySymbol
```

para identificar la moneda origen.

## 8.2. Centralizar catálogo de monedas

Evitar listas duplicadas en widgets.

Crear una entidad/configuración similar a:

```text
CurrencyDefinition
├── code       PEN / USD / EUR / JPY / RUB
├── symbol     S/ / $ / € / ¥ / ₽
├── minorUnits
└── displayName
```

El código ISO debe ser la identidad lógica; el símbolo es presentación.

## 8.3. Centralizar conversión

Crear un servicio puro:

```text
CurrencyConverter
```

que reciba:

```text
amount
sourceCurrency
targetCurrency
rates
```

y devuelva el valor convertido.

No realizar fórmulas de conversión diferentes en:

- Wallet;
- Stats;
- Coach;
- Dashboard.

## 8.4. Estadísticas

Antes de sumar:

```text
S/ 100 + $100
```

convertir cada movimiento a la moneda seleccionada.

Las transferencias deben excluirse de ingresos/egresos netos, salvo que una vista específica necesite mostrarlas.

## 8.5. Metas y gastos fijos

Toda visualización agregada debe respetar su moneda real.

No anteponer simplemente la moneda principal a un valor que fue calculado en otra moneda.

## 8.6. JPY y decimales

No asumir que todas las monedas visualmente usan dos decimales.

Preparar `minorUnits`, aunque la persistencia siga usando `double` temporalmente.

### Criterio de aceptación

Prueba obligatoria:

```text
Cuenta PEN: 100 PEN
Cuenta USD: 100 USD
```

con un tipo de cambio conocido.

El total en PEN y el total en USD deben coincidir matemáticamente con la conversión configurada.

---

# 9. FASE 6 — Precisión monetaria: mitigación segura antes de una migración completa

**Prioridad: MEDIA-ALTA**

Actualmente se utiliza `double` / `REAL`.

Migrar de golpe toda la app a enteros en unidades mínimas puede introducir muchos bugs y **NO debe hacerse durante las correcciones críticas**.

## 9.1. Primera medida conservadora

Crear utilidades centralizadas para:

- normalizar importes;
- redondear según moneda;
- comparar montos con tolerancia definida;
- formatear.

Ejemplo conceptual:

```text
MoneyRules.normalize(amount, currency)
MoneyRules.equals(a, b, currency)
MoneyFormatter.format(...)
```

## 9.2. No hacer todavía

No convertir todas las columnas `REAL` a `INTEGER` en la misma rama de estabilización.

## 9.3. Futuro

Antes de publicación real, evaluar una migración dedicada a:

```text
minor units / fixed point
```

con pruebas de migración y respaldo.

### Razón

La solución ideal no debe introducir más riesgo que el problema que intenta corregir.

---

# 10. FASE 7 — Notificaciones: preparar la base antes de Recordatorios

**Prioridad: ALTA antes de implementar Recordatorios**

Archivos observados:

```text
lib/core/services/notification_service.dart
lib/presentation/providers/ui_provider.dart
lib/presentation/providers/transaction_provider.dart
```

## 10.1. Respetar preferencia global

El switch:

```text
Notificaciones ON/OFF
```

debe controlar realmente el scheduling.

Comportamiento recomendado:

### OFF

- no programar nuevas notificaciones;
- cancelar notificaciones pendientes administradas por la app;
- mantener los datos de recordatorios/suscripciones en BD.

### ON

- solicitar permisos si son necesarios;
- reprogramar notificaciones activas.

## 10.2. Zona horaria

Actualmente inicializar la base de zonas horarias no garantiza que `tz.local` represente la zona real del dispositivo.

No hardcodear:

```text
America/Lima
```

porque la app puede utilizarse en otros países.

Resolver la zona horaria del dispositivo y configurar `tz.local`.

## 10.3. IDs estables

Cada recordatorio/suscripción debe tener un ID de notificación estable para poder:

```text
crear
editar
cancelar
reprogramar
```

sin duplicados.

## 10.4. No construir Recordatorios todavía

Primero dejar el servicio de notificaciones fiable. Después construir el módulo nuevo.

---

# 11. FASE 8 — Seguridad de Gemini sin romper la IA actual

**Prioridad: ALTA para producción; MEDIA durante desarrollo individual**

Archivo observado:

```text
lib/core/services/gemini_client.dart
pubspec.yaml
```

La API key está cargada desde `.env`, pero `.env` forma parte de los assets Flutter.

## 11.1. No eliminar `.env` inmediatamente

Quitar la key sin reemplazo rompería:

- Coach IA;
- transacciones por voz.

Por eso NO se debe hacer de forma brusca.

## 11.2. Medidas inmediatas de desarrollo

- confirmar que `.env` está ignorado por Git;
- crear/actualizar `.env.example` sin secretos;
- restringir la API key desde Google Cloud tanto como permita el proveedor;
- aplicar cuotas;
- no imprimir la key en logs;
- no incluirla en documentación.

## 11.3. Antes de distribución pública

Mover la llamada de Gemini a:

```text
Flutter
   ↓
Backend/Proxy propio
   ↓
Gemini
```

La key real debe vivir fuera del cliente.

## 11.4. Privacidad

El usuario debe saber que al utilizar IA se envía información financiera resumida/texto de voz a un servicio externo.

No es necesario rediseñar toda la privacidad ahora, pero esta condición debe quedar en el roadmap de publicación.

### Nota

Cambiar `.env` por `dart-define` no convierte mágicamente una key embebida en el cliente en un secreto seguro.

---

# 12. FASE 9 — Reducir acoplamiento arquitectónico de forma incremental

**Prioridad: MEDIA**

La estructura general intenta seguir Clean Architecture, pero algunos Providers conocen directamente:

```text
DataSources
SharedPreferences
Models de Data
```

No realizar una reescritura completa.

## 12.1. Regla para código nuevo

A partir de este punto:

```text
Presentation
    ↓
UseCase
    ↓
Repository interface (Domain)
    ↓
Repository implementation (Data)
    ↓
DataSource
```

Las nuevas funcionalidades de:

```text
Recordatorios
Presupuestos
Metas
```

deben respetar esta dirección desde su creación.

## 12.2. Providers especializados

No seguir agregando responsabilidades a `WalletProvider`.

Evolución recomendada:

```text
WalletProvider      → cuentas y resumen de patrimonio
GoalProvider        → metas
BudgetProvider      → presupuestos
ReminderProvider    → recordatorios
TransactionProvider → movimientos
StatsProvider       → agregaciones/estadísticas
```

No es necesario dividirlos todos en un solo commit.

## 12.3. Migración gradual

Cuando se toque un flujo existente por una corrección:

- mover solo ese flujo a UseCase/Repository;
- dejar el resto intacto.

### Razón

Un refactor total de arquitectura antes de nuevas funcionalidades puede crear más regresiones que beneficios.

---

# 13. FASE 10 — Reducir archivos gigantes solo cuando se toquen

**Prioridad: MEDIA-BAJA**

Se observaron archivos de UI muy grandes, por ejemplo:

```text
main_page.dart
settings_page.dart
add_account_sheet.dart
```

Esto contradice la intención de `.agent_rules` de utilizar widgets pequeños.

## 13.1. No dividir por dividir

No hacer una campaña masiva para que todos los archivos tengan menos de X líneas.

Al trabajar en una pantalla:

- extraer widgets autocontenidos;
- extraer lógica de formularios;
- extraer servicios;
- mantener comportamiento idéntico.

## 13.2. Prioridad

Primero:

```text
correctitud financiera
```

después:

```text
tamaño de archivos
```

---

# 14. FASE 11 — Relación de suscripciones y pagos

**Prioridad: MEDIA**

Si el estado “pagado” de una suscripción se determina mediante coincidencia de texto/descripción, la relación es frágil.

## 14.1. Solución futura recomendada

Agregar una relación explícita:

```text
transaction.subscriptionId
```

o una entidad:

```text
SubscriptionPayment
├── subscriptionId
├── transactionId
├── period
└── paidAt
```

## 14.2. No mezclar con Recordatorios

Recordatorio y suscripción son conceptos diferentes:

```text
Suscripción = obligación recurrente
Recordatorio = aviso programado
```

Una suscripción puede generar un recordatorio, pero no deben ser la misma entidad.

---

# 15. FASE 12 — PIN y protección contra intentos repetidos

**Prioridad: MEDIA-BAJA**

El PIN está almacenado mediante almacenamiento seguro, lo cual debe conservarse.

Agregar protección local:

```text
5 intentos fallidos
→ bloqueo corto

más intentos
→ bloqueo progresivo
```

No bloquear permanentemente la aplicación.

Guardar únicamente la información mínima necesaria para el cooldown.

La biometría actualmente simulada no debe presentarse como seguridad real en una versión pública hasta integrar autenticación biométrica verdadera.

---

# 16. FASE 13 — Cifrado local y backups

**Prioridad: BAJA en la etapa actual / ALTA antes de un producto sensible en producción**

No cambiar SQLite ahora si la app continúa como proyecto en desarrollo.

Antes de publicación real evaluar:

- cifrado de base de datos;
- política de backups;
- tratamiento de imágenes/comprobantes;
- almacenamiento de archivos sensibles.

No introducir SQLCipher u otra tecnología durante la estabilización contable salvo que exista un requisito real inmediato.

---

# 17. FASE 14 — README y documentación

**Prioridad: BAJA**

Actualizar el README después de:

- estabilizar contabilidad;
- definir la nueva arquitectura de funcionalidades;
- implementar Recordatorios/Presupuestos/Metas.

No perder tiempo corrigiendo cada afirmación del README mientras el producto sigue cambiando.

## 17.1. Documentación que sí debe mantenerse durante el proceso

Actualizar `/doc` cuando cambie:

- una regla contable;
- una entidad;
- una relación;
- una migración;
- un requisito funcional.

Especialmente documentar los invariantes de este plan.

---

# 18. Tratamiento específico de la migración V20

## Decisión actual

**NO es una corrección prioritaria.**

La V20 puede permanecer como migración destructiva histórica mientras:

- no existan usuarios reales;
- siga siendo una etapa de desarrollo;
- el equipo acepte resetear datos de prueba.

## Regla a partir de ahora

No crear:

```text
V23 / V24 / ...
```

con `DROP TABLE` general para resolver problemas normales.

Las futuras migraciones deben ser:

```text
append-only cuando sea posible
ALTER TABLE
CREATE TABLE
CREATE INDEX
INSERT de datos de sistema
UPDATE controlado
```

Si una migración realmente necesita transformar datos:

1. hacerla dentro de una transacción;
2. agregar test desde versión anterior;
3. validar conteos antes/después.

### Antes de beta/publicación

Revisar todo el camino de migración que se quiera soportar.

---

# 19. Orden exacto recomendado de ejecución

## BLOQUE A — No negociable

### P0-01
Crear pruebas de regresión contable.

### P0-02
Ejecutar `flutter analyze` y corregir únicamente errores reales de compilación/imports.

> Si imports relativos como los de `settings_page.dart` ya están corregidos en local, no tocarlos.

### P0-03
Corregir `updateTransaction()` mediante reversión + aplicación atómica.

### P0-04
Blindar `updateAccount()` para que una edición de metadatos no pueda modificar saldo.

### P0-05
Corregir categorías inexistentes del flujo de voz (`20/25`) y centralizar IDs críticos.

### P0-06
Bloquear operaciones de Meta que no tengan una cuenta destino válida y corregir flujos capaces de crear/duplicar dinero.

---

## BLOQUE B — Alta prioridad antes de funcionalidades nuevas

### P1-01
Hacer atómicas las operaciones financieras de Metas.

### P1-02
Centralizar lógica multimoneda y corregir estadísticas agregadas.

### P1-03
Alinear preferencias de notificaciones con el servicio real.

### P1-04
Configurar correctamente timezone del dispositivo.

---

## BLOQUE C — Mejora estructural incremental

### P2-01
Crear repositorios/casos de uso de Meta donde todavía se accede directamente a Data.

### P2-02
Evitar DataSources directos en nuevos Providers.

### P2-03
Preparar `GoalProvider`, `BudgetProvider` y `ReminderProvider` al implementar esas funcionalidades.

### P2-04
Extraer widgets/lógica solamente de pantallas que se estén modificando.

---

## BLOQUE D — Seguridad y producción

### P3-01
Preparar backend/proxy para Gemini antes de distribución pública.

### P3-02
Agregar rate limit al PIN.

### P3-03
Revisar cifrado/backup local según alcance real del producto.

### P3-04
Evaluar migración futura desde `double` a representación monetaria fija.

---

# 20. Checklist obligatorio después de cada fase

Después de cada fase:

```bash
dart format .
flutter analyze
flutter test
```

Además ejecutar smoke tests manuales:

- Home carga.
- Wallet carga.
- Accounts cargan.
- Crear cuenta.
- Editar cuenta sin alterar saldo.
- Registrar ingreso.
- Registrar egreso.
- Transferir.
- Editar movimiento.
- Eliminar movimiento.
- Historial correcto.
- Estadísticas correctas.
- Crear/meta/aportar si la fase toca metas.
- App reinicia y persiste datos.

No pasar a la siguiente fase si:

```text
flutter analyze
```

introduce errores nuevos o una prueba de regresión falla.

---

# 21. Política de rollback

Cada fase debe poder revertirse independientemente.

Antes de una modificación sensible:

```bash
git status
git add .
git commit -m "test: baseline before accounting fix"
```

Trabajar preferentemente en una rama:

```text
fix/stabilization-before-new-features
```

No usar comandos destructivos sobre trabajo no committeado.

Si un cambio contable no puede demostrarse correcto con pruebas:

```text
REVERTIR
```

en lugar de intentar “parchar encima”.

---

# 22. Qué NO debe hacer el agente

- No eliminar V20 solamente porque es destructiva.
- No reducir las monedas a PEN/USD.
- No permitir editar saldo directamente.
- No cambiar simultáneamente esquema, UI, providers y reglas financieras.
- No borrar `currentAmount` de metas todavía.
- No migrar todo a centavos en esta primera estabilización.
- No quitar Gemini sin reemplazo.
- No crear un backend completo sin que se haya aprobado ese alcance.
- No inventar reglas de negocio faltantes.
- No usar la primera cuenta encontrada como fallback silencioso para operaciones financieras.
- No usar IDs de categorías “porque funcionan”.
- No alterar datos financieros para resolver problemas visuales.
- No convertir un movimiento existente a otro tipo sin revertir antes su efecto anterior.
- No agregar Recordatorios/Presupuestos nuevos hasta finalizar como mínimo el BLOQUE A.

---

# 23. Preparación para las funcionalidades nuevas

Cuando el BLOQUE A y el BLOQUE B estén estables, recién empezar las nuevas funciones.

## Recordatorios

Crear módulo independiente:

```text
domain/entities/reminder_entity.dart
domain/repositories/reminder_repository.dart
domain/usecases/
data/models/reminder_model.dart
data/repositories/reminder_repository_impl.dart
data/datasources/reminder_local_data_source.dart
presentation/providers/reminder_provider.dart
presentation/features/reminders/
```

Debe reutilizar el `NotificationService`, no duplicar scheduling.

## Presupuestos

No seguir guardando toda la lógica del presupuesto dentro de preferencias si el nuevo modelo tendrá:

- presupuesto mensual;
- asignación por categorías;
- alertas;
- historial por mes.

Probablemente requerirá entidades/tablas propias.

## Metas

Antes de implementar las ideas nuevas, decidir formalmente:

```text
¿una meta representa una cuenta real?
o
¿una meta es una asignación lógica del ahorro?
```

No mantener ambos modelos mezclados.

## Registro de movimientos

Agregar nuevos parámetros únicamente después de definir:

- qué campos son del movimiento;
- qué campos son de la cuenta;
- qué campos son de categoría;
- qué campos afectan presupuestos/metas.

Las validaciones deben vivir en dominio/casos de uso, no exclusivamente en la pantalla.

---

# 24. Definition of Done de la estabilización

La base se considera preparada para nuevas funcionalidades cuando:

- [ ] `flutter analyze` no presenta errores nuevos.
- [ ] Existe suite de pruebas contables.
- [ ] Editar una transacción no corrompe saldos.
- [ ] Cambiar de cuenta/tipo al editar funciona correctamente.
- [ ] Transferencias son reversibles.
- [ ] Editar una cuenta no modifica saldo.
- [ ] No existen fallbacks a categorías inexistentes.
- [ ] Los flujos principales de metas son atómicos o están explícitamente bloqueados cuando no pueden garantizar consistencia.
- [ ] Las estadísticas multimoneda convierten antes de agregar.
- [ ] Las monedas existentes continúan funcionando.
- [ ] Las notificaciones respetan la preferencia del usuario.
- [ ] El timezone se maneja según el dispositivo.
- [ ] No se introdujeron regresiones visibles en Home, Wallet, Historial o Stats.
- [ ] La documentación técnica refleja las nuevas reglas contables.

---

# 25. Principio final para el agente

> **En una aplicación financiera, primero se protege la consistencia del dinero y después se optimiza la arquitectura o se añaden funcionalidades.**

Si existe una elección entre:

```text
hacer un refactor más elegante
```

y:

```text
mantener una operación financiera demostrablemente correcta
```

priorizar siempre la segunda.

Las nuevas funcionalidades deben integrarse sobre esta base, no reemplazarla ni romper los flujos actuales.
