
USE supermarket_sales;

-- ============================================================================
-- 1. PREPARACIÓN: CREAR TABLAS TEMPORALES
-- ============================================================================
-- Las tablas temporales sirven como área de staging para:
-- 1. Cargar datos crudos desde CSV sin validación inicial
-- 2. Limpiar y transformar datos antes de insertarlos en tablas finales
-- 3. Evitar insertar datos incorrectos directamente en el modelo dimensional

DROP TABLE IF EXISTS temp_products;
DROP TABLE IF EXISTS temp_sales;
DROP TABLE IF EXISTS temp_prices;
DROP TABLE IF EXISTS temp_losses;

CREATE TABLE temp_products (
    id INT AUTO_INCREMENT PRIMARY KEY,  -- PK permite UPDATE con safe mode activado
    item_code BIGINT,                   -- Código de producto del CSV (sin validar)
    item_name VARCHAR(200),             -- Nombre del producto
    category_code VARCHAR(50),          -- Código de categoría
    category_name VARCHAR(200)          -- Nombre de categoría
    -- Todas las columnas VARCHAR para aceptar cualquier dato del CSV
);

CREATE TABLE temp_sales (
    id INT AUTO_INCREMENT PRIMARY KEY,  -- PK permite UPDATE con safe mode activado
    sale_date VARCHAR(20),              -- Fecha como texto, se convierte a DATE después
    sale_time VARCHAR(20),              -- Hora como texto, se convierte a TIME después
    item_code BIGINT,                   -- Código del producto vendido
    quantity_sold VARCHAR(20),          -- Cantidad como texto, se convierte a DECIMAL
    unit_price VARCHAR(20),             -- Precio como texto, se convierte a DECIMAL
    sale_or_return VARCHAR(20),         -- 'sale' o 'return', se convierte a BOOLEAN
    discount VARCHAR(20)                -- 'Yes' o 'No', se convierte a BOOLEAN
    -- VARCHAR permite cargar datos con espacios o formatos inconsistentes
);

CREATE TABLE temp_prices (
    id INT AUTO_INCREMENT PRIMARY KEY,  -- PK permite UPDATE con safe mode activado
    price_date VARCHAR(20),             -- Fecha del precio, se convierte a DATE
    item_code BIGINT,                   -- Código del producto
    wholesale_price VARCHAR(20)         -- Precio mayorista, se convierte a DECIMAL
);

CREATE TABLE temp_losses (
    id INT AUTO_INCREMENT PRIMARY KEY,  -- PK permite UPDATE con safe mode activado
    item_code BIGINT,                   -- Código del producto
    item_name VARCHAR(200),             -- Nombre del producto
    loss_rate VARCHAR(20)               -- Tasa de pérdida, se convierte a DECIMAL
);

-- ============================================================================
-- 2. CARGA MASIVA DESDE CSVs USANDO LOAD DATA LOCAL INFILE
-- ============================================================================
-- LOAD DATA LOCAL INFILE es el método más rápido para cargar archivos grandes
-- Alternativas descartadas:
-- - Table Data Import Wizard: muy lento (solo 2,350 registros en varios minutos)
-- - INSERT individuales con Python: genera archivo SQL gigante
-- Requiere: OPT_LOCAL_INFILE=1 en conexión y SET GLOBAL local_infile=1 en servidor

-- Muestra que local infile esta activado.
SHOW VARIABLES LIKE 'local_infile';

-- IMPORTANTE: Modifica las rutas según tu sistema operativo y ubicación del proyecto
-- Formato Windows: 'C:/ruta/al/proyecto/archivo.csv'
-- Formato Linux/Mac: '/ruta/al/proyecto/archivo.csv'

-- ----------------------------------------------------------------------------
-- 2.1 Cargar productos
-- ----------------------------------------------------------------------------
-- MODIFICAR ESTA RUTA según dónde descargaste el proyecto
LOAD DATA LOCAL INFILE 'D:/DataScience/Proyecto-2-SQL/products.csv'
INTO TABLE temp_products
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(item_code, item_name, category_code, category_name);

-- ----------------------------------------------------------------------------
-- 2.2 Cargar ventas
-- ----------------------------------------------------------------------------
-- MODIFICAR ESTA RUTA según dónde descargaste el proyecto
LOAD DATA LOCAL INFILE 'D:/DataScience/Proyecto-2-SQL/sales.csv'
INTO TABLE temp_sales
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(sale_date, sale_time, item_code, quantity_sold, unit_price, sale_or_return, discount);

-- ----------------------------------------------------------------------------
-- 2.3 Cargar precios mayoristas
-- ----------------------------------------------------------------------------
-- MODIFICAR ESTA RUTA según dónde descargaste el proyecto
LOAD DATA LOCAL INFILE 'D:/DataScience/Proyecto-2-SQL/bulk_prices.csv'
INTO TABLE temp_prices
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(price_date, item_code, wholesale_price);

-- ----------------------------------------------------------------------------
-- 2.4 Cargar tasas de pérdida
-- ----------------------------------------------------------------------------
-- MODIFICAR ESTA RUTA según dónde descargaste el proyecto
LOAD DATA LOCAL INFILE 'D:/DataScience/Proyecto-2-SQL/product_loss_rate.csv'
INTO TABLE temp_losses
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(item_code, item_name, loss_rate);

-- ============================================================================
-- 3. LIMPIEZA Y TRANSFORMACIÓN DE DATOS
-- ============================================================================
-- TRIM elimina espacios en blanco al inicio/final que causan errores en CAST
-- Ejemplo: CAST(" 15.50 " AS DECIMAL) falla, pero CAST("15.50" AS DECIMAL) funciona
-- WHERE id > 0 usa la PRIMARY KEY para cumplir con SQL_SAFE_UPDATES sin desactivarlo

-- Limpiar espacios en blanco usando la PK para cumplir con safe mode
UPDATE temp_products
SET category_code = TRIM(category_code),
    category_name = TRIM(category_name),
    item_name = TRIM(item_name)
WHERE id > 0;

UPDATE temp_losses
SET loss_rate = TRIM(loss_rate)
WHERE id > 0;

UPDATE temp_sales
SET quantity_sold = TRIM(quantity_sold),
    unit_price = TRIM(unit_price),
    sale_or_return = TRIM(sale_or_return),
    discount = TRIM(discount)
WHERE id > 0;

UPDATE temp_prices
SET wholesale_price = TRIM(wholesale_price)
WHERE id > 0;

-- ============================================================================
-- 4. TRANSACCIÓN PRINCIPAL: CARGA DE DIMENSIONES
-- ============================================================================
-- START TRANSACTION agrupa múltiples INSERT en una unidad atómica:
-- - Si TODAS las operaciones tienen éxito → COMMIT (confirmar cambios)
-- - Si CUALQUIER operación falla → ROLLBACK automático (cancelar TODO)
-- Garantiza que las 6 dimensiones se carguen completas o ninguna quede a medias

START TRANSACTION;

-- ----------------------------------------------------------------------------
-- 4.1 Cargar DIM_CATEGORIAS
-- ----------------------------------------------------------------------------
-- DISTINCT elimina duplicados: 251 productos tienen solo 10 categorías únicas
-- NOT NULL evita insertar registros inválidos
INSERT INTO dim_categorias (category_code, category_name)
SELECT DISTINCT
    category_code,
    category_name
FROM temp_products
WHERE category_code IS NOT NULL
    AND category_name IS NOT NULL
ORDER BY category_code;

-- ----------------------------------------------------------------------------
-- 4.2 Cargar DIM_PRODUCTOS
-- ----------------------------------------------------------------------------
-- INNER JOIN obtiene category_id desde dim_categorias (relación FK)
-- DISTINCT elimina duplicados de productos con mismo código
INSERT INTO dim_productos (item_code, item_name, category_id)
SELECT DISTINCT
    tp.item_code,
    tp.item_name,
    dc.category_id
FROM temp_products tp
    INNER JOIN dim_categorias dc ON tp.category_code = dc.category_code
WHERE tp.item_code IS NOT NULL
    AND tp.item_name IS NOT NULL
ORDER BY tp.item_code;

-- ----------------------------------------------------------------------------
-- 4.3 Cargar DIM_CALENDARIO
-- ----------------------------------------------------------------------------
-- CAST convierte VARCHAR a DATE para poder usar funciones como DAY(), MONTH(), etc.
-- UNION combina fechas de ventas y precios eliminando duplicados automáticamente
-- DAYOFWEEK retorna 1=Domingo, 2=Lunes...7=Sábado

-- Insertar fechas únicas desde ventas y precios
INSERT INTO dim_calendario (
    fecha,
    dia,
    mes,
    anio,
    trimestre,
    dia_semana,
    nombre_dia,
    nombre_mes,
    es_fin_semana
)
SELECT DISTINCT
    CAST(sale_date AS DATE) AS fecha,
    DAY(CAST(sale_date AS DATE)) AS dia,
    MONTH(CAST(sale_date AS DATE)) AS mes,
    YEAR(CAST(sale_date AS DATE)) AS anio,
    QUARTER(CAST(sale_date AS DATE)) AS trimestre,
    DAYOFWEEK(CAST(sale_date AS DATE)) AS dia_semana,
    DAYNAME(CAST(sale_date AS DATE)) AS nombre_dia,
    MONTHNAME(CAST(sale_date AS DATE)) AS nombre_mes,
    CASE
        WHEN DAYOFWEEK(CAST(sale_date AS DATE)) IN (1, 7) THEN TRUE  -- 1=Domingo, 7=Sábado
        ELSE FALSE
    END AS es_fin_semana
FROM temp_sales
WHERE sale_date IS NOT NULL
UNION
SELECT DISTINCT
    CAST(price_date AS DATE),
    DAY(CAST(price_date AS DATE)),
    MONTH(CAST(price_date AS DATE)),
    YEAR(CAST(price_date AS DATE)),
    QUARTER(CAST(price_date AS DATE)),
    DAYOFWEEK(CAST(price_date AS DATE)),
    DAYNAME(CAST(price_date AS DATE)),
    MONTHNAME(CAST(price_date AS DATE)),
    CASE
        WHEN DAYOFWEEK(CAST(price_date AS DATE)) IN (1, 7) THEN TRUE
        ELSE FALSE
    END
FROM temp_prices
WHERE price_date IS NOT NULL
ORDER BY fecha;

-- ----------------------------------------------------------------------------
-- 4.4 Cargar DIM_TIEMPO
-- ----------------------------------------------------------------------------
-- Tabla estática con las 24 horas (0-23)
-- periodo_dia facilita análisis por Madrugada/Mañana/Tarde/Noche
-- time_id coincide con HOUR(sale_time) para hacer JOIN en fact_ventas


INSERT INTO dim_tiempo (time_id, hora, periodo_dia)
VALUES
    (0, 0, 'Madrugada'),
    (1, 1, 'Madrugada'),
    (2, 2, 'Madrugada'),
    (3, 3, 'Madrugada'),
    (4, 4, 'Madrugada'),
    (5, 5, 'Madrugada'),
    (6, 6, 'Mañana'),
    (7, 7, 'Mañana'),
    (8, 8, 'Mañana'),
    (9, 9, 'Mañana'),
    (10, 10, 'Mañana'),
    (11, 11, 'Mañana'),
    (12, 12, 'Tarde'),
    (13, 13, 'Tarde'),
    (14, 14, 'Tarde'),
    (15, 15, 'Tarde'),
    (16, 16, 'Tarde'),
    (17, 17, 'Tarde'),
    (18, 18, 'Noche'),
    (19, 19, 'Noche'),
    (20, 20, 'Noche'),
    (21, 21, 'Noche'),
    (22, 22, 'Noche'),
    (23, 23, 'Noche');

-- ----------------------------------------------------------------------------
-- 4.5 Cargar DIM_PRECIOS
-- ----------------------------------------------------------------------------
-- CAST convierte wholesale_price de VARCHAR a DECIMAL(10,2) para cálculos
-- REGEXP valida que el valor sea numérico antes de convertir
-- JOIN con dim_productos y dim_calendario obtiene las FKs necesarias


INSERT INTO dim_precios (product_id, date_id, wholesale_price)
SELECT
    dp.product_id,
    dc.date_id,
    CAST(tp.wholesale_price AS DECIMAL(10, 2))
FROM temp_prices tp
    INNER JOIN dim_productos dp ON tp.item_code = dp.item_code
    INNER JOIN dim_calendario dc ON CAST(tp.price_date AS DATE) = dc.fecha
WHERE tp.wholesale_price IS NOT NULL
    AND tp.wholesale_price REGEXP '^[0-9]+\\.?[0-9]*$';  -- Validar formato numérico

-- ----------------------------------------------------------------------------
-- 4.6 Cargar DIM_PERDIDAS
-- ----------------------------------------------------------------------------
-- CAST convierte loss_rate de VARCHAR a DECIMAL(5,2) para porcentajes
-- REGEXP valida formato numérico antes de conversión
-- JOIN con dim_productos obtiene product_id como FK


INSERT INTO dim_perdidas (product_id, loss_rate)
SELECT
    dp.product_id,
    CAST(tl.loss_rate AS DECIMAL(5, 2))
FROM temp_losses tl
    INNER JOIN dim_productos dp ON tl.item_code = dp.item_code
WHERE tl.loss_rate IS NOT NULL
    AND tl.loss_rate REGEXP '^[0-9]+\\.?[0-9]*$';

-- Confirmar transacción de dimensiones
COMMIT;

-- ============================================================================
-- 5. TRANSACCIÓN PRINCIPAL: CARGA DE TABLA DE HECHOS
-- ============================================================================
-- Transacción para insertar 878k+ registros en fact_ventas
-- Si falla a la mitad, MySQL revierte automáticamente todos los INSERT

-- Aumentar timeouts para evitar Error 2013 (Lost connection)
SET SESSION wait_timeout = 28800;
SET SESSION interactive_timeout = 28800;
SET SESSION net_read_timeout = 600;
SET SESSION net_write_timeout = 600;
SET SESSION max_execution_time = 0;

START TRANSACTION;

-- ----------------------------------------------------------------------------
-- 5.1 Cargar FACT_VENTAS
-- ----------------------------------------------------------------------------
-- CAST múltiples: quantity_sold y unit_price de VARCHAR a DECIMAL
-- Cálculo de total_sale_amount: quantity * price (métrica calculada)
-- CASE convierte 'Yes'/'No' a BOOLEAN para has_discount
-- CASE convierte 'return'/'sale' a BOOLEAN para is_return
-- HOUR() extrae la hora de sale_time para hacer JOIN con dim_tiempo
-- REGEXP valida que quantity y price sean numéricos antes de CAST


INSERT INTO fact_ventas (
    date_id,
    time_id,
    product_id,
    quantity_sold,
    unit_selling_price,
    total_sale_amount,
    has_discount,
    is_return
)
SELECT
    dc.date_id,
    HOUR(CAST(ts.sale_time AS TIME)) AS time_id,
    dp.product_id,
    CAST(ts.quantity_sold AS DECIMAL(10, 3)),
    CAST(ts.unit_price AS DECIMAL(10, 2)),
    -- Cálculo del total de venta
    CAST(ts.quantity_sold AS DECIMAL(10, 3)) * CAST(ts.unit_price AS DECIMAL(10, 2)),
    -- Conversión de 'Yes'/'No' a BOOLEAN
    CASE WHEN ts.discount = 'Yes' THEN TRUE ELSE FALSE END,
    -- Conversión de 'return'/'sale' a BOOLEAN
    CASE WHEN ts.sale_or_return = 'return' THEN TRUE ELSE FALSE END
FROM temp_sales ts
    INNER JOIN dim_productos dp ON ts.item_code = dp.item_code
    INNER JOIN dim_calendario dc ON CAST(ts.sale_date AS DATE) = dc.fecha
WHERE ts.quantity_sold IS NOT NULL
    AND ts.unit_price IS NOT NULL
    AND ts.quantity_sold REGEXP '^[0-9]+\\.?[0-9]*$'
    AND ts.unit_price REGEXP '^[0-9]+\\.?[0-9]*$';

-- Confirmar transacción
COMMIT;

-- ============================================================================
-- 6. EJEMPLOS DE UPDATE - Actualización de datos
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Ejemplo 1: Actualizar nombres de productos con formato inconsistente
-- ----------------------------------------------------------------------------
-- Objetivo: Convertir "MANZANA" a "Manzana" (Title Case)
-- SUBSTRING extrae primera letra y resto, UPPER/LOWER aplican formato
-- Subquery anidada evita error "can't update table being selected"
-- WHERE product_id IN usa PK para cumplir con safe mode
-- Transacción para poder revertir cambios si no gustan los resultados

START TRANSACTION;

UPDATE dim_productos
SET item_name = CONCAT(UPPER(SUBSTRING(item_name, 1, 1)), LOWER(SUBSTRING(item_name, 2)))
WHERE product_id IN (
    SELECT product_id FROM (
        SELECT product_id FROM dim_productos
        WHERE item_name = UPPER(item_name) AND LENGTH(item_name) > 1
    ) AS subquery
);

COMMIT;

-- ----------------------------------------------------------------------------
-- Ejemplo 2: Actualizar precios mayoristas con inflación del 2%
-- ----------------------------------------------------------------------------
-- Objetivo: Simular ajuste de precios por inflación
-- CREATE TEMPORARY TABLE crea respaldo (solo existe en la sesión actual)
-- CAST redondea resultado a 2 decimales
-- ROLLBACK demuestra cómo revertir cambios (los precios vuelven al valor original)
-- Tabla temporal backup_precios también se descarta con ROLLBACK

START TRANSACTION;

-- Crear tabla de respaldo antes de actualizar
CREATE TEMPORARY TABLE backup_precios AS SELECT * FROM dim_precios;

UPDATE dim_precios
SET wholesale_price = CAST(wholesale_price * 1.02 AS DECIMAL(10, 2))
WHERE price_id IN (
    SELECT price_id FROM (
        SELECT price_id FROM dim_precios WHERE wholesale_price > 0
    ) AS subquery
);

-- Revertir cambios (solo fue un ejemplo)
ROLLBACK;

-- ----------------------------------------------------------------------------
-- Ejemplo 3: Actualizar precios de venta con descuento
-- ----------------------------------------------------------------------------
-- Objetivo: Reducir 10% el precio de ventas que tienen descuento activado
-- Demuestra: UPDATE con cálculo aritmético, WHERE con BOOLEAN
-- Transacción permite revertir si no gustan los cambios

START TRANSACTION;

UPDATE fact_ventas
SET unit_selling_price = CAST(unit_selling_price * 0.90 AS DECIMAL(10, 2)),
    total_sale_amount = CAST(total_sale_amount * 0.90 AS DECIMAL(10, 2))
WHERE sale_id IN (
    SELECT sale_id FROM (
        SELECT sale_id FROM fact_ventas WHERE has_discount = TRUE
    ) AS subquery
);

-- Revertir cambios (solo fue un ejemplo)
ROLLBACK;

-- ============================================================================
-- 7. EJEMPLOS DE DELETE - Eliminación de datos
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Ejemplo 1: Identificar productos sin ventas (sin eliminar)
-- ----------------------------------------------------------------------------
-- Objetivo: Encontrar productos sin registros de venta
-- NOT EXISTS retorna TRUE si no hay ventas para ese producto
-- SELECT COUNT muestra cuántos productos nunca se vendieron
-- DELETE comentado: solo identifica, no elimina (buena práctica)
-- ROLLBACK innecesario (no hubo cambios) pero demuestra uso

START TRANSACTION;

SELECT COUNT(*) AS productos_sin_ventas
FROM dim_productos dp
WHERE NOT EXISTS (
    SELECT 1
    FROM fact_ventas fv
    WHERE fv.product_id = dp.product_id
);

-- DELETE no ejecutado (solo demostración)
-- DELETE FROM dim_productos WHERE NOT EXISTS (...);

ROLLBACK;

-- ----------------------------------------------------------------------------
-- Ejemplo 2: Eliminar ventas con monto negativo (si existieran)
-- ----------------------------------------------------------------------------
-- Objetivo: Eliminar registros de ventas con errores (monto negativo)
-- WHERE usa sale_id (PK) para cumplir con safe mode
-- Transacción protege: si falla, no queda tabla con datos inconsistentes

START TRANSACTION;

DELETE FROM fact_ventas
WHERE sale_id IN (
    SELECT sale_id FROM (
        SELECT sale_id FROM fact_ventas WHERE total_sale_amount < 0
    ) AS subquery
);

COMMIT;

