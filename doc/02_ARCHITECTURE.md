# Arquitectura Técnica de FinIA

## 1. Visión General de la Arquitectura
FinIA sigue una arquitectura modular inspirada en los principios de **Clean Architecture**, aunque pragmatizada para una aplicación rápida y eficiente en Flutter. Esta estructura garantiza una separación clara de responsabilidades, facilitando el prueba (testing) y el mantenimiento.

La aplicación consta de tres capas principales:

1.  **Capa Local (Core)**: Define las entidades de dominio y casos de uso básicos.
2.  **Capa Presentación (UI)**: Maneja la interfaz, el estado visual y la navegación.
3.  **Capa de Servicios y Datos:** Implementa la lógica de acceso a la base de datos (Data Source) y la comunicación con servicios externos (IA).

## 2. Estructura del Proyecto (Carpetas)
El código fuente se organiza de la siguiente manera:

*   **`lib/core/`**: Funcionalidades esenciales compartidas.
    *   `services/`: Clientes API (ej. `GeminiClient`, `AIService`), lógica de voz (`VoiceInputHelper`) y servicios generales (e.g., `SharedPreferencesService`).
    *   `utils/`: Funciones utilitarias (formatos de moneda, fechas, constantes).
    *   `widgets/`: Componentes UI reutilizables (Botones, Tarjetas).
*   **`lib/data/`**: Acceso a datos y modelos de persistencia.
    *   `datasources/`: Implementaciones concretas (ej. `TransactionLocalDataSource`, `AccountLocalDataSource`).
    *   `models/`: Objetos de transferencia de datos (DTOs) que mapean JSON/BD a entidades Dart.
    *   `database/` o `db/`: Helpers de SQLite (tablas, migraciones).
*   **`lib/domain/`**: Lógica de negocio pura.
    *   `entities/`: Objetos de negocio inmutables (ej. `TransactionEntity`, `AccountEntity`).
    *   `repositories/`: Contratos (interfaces) abstractos para el acceso a datos.
    *   `usecases/`: Casos de uso de la aplicación (ej. `AddTransactionUseCase`, `GetAccountBalanceUseCase`).
*   **`lib/presentation/`**: Capa visual.
    *   `pages/`: Pantallas principales (`MainPage`, `HomePage`, `StatsPage`, `AddTransactionPage`).
    *   `providers/`: Gestión de estado con `DashboardProvider` (Lógica de vista).
    *   `widgets/`: Widgets específicos de las pantallas.

## 3. Modelo de Datos (Esquema BD)
FinIA utiliza **SQLite** como motor de persistencia relacional local. Las tablas clave son:

### Diagrama ER Simplificado
`Accounts` (1) ----< `Transactions` (N) >---- (1) `Categories` (Lógico)

### Tablas Principales

#### `transactions`
Almacena el registro histórico de movimientos financieros.
| Campo | Tipo | Descripción |
| :--- | :--- | :--- |
| `id` | INTEGER PK | Identificador único auto-incremental. |
| `accountId` | INTEGER FK | Referencia a la cuenta de origen. |
| `categoryId` | INTEGER | Categoría del gasto/ingreso (1=Comida, 2=Transporte...). |
| `amount` | REAL | Monto de la transacción (Negativo para gasto). |
| `date` | TEXT | Fecha y hora ISO-8601. |
| `description` | TEXT | Título corto autogenerado o ingresado. |
| `note` | TEXT | Notas adicionales o transcripción de voz (raw). |
| `type` | TEXT | Tipo: 'expense', 'income', 'transfer'. |

#### `accounts`
Gestiona las fuentes de dinero del usuario.
| Campo | Tipo | Descripción |
| :--- | :--- | :--- |
| `id` | INTEGER PK | Identificador único. |
| `name` | TEXT | Nombre de la cuenta (ej. "BCP", "Efectivo"). |
| `type` | TEXT | Tipo de cuenta (banco, cash, digital). |
| `balance` | REAL | Saldo actual calculado. |
| `currency` | TEXT | Moneda base de la cuenta (default 'PEN'). |

#### `budgets` (Planificado V2)
Soporte futuro para presupuestos por categoría.

## 4. Patrones de Diseño Implementados

### Provider & State Management
Utilizamos el patrón **Provider** para la inyección de dependencias y la gestión del estado de la aplicación.
*   **`DashboardProvider`**: Actúa como el *ViewModel* principal. Orquesta la obtención de datos desde los Casos de Uso, gestiona el estado de carga (`_isLoading`), notifica a la UI (`notifyListeners()`) y mantiene la coherencia de los datos en memoria (`_transactions`, `_accounts`).

### Repository Pattern (Repositorio)
Desacopla la lógica de negocio (`UseCases`) de la implementación de datos (`DataSources`).
*   **Interfaz (`Domain`):** `TransactionRepository` define *qué* operaciones existen (ej. `addTransaction`).
*   **Implementación (`Data`):** `TransactionRepositoryImpl` define *cómo* se realizan (llamando a `TransactionLocalDataSource`).

### Service Locator (Inyección de Dependencias)
Aunque Provider maneja el estado UI, utilizamos un contenedor de servicios (posiblemente `get_it` o inyección manual en `main.dart`) para instanciar y proveer singletons como `AIService`, `DatabaseHelper` y los repositorios a los Providers.

### Clean Architecture (Simplificada)
El flujo de datos sigue un camino unidireccional estricto:
UI (`Page`) -> Provider (`State`) -> UseCase (`Domain`) -> Repository (`Data`) -> DataSource (`Local/Remote`) -> **Resultado**.

Esta separación permite cambiar la base de datos (e.g. a Hive o Realm) o el proveedor de IA sin afectar la interfaz de usuario ni la lógica de negocio core.
