# Reporte de Auditoría Integral — Gestor de Gastos v20

**Fecha:** 13 de Mayo de 2026
**Auditor:** Staff Software Engineer / Tech Lead
**Alcance:** Base de código completa (`lib/`) — 40+ archivos Dart
**Esquema SQLite:** v20 (Wipe & Rebuild)

---

## 1. Arquitectura y Escalabilidad

### 1.1 Separación de Responsabilidades — ✅ Buena base, con fugas detectadas

La estructura de 4 capas (`core/`, `domain/`, `data/`, `presentation/`) es correcta y sigue Clean Architecture. Sin embargo, se detectaron **fugas de capa** (Layer Leaks):

| Hallazgo | Archivo | Severidad |
| :--- | :--- | :--- |
| `TransactionProvider` accede directamente a `sl<TransactionLocalDataSource>()` (Service Locator en capa de Presentación) en vez de pasar por UseCases/Repository. | `transaction_provider.dart:55, 75, 128, 211, 237` | 🟡 |
| `WalletProvider` recibe `TransactionLocalDataSource` como dependencia directa y lo usa para Goals, Subscriptions y preferencias. | `wallet_provider.dart:25, 158-162` | 🟡 |
| `StatsProvider` accede a `sl<TransactionLocalDataSource>()` directamente para obtener moneda y presupuesto. | `stats_provider.dart:90, 253-255` | 🟡 |
| `UiProvider` accede a `sl<TransactionLocalDataSource>()` directamente para tema, avatar, PIN, etc. | `ui_provider.dart:50, 80, 86, 93-94, 100, 106, 112` | 🟡 |

**Impacto:** No es un bug, pero dificulta testing (mocking) y viola la inversión de dependencias. Los Providers deberían recibir todas sus dependencias por constructor, nunca llamar a `sl<>()` internamente.

### 1.2 Principio de Responsabilidad Única — ⚠️ God Class detectada

| Clase | Responsabilidades actuales | Evaluación |
| :--- | :--- | :--- |
| `TransactionLocalDataSource` | Transacciones CRUD + Subscriptions CRUD + Goals CRUD + Preferencias de usuario (nombre, moneda, PIN, tema, avatar, imagen) + Migración de datos + Clear all | 🔴 **God Class** — 12+ responsabilidades |
| `TransactionRepositoryImpl` | Transacciones + Cuentas CRUD + Balance Breakdown + Monthly Expenses + Monthly Budget | 🟡 Excede contrato original |
| `WalletProvider` | Cuentas + Metas + Moneda + Presupuesto + Exchange Rates + Soft Delete + Depósitos + Compras | 🟡 Candidata a split |

**Recomendación prioritaria:**  Dividir `TransactionLocalDataSource` en:
- `TransactionDataSource` — Solo transacciones
- `FixedExpenseDataSource` — Subscriptions
- `GoalDataSource` — Metas
- `UserPreferencesDataSource` — Preferencias (nombre, tema, moneda, PIN, etc.)

### 1.3 Gestión de Estado — ✅ Correcto con mejoras posibles

- El uso de `ChangeNotifierProxyProvider` para sincronizar `StatsProvider` desde `TransactionProvider` es correcto.
- Los Providers están registrados como `LazySingleton` en GetIt, lo que significa que **sobreviven todo el ciclo de vida de la app**. Esto es aceptable para esta app, pero puede causar memory leaks si se acumulan listeners sin disponer.

---

## 2. Rendimiento y Optimización

### 2.1 Carga completa de transacciones en memoria

```
TransactionProvider.loadTransactions() → getTransactionsUseCase(NoParams())
```

Esto carga **TODAS** las transacciones desde SQLite a memoria cada vez que se llama. Con 10,000 transacciones, esto implica:
- ~10K objetos `TransactionEntity` en RAM permanentemente.
- Ordenamiento in-memory (`_transactions.sort((a, b) => b.date.compareTo(a.date))`) en cada recarga.

| Métrica estimada (10K txns) | Impacto |
| :--- | :--- |
| RAM | ~3-5 MB (objetos Dart) |
| Tiempo de sort | ~10-50ms (depende del dispositivo) |
| UI janks | Posible en dispositivos gama baja |

**Recomendación:** Implementar paginación SQL (`LIMIT/OFFSET`) para el historial y cargar solo transacciones del mes actual por defecto.

### 2.2 Verificación de suscripciones: O(N×M) en cada carga

```dart
// transaction_provider.dart:96-112
for (var tx in _transactions) {        // N transacciones
  for (var sub in _subscriptions) {    // M suscripciones (implícito por el loop externo)
```

Actualmente, `_checkSubscriptionStatuses()` itera sobre **todas** las transacciones por cada suscripción para determinar si fue pagada este ciclo. Con 10K transacciones y 15 suscripciones: **150,000 comparaciones**.

**Recomendación:** Realizar una consulta SQL específica:
```sql
SELECT DISTINCT description FROM transactions
WHERE type = 'EXPENSE' AND date >= ? AND date < ?
```
Y cruzar contra los nombres de suscripciones con un `Set<String>`.

### 2.3 Índices SQLite — ✅ Correctos, con mejora potencial

Índices existentes:
- `idx_transactions_date` — ✅
- `idx_transactions_accountId` — ✅

**Índices faltantes (recomendados para escala):**
```sql
CREATE INDEX idx_transactions_categoryId ON transactions(categoryId);
CREATE INDEX idx_transactions_type ON transactions(type);
```
Estos beneficiarían las consultas de estadísticas por categoría y los filtros por tipo.

### 2.4 Reconstrucciones de UI

Los archivos de página (`home_page.dart`: 36KB, `wallet_page.dart`: 35KB, `history_page.dart`: 43KB) son **widgets monolíticos** con métodos `build()` muy largos. Cada cambio en cualquier Provider reconstruye todo el árbol.

**Recomendación:**
- Extraer secciones a `StatelessWidget` / `StatefulWidget` separados.
- Usar `Selector<Provider, T>` en vez de `Consumer<Provider>` para escuchar solo campos específicos.
- Marcar widgets estáticos con `const` donde sea posible.

### 2.5 Bloqueo de Main Thread — ✅ No se detectaron problemas críticos

Todas las operaciones de SQLite son `async/await`. No se detectaron operaciones síncronas pesadas bloqueando el hilo principal. La lectura de PIN seguro es asíncrona correctamente.

---

## 3. Seguridad, Integridad y Resiliencia

### 3.1 Inyección SQL — ✅ Protegido

Todas las consultas SQL usan **parametrización correcta** con `?` placeholders:
```dart
await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
await db.rawQuery('... WHERE t.date >= ? AND t.date <= ?', [start, end]);
```
No se detectaron concatenaciones de strings en consultas SQL.

### 3.2 Integridad Referencial — ⚠️ Riesgo detectado

Las Foreign Keys están activadas con `PRAGMA foreign_keys = ON` y las tablas definen cascada correctamente. Sin embargo:

| Hallazgo | Riesgo | Severidad |
| :--- | :--- | :--- |
| `clearAllTables()` borra tablas en orden incorrecto: borra `accounts` antes de `transactions`, pero `transactions` tiene FK a `accounts` con `ON DELETE CASCADE`. Si las FK están ON, esto funciona por cascada, pero es frágil. | Bajo, funciona por cascada | 🟢 |
| `clearAllTables()` NO borra `categories`. Si se hace un Factory Reset y se vuelve a hacer seed, habrá **IDs duplicados** si `AUTOINCREMENT` sigue contando. | 🔴 Las categorías Core quedarían duplicadas | 🔴 |

**Fix crítico para `clearAllTables()`:**
```dart
Future<void> clearAllTables() async {
  final db = await database;
  await db.delete('transactions');
  await db.delete('fixed_expenses');
  await db.delete('goals');
  await db.delete('accounts');
  await db.delete('categories');       // ← FALTANTE
  await db.delete('sqlite_sequence');
}
```

### 3.3 Seguridad del PIN — ✅ Buena implementación

- El PIN se almacena en `FlutterSecureStorage` (Android Keystore / iOS Keychain).
- Existe migración automática de PIN texto plano (SharedPreferences → SecureStorage).
- La app se bloquea automáticamente al ir a background (`didChangeAppLifecycleState`).

**Observación menor:** La verificación de PIN en `UiProvider.verifyPin()` compara strings directamente (`_userPin == input`). En producción con datos sensibles, considerar hash + salt. Para un PIN de 4-6 dígitos en una app local, el riesgo es bajo.