-- ----------------------------------------------------------------------------
-- Ejemplo 3: Identificar devoluciones (sin eliminar)
-- ----------------------------------------------------------------------------
-- Objetivo: Contar cuántas ventas son devoluciones (returns)
-- is_return = TRUE: campo BOOLEAN que indica devolución
-- DELETE comentado: buena práctica identificar antes de eliminar
-- ROLLBACK: demuestra uso aunque no hubo cambios

START TRANSACTION;

SELECT COUNT(*) AS total_devoluciones
FROM fact_ventas
WHERE is_return = TRUE;

-- DELETE no ejecutado (solo demostración)
-- DELETE FROM fact_ventas WHERE is_return = TRUE;

ROLLBACK;

-- ============================================================================
-- 8. VALIDACIÓN DE DATOS CARGADOS
-- ============================================================================
-- Verifica que todos los datos se cargaron correctamente
-- Valida integridad referencial (todas las FKs tienen registros válidos)
-- Proporciona resumen de registros por tabla

-- Contar registros en cada tabla
SELECT 'dim_categorias' AS tabla, COUNT(*) AS total_registros FROM dim_categorias
UNION ALL
SELECT 'dim_productos', COUNT(*) FROM dim_productos
UNION ALL
SELECT 'dim_calendario', COUNT(*) FROM dim_calendario
UNION ALL
SELECT 'dim_tiempo', COUNT(*) FROM dim_tiempo
UNION ALL
SELECT 'dim_precios', COUNT(*) FROM dim_precios
UNION ALL
SELECT 'dim_perdidas', COUNT(*) FROM dim_perdidas
UNION ALL
SELECT 'fact_ventas', COUNT(*) FROM fact_ventas;

-- Verificar que todas las ventas tienen producto, fecha y hora válidos
SELECT
    'Ventas sin producto' AS validacion,
    COUNT(*) AS cantidad
FROM fact_ventas fv
WHERE NOT EXISTS (SELECT 1 FROM dim_productos dp WHERE dp.product_id = fv.product_id)
UNION ALL
SELECT
    'Ventas sin fecha',
    COUNT(*)
FROM fact_ventas fv
WHERE NOT EXISTS (SELECT 1 FROM dim_calendario dc WHERE dc.date_id = fv.date_id)
UNION ALL
SELECT
    'Ventas sin hora',
    COUNT(*)
FROM fact_ventas fv
WHERE NOT EXISTS (SELECT 1 FROM dim_tiempo dt WHERE dt.time_id = fv.time_id);

-- ============================================================================
-- 9. FUNCIONES DE FECHA - Ejemplos adicionales
-- ============================================================================
-- Demuestra uso de funciones de fecha de MySQL
-- MIN/MAX obtiene rango de fechas en el dataset
-- DATEDIFF calcula días entre fechas
-- DATE_FORMAT formatea fechas para presentación

-- Rango de fechas en el dataset
SELECT
    'Rango de fechas' AS metrica,
    DATE_FORMAT(MIN(fecha), '%Y-%m-%d') AS fecha_minima,
    DATE_FORMAT(MAX(fecha), '%Y-%m-%d') AS fecha_maxima,
    DATEDIFF(MAX(fecha), MIN(fecha)) AS dias_totales
FROM dim_calendario;

-- Ventas por mes usando funciones de fecha
SELECT
    DATE_FORMAT(dc.fecha, '%M %Y') AS mes_anio,
    COUNT(*) AS total_ventas,
    CAST(SUM(fv.total_sale_amount) AS DECIMAL(12, 2)) AS total_RMB
FROM fact_ventas fv
    INNER JOIN dim_calendario dc ON fv.date_id = dc.date_id
GROUP BY YEAR(dc.fecha), MONTH(dc.fecha), DATE_FORMAT(dc.fecha, '%M %Y')
ORDER BY YEAR(dc.fecha), MONTH(dc.fecha);

-- ============================================================================
-- 10. LIMPIEZA DE TABLAS TEMPORALES
-- ============================================================================
-- Elimina tablas temporales para liberar memoria
-- Ya no son necesarias: datos transformados e insertados en tablas finales

DROP TABLE IF EXISTS temp_products;
DROP TABLE IF EXISTS temp_sales;
DROP TABLE IF EXISTS temp_prices;
DROP TABLE IF EXISTS temp_losses;

-- ============================================================================
-- FIN DEL ARCHIVO 02_data.sql
-- ============================================================================
