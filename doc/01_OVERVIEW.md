# Visión General del Proyecto: Gestor de Gastos

## 1. Introducción
**Gestor de Gastos** es una aplicación móvil nativa diseñada para transformar la gestión de gastos personales en Perú. A diferencia de las apps tradicionales, esta aplicación integra un **Coach Financiero** impulsado por Google Gemini que ofrece análisis proactivos, consejos empáticos y categorización inteligente.

La aplicación opera bajo una filosofía **Local-First**: los datos financieros viven en el dispositivo del usuario (SQLite), garantizando privacidad y velocidad, conectándose a la nube solo para procesar consultas de IA.

## 2. Características Principales

### Registro Multimodal
*   **Voz Inteligente:** Reconocimiento de lenguaje natural que detecta **Tipo** (Gasto/Ingreso/Transferencia), **Monto** (S/), **Categoría** y **Cuenta** (ej. "Yape", "BCP") en una sola frase.
*   **Manual:** Interfaz optimizada para registros rápidos.

### Coach Financiero (Gemini AI)
*   **Análisis Semanal y Mensual** de patrones de gasto.
*   **Localización total** a moneda peruana (Nuevos Soles S/).
*   Sistema de **"Bienvenida Local"** para ahorrar consumo de API en usuarios nuevos.

### Gestión de Cuentas Dinámica
*   Soporte para efectivo, bancos y billeteras digitales personalizables.

## 3. Roadmap: Hacia la Play Store (El Futuro del Coach)
Para el despliegue en producción (Google Play Store), **Gestor de Gastos** tiene una hoja de ruta técnica clara:

### A. Estrategia de Costos y Cuotas
*   **Fase Actual (Beta):** Uso del *Free Tier* de Gemini (modelos Flash 1.5/2.5) que permite hasta 1,500 peticiones diarias gratuitas. Ideal para <100 usuarios activos.
*   **Fase Producción (Escalado):** Migración al modelo *Pay-as-you-go*. Dado el bajo costo de los modelos Flash (~$0.075 por millón de tokens de entrada), se estima que mantener a 1,000 usuarios activos costaría menos de $5 USD/mes.

### B. Seguridad de la API (Backend Proxy)
*   **Actualmente:** La `API_KEY` reside en el cliente (segura mediante ofuscación en Android).
*   **Futuro:** Para máxima seguridad, las peticiones al Coach pasarán a través de **Firebase Cloud Functions** o **Vertex AI**. Esto ocultará la llave API real del lado del cliente y permitirá implementar límites de uso por usuario (*Rate Limiting*) para evitar abusos.

### C. Memoria a Largo Plazo
*   Se implementará un sistema de **Resumen Incremental**: en lugar de enviar todo el historial de transacciones cada vez, el Coach guardará un "perfil financiero" comprimido del usuario que se actualiza mes a mes, reduciendo costos y mejorando la precisión.