### 3.4 Manejo de Errores — ⚠️ Mixto

| Patrón | Ubicación | Evaluación |
| :--- | :--- | :--- |
| `Either<Failure, T>` en Repository → UseCases | `transaction_repository_impl.dart` | ✅ Robusto |
| `result.fold((fail) => debugPrint(...), ...)` en Providers | Todos los providers | 🟡 El error se imprime en consola pero **nunca se muestra al usuario** |
| `try-catch` vacíos en migraciones | `database_helper.dart:49-54, 59-63...` | ✅ Aceptable para migraciones (ignora si la columna ya existe) |
| Sin `try-catch` en `addSubscription` | `transaction_provider.dart:211` | 🟡 Si falla el guardado SQLite, el usuario no se entera |
| Sin `try-catch` en `depositToGoal` | `wallet_provider.dart:296-327` | 🟡 |

**Recomendación:** Crear un sistema de notificación de errores al usuario:
```dart
// En el Provider, en caso de fallo:
result.fold(
  (fail) {
    _errorMessage = fail.message;
    notifyListeners();
  },
  (success) => ...,
);
```
Y consumirlo en la UI con un `SnackBar` o `Banner`.

### 3.5 API Key expuesta en URL — 🟡 Riesgo inherente

```dart
// gemini_client.dart:47
final uri = Uri.parse("$_urlOficial?key=$apiKey");
```

La API Key de Gemini viaja como query parameter en HTTP. Esto es el patrón estándar de Google APIs y no hay alternativa directa en client-side. El riesgo se mitiga con:
- `.env` en `.gitignore` ✅
- Cuota limitada de la API gratuita ✅

---

## 4. Calidad de Código y Deuda Técnica

### 4.1 Hardcoding de Valores — 🟡 Moderado

| Tipo | Ejemplo | Ubicación |
| :--- | :--- | :--- |
| **Colores hardcodeados** | `Color(0xFF1E2435)`, `Color(0xFF00E5FF)`, `Color(0xFF0F172A)` repetidos en docenas de archivos | `add_fixed_expense_sheet.dart`, `main.dart`, UI files |
| **Category IDs mágicos** | `categoryId: 8` (Transferencias), `categoryId: 14` (Regalos), `categoryId: 3` (Transporte) | `transaction_provider.dart:189`, `wallet_provider.dart:269,305` |
| **Account IDs mágicos** | `accountId: 3` hardcodeado como "Ahorros" | `wallet_provider.dart:336` |
| **Textos en español** | Strings de UI directamente en widgets | Todas las páginas |
| **Presupuesto default** | `2400.00` hardcodeado | `wallet_provider.dart:42`, `transaction_data_source.dart:238` |

**Recomendación prioritaria:** Crear constantes centralizadas:
```dart
// lib/core/constants/app_constants.dart
class AppConstants {
  static const int transferCategoryId = 8;
  static const int giftCategoryId = 14;
  static const double defaultBudget = 2400.00;
  static const String defaultCurrency = 'S/';
}

// lib/core/theme/app_colors.dart
class AppColors {
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkCard = Color(0xFF1E2435);
  static const Color accent = Color(0xFF00E5FF);
}
```

### 4.2 Balance Breakdown con lógica frágil — 🔴 Crítico

```dart
// transaction_repository_impl.dart:91-97
for (var account in accounts) {
  total += account.currentBalance;
  if (account.id == 1 || account.name.toLowerCase() == 'efectivo') {
    cash += account.currentBalance;
  } else if (account.id == 3 || account.name.toLowerCase() == 'ahorros') {
    savings += account.currentBalance;
  } else {
    digital += account.currentBalance;
  }
}
```

Este código asume que:
- `id == 1` siempre es "Efectivo"
- `id == 3` siempre es "Ahorros"
- Cualquier otra cuenta es "Digital"

**Problema:** Si el usuario elimina y recrea cuentas, los IDs cambian (AUTOINCREMENT). Además, la cuenta "Ahorros" no se crea en el seed v20 (solo se crea "Efectivo").

**Fix:** Usar el campo `type` de la tabla (`CASH` / `DIGITAL`) en lugar de IDs hardcodeados:
```dart
for (var account in accounts) {
  total += account.currentBalance;
  if (account.isCash) {
    cash += account.currentBalance;
  } else {
    digital += account.currentBalance;
  }
}
```

### 4.3 `purchaseGoal` con accountId hardcodeado — 🔴 Crash potencial

```dart
// wallet_provider.dart:335-342
final transaction = TransactionEntity(
  accountId: 3,    // ← HARDCODEADO. ¿Qué pasa si no existe la cuenta 3?
  categoryId: 3,   // ← HARDCODEADO. Transporte? Debería ser otra categoría.
  amount: -goal.targetAmount,
  ...
);
```

Si el usuario no tiene una cuenta con `id == 3`, esta transacción fallará silenciosamente (FK constraint) o se guardará con datos inválidos.

**Fix:** Recibir `accountId` como parámetro:
```dart
Future<void> purchaseGoal(String goalId, {required int accountId}) async {
  // ...
  final transaction = TransactionEntity(
    accountId: accountId,
    categoryId: 8,  // "Compras" en v20
    // ...
  );
}
```

### 4.4 `setBudgetLimit` no persiste — 🟡 Bug funcional

```dart
// wallet_provider.dart:221-225
void setBudgetLimit(double newLimit) {
  _budgetLimit = newLimit;
  notifyListeners();
  // In real app, persist this   ← ¡El comentario reconoce que falta!
}
```

El presupuesto se pierde al reiniciar la app.

**Fix:**
```dart
Future<void> setBudgetLimit(double newLimit) async {
  _budgetLimit = newLimit;
  notifyListeners();
  await localDataSource.saveBudgetLimit(newLimit);
}
```

### 4.5 `setCurrency` no persiste — 🟡 Bug funcional

```dart
// wallet_provider.dart:227-230
void setCurrency(String symbol) {
  _currencySymbol = symbol;
  notifyListeners();
  // ← No persiste
}
```

**Fix:**
```dart
Future<void> setCurrency(String symbol) async {
  _currencySymbol = symbol;
  notifyListeners();
  await localDataSource.saveCurrency(symbol);
}
```

### 4.6 Toggles no persistidos

```dart
// ui_provider.dart:119-127
void toggleBiometrics(bool value) {
  _enableBiometrics = value;
  notifyListeners();
  // ← No persiste
}

void toggleNotifications(bool value) {
  _enableNotifications = value;
  notifyListeners();
  // ← No persiste
}
```

Estas preferencias se pierden al reiniciar la app.

### 4.7 Convenciones de Código — ✅ Aceptable

- El linter (`flutter analyze`) pasa sin errores.
- Los nombres de archivos siguen snake_case.
- Las clases siguen PascalCase.
- Hay comentarios útiles en español (consistente con el dominio).

---

## 5. Matriz de Acción Priorizada

### 🔴 CRÍTICO — Resolver inmediatamente

| # | Problema | Archivo | Fix |
| :--- | :--- | :--- | :--- |
| C1 | `clearAllTables()` no borra `categories` → duplicados tras Factory Reset | `database_helper.dart:354-361` | Agregar `await db.delete('categories');` antes de `sqlite_sequence` |
| C2 | `purchaseGoal` usa `accountId: 3` hardcodeado → crash si no existe | `wallet_provider.dart:336` | Recibir `accountId` como parámetro obligatorio |
| C3 | `getBalanceBreakdown()` clasifica cuentas por ID mágico (1, 3) → datos incorrectos si los IDs cambian | `transaction_repository_impl.dart:91-97` | Usar `account.isCash` / `account.type` en vez de IDs |

### 🟡 MODERADO — Resolver a corto plazo

| # | Problema | Archivo |
| :--- | :--- | :--- |
| M1 | `setBudgetLimit()` no persiste el valor | `wallet_provider.dart:221` |
| M2 | `setCurrency()` no persiste el valor | `wallet_provider.dart:227` |
| M3 | `toggleBiometrics()` y `toggleNotifications()` no persisten | `ui_provider.dart:119-127` |
| M4 | Colores y IDs de categoría hardcodeados en toda la UI | Múltiples archivos |
| M5 | Errores de BD nunca se muestran al usuario (solo `debugPrint`) | Todos los providers |
| M6 | `_checkSubscriptionStatuses()` tiene complejidad O(N×M) | `transaction_provider.dart:81-124` |
| M7 | Providers acceden a `sl<>()` internamente (fuga de capa DI) | 4 providers |
| M8 | Widgets monolíticos de 30-43KB sin decomposición | `home_page.dart`, `wallet_page.dart`, `history_page.dart` |

### 🟢 MEJORA — Mantenibilidad y escalabilidad futura

| # | Problema | Archivo |
| :--- | :--- | :--- |
| G1 | `TransactionLocalDataSource` es una God Class (12+ responsabilidades) | `transaction_data_source.dart` |
| G2 | Sin paginación SQL (carga todas las transacciones en RAM) | `transaction_data_source.dart:84-91` |
| G3 | Faltan índices para `categoryId` y `type` en `transactions` | `database_helper.dart` |
| G4 | Internacionalización hardcodeada (strings en español directo) | Todas las páginas |
| G5 | `TransactionRepository` centraliza Transacciones + Cuentas (debería separarse) | `transaction_repository.dart` |
| G6 | `reorderSubscriptions()` y `reorderGoals()` no persisten el orden | `transaction_provider.dart:272`, `wallet_provider.dart:286` |
| G7 | Exchange rates hardcodeados como constante estática | `wallet_provider.dart:53-60` |

---

## 6. Fragmentos de Corrección — Issues Críticos

### C1: Fix `clearAllTables()`

```dart
// database_helper.dart
Future<void> clearAllTables() async {
  final db = await database;
  await db.delete('transactions');
  await db.delete('fixed_expenses');
  await db.delete('goals');
  await db.delete('accounts');
  await db.delete('categories');        // ← AGREGAR
  await db.delete('sqlite_sequence');
}
```

### C2: Fix `purchaseGoal()`

```dart
// wallet_provider.dart
Future<void> purchaseGoal(String goalId, {required int accountId}) async {
  final index = _goals.indexWhere((g) => g.id == goalId);
  if (index == -1) return;

  final goal = _goals[index];

  final transaction = TransactionEntity(
    accountId: accountId,          // ← Parámetro en vez de hardcoded
    categoryId: 8,                 // "Compras" en el seed v20
    amount: -goal.targetAmount,
    date: DateTime.now(),
    description: "Meta Cumplida: ${goal.name}",
    note: "Compra realizada con éxito 🏆",
    type: TransactionType.expense,
  );

  await addTransactionUseCase(AddTransactionParams(transaction: transaction));
  await loadWalletData();

  _goals.removeAt(index);
  notifyListeners();
  await localDataSource.deleteGoal(goalId);
}
```

### C3: Fix `getBalanceBreakdown()`

```dart
// transaction_repository_impl.dart
@override
Future<Either<Failure, BalanceBreakdown>> getBalanceBreakdown() async {
  try {
    final db = await localDatabase.database;
    final List<Map<String, dynamic>> accountsMap = await db.query('accounts');

    final accounts = accountsMap.map((e) {
      return AccountModel.fromJson(e)
          .copyWith(currentBalance: (e['balance'] as num).toDouble());
    }).toList();

    double total = 0, cash = 0, digital = 0;

    for (var account in accounts) {
      if (!account.includeInTotal) continue;  // ← Respetar flag
      total += account.currentBalance;
      if (account.isCash) {                    // ← Usar tipo, no ID
        cash += account.currentBalance;
      } else {
        digital += account.currentBalance;
      }
    }

    return Right(BalanceBreakdown(
      total: total,
      cash: cash,
      digital: digital,
      savings: 0,   // Eliminar concepto "savings" hardcodeado
    ));
  } catch (e) {
    return Left(DatabaseFailure(e.toString()));
  }
}
```

---

## 7. Veredicto General

| Dimensión | Nota | Comentario |
| :--- | :--- | :--- |
| **Arquitectura** | 7/10 | Clean Architecture bien implementada con fugas menores de DI |
| **Rendimiento** | 7/10 | Funcional para uso normal, necesita paginación para escalar |
| **Seguridad** | 8/10 | PIN seguro, SQL parametrizado, buenas prácticas |
| **Integridad de Datos** | 6/10 | 3 bugs críticos (clearAll, purchaseGoal, balanceBreakdown) |
| **Calidad de Código** | 7/10 | Consistente pero con hardcoding moderado |
| **Resiliencia** | 6/10 | Errores no se comunican al usuario |

**Puntuación Global: 6.8/10** — Funcional para producción inicial, pero requiere correcciones críticas (C1-C3) antes de release estable.
