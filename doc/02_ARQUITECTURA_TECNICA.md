# Arquitectura Técnica

## 1. Patrón de Diseño: Clean Architecture (Simplificada)
El proyecto utiliza una variante de **Clean Architecture** adaptada para la velocidad de desarrollo en Flutter. La estructura de directorios en `lib/` refleja una clara separación de responsabilidades:

1.  **Core (`lib/core/`)**: Lógica central agnóstica de la UI, como servicios de red (`ai_service.dart`) y manejo de errores.
2.  **Data (`lib/data/`)**: Implementación del acceso a datos. Contiene los `repositories`, `models` y `datasources` (`database_helper.dart`).
3.  **Presentation (`lib/presentation/`)**: Capa visual que interactúa con el usuario a través de `pages` y gestiona el estado mediante `providers`.
4.  **Domain (`lib/domain/`)**: Lógica pura de negocio (Entidades, Contratos de Repositorios). *Nota: Aunque no se observó explícitamente en el `ls` inicial, es común en este patrón y se infiere su existencia por los `import` en `main.dart`.*

## 2. Diagrama de Componentes (Mermaid)

El siguiente diagrama muestra cómo los componentes interactúan entre sí:

```mermaid
classDiagram
    direction LR
    
    %% Capa de Presentación
    class HomePage {
        +state: DashboardProvider
        +showAdminMode()
        +onVoiceInput()
    }
    
    class DashboardProvider {
        -List~TransactionEntity~ _transactions
        +addTransaction()
        +getAdvice()
        -notifyListeners()
    }
    
    %% Capa de Dominio/Data
    class TransactionRepositoryImpl {
        +addTransaction()
        +getTransactions()
    }
    
    %% Capa de Infraestructura
    class DatabaseHelper {
        +database: Database
        +insert()
        +query()
    }
    
    class AIService {
        -_apiKey: String
        +analyzeTransaction()
        +getFinancialAdvice()
    }

    %% Relaciones
    HomePage o-- DashboardProvider : Consume
    DashboardProvider --> TransactionRepositoryImpl : Llama a Repositorio
    DashboardProvider --> AIService : Solicita Análisis
    TransactionRepositoryImpl --> DatabaseHelper : Persiste en SQLite
    AIService --> GoogleGemini : HTTP Request (REST)
```

## 3. Manejo de Estado
La aplicación utiliza el paquete `provider` para gestionar el estado de manera reactiva.
*   **`DashboardProvider`**: Actúa como el *ViewModel* principal, centralizando la lógica de negocio y notificando a `HomePage` y `StatsPage` cuando hay cambios en el saldo o las transacciones.
*   **Inyección de Dependencias**: Se realiza a través de `provider` (o `get_it` si está configurado en `injection_container.dart`), permitiendo desacoplar la UI de la implementación concreta de los servicios.
