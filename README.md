# 💰 Gestor de Gastos: Cash vs Digital

> **Una aplicación móvil Offline-First diseñada para cerrar la brecha entre tus finanzas digitales y el dinero en efectivo que llevas en el bolsillo.**

---

## 📋 Descripción del Proyecto

A diferencia de las aplicaciones bancarias tradicionales que solo rastrean movimientos digitales, este **Gestor de Gastos** trata al **Efectivo (Cash)** como una cuenta de primera clase. 

El objetivo es ofrecer una visión realista de la salud financiera del usuario, funcionando 100% sin internet y proporcionando **feedback emocional** inmediato sobre los hábitos de gasto mediante una interfaz reactiva.

## ✨ Características Clave (MVP)

### 1. 💵 Gestión Dual (Cash vs. Digital)
Sistema de cuentas híbrido que permite al usuario diferenciar claramente:
* **Saldo Digital:** Cuentas bancarias, tarjetas, billeteras digitales.
* **Saldo Físico:** El dinero real en la billetera.

### 2. 😐 Feedback Emocional (Smart HUD)
La interfaz cambia su "estado de ánimo" basándose en tu salud financiera del mes:
* 🟢 **Feliz:** Gastos <= 80% del presupuesto.
* 🟡 **Neutral/Preocupado:** Gastos entre 80% y 100%.
* 🔴 **Triste/Alerta:** Gastos > 100% (Presupuesto excedido).

### 3. 🛡️ Privacidad y Seguridad (Offline First)
* **Cero Nube:** Todos los datos viven en el dispositivo del usuario usando una base de datos local robusta.
* **Bloqueo por PIN:** Capa de seguridad para acceder a la aplicación.

### 4. 📊 Análisis
* Gráficos de pastel por categorías.
* Diferenciación de gastos fijos (alquiler, servicios) vs. gastos variables.

---

## 🛠️ Stack Tecnológico

Este proyecto está construido con tecnologías modernas y escalables:

* **Framework:** [Flutter](https://flutter.dev/) (Dart)
* **Base de Datos:** SQLite (via `sqflite`)
* **Arquitectura:** Clean Architecture (Separación estricta de responsabilidades).
* **Gestión de Estado:** (Provider / Riverpod - *A definir en implementación*)
* **Entorno de Desarrollo:** Google Antigravity (VS Code Fork) con Asistencia de Agentes AI.

---

## 🏗️ Arquitectura del Proyecto

El código sigue los principios de **Clean Architecture** para asegurar escalabilidad y testabilidad:

```text
lib/
├── core/           # Utilidades, constantes y manejo de errores globales.
├── data/           # Implementación de Repositorios y Fuentes de Datos (SQLite).
├── domain/         # Lógica de Negocio Pura (Entities & UseCases).
└── presentation/   # UI (Widgets, Pages) y Gestión de Estado.