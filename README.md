# Proyecto SQL - Análisis de Ventas de Supermercado

Base de datos relacional para análisis de ventas de supermercado con datos de Kaggle.

## Archivos del Proyecto

01_schema.sql  → Crea la estructura de la base de datos
02_data.sql    → Carga los datos desde archivos CSV
03_eda.sql     → 15 consultas de análisis exploratorio

## Modelo de Datos:

1 Tabla de Hechos:
- fact_ventas

6 Tablas de Dimensiones:
- dim_productos → Catálogo de productos
- dim_categorias → 5 categorías (Bakery, Dairy, Meat, Produce, Snacks)
- dim_canales → 3 canales (Online, Outlet, Retail)
- dim_calendario → Fechas
- dim_clientes → Información de clientes
- dim_perdidas → Tasas de pérdida por producto

## 01_schema.sql - Estructura de la Base de Datos

Crea 7 tablas con:
- PRIMARY KEY y FOREIGN KEY
- Constraints: CHECK, UNIQUE, NOT NULL, DEFAULT
- Índices para optimizar consultas
- 1 vista: vista_ventas_completa
- 2 funciones: calcular_margen(), clasificar_venta()

## 02_data.sql - Carga de Datos

Carga datos desde CSV con:
- LOAD DATA LOCAL INFILE
- INSERT, UPDATE, DELETE
- CAST y TRIM para transformación
- Transacciones (START TRANSACTION, COMMIT, ROLLBACK)

## 03_eda.sql - Análisis Exploratorio (15 Consultas)

### 1. Ventas por Categoría
Ingresos totales, número de ventas y productos únicos por categoría.

### 2. Top 10 Productos Más Vendidos
Productos con mayor cantidad vendida y sus ingresos.

### 3. Ventas por Día de la Semana
Patrones de consumo: qué días se vende más.

### 4. Análisis de Canales
Compara rendimiento entre Online, Outlet y Retail.

### 5. Ventas Mensuales (CTE)
Tendencias mes a mes con crecimiento porcentual.

### 6. Ranking de Productos
Mejores productos por categoría y ranking general.

### 7. Productos Sin Ventas
Detecta productos sin movimiento en un periodo.

### 8. Análisis de Devoluciones
Productos con mayor tasa de retorno.

### 9. Productos con Mayor Pérdida
Identifica productos con merma elevada.

### 10. Clientes Top
Clientes con mayor gasto total.

### 11. Descuentos por Canal
Política de descuentos aplicada en cada canal.

### 12. Productos Más Rentables
Cálculo de margen bruto por producto.

### 13. Ventas por Trimestre
Detecta estacionalidad por categoría.

### 14. Vista Completa
Usa la vista predefinida para consulta integral.

### 15. Análisis Combinado (CTE Múltiple)
Análisis complejo con múltiples CTEs.

## Conceptos SQL Demostrados

- Agregaciones: COUNT, SUM, AVG, MIN, MAX, STDDEV
- Window Functions: RANK(), ROW_NUMBER(), LAG(), PARTITION BY
- JOINs: INNER, LEFT, CROSS
- CTEs: WITH...AS (simples y múltiples)
- Subconsultas: Correlacionadas, NOT EXISTS
- Funciones: COALESCE, CAST, DATE_FORMAT, CASE