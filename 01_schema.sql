-- ============================================================================
-- CONSTRAINTS UTILIZADAS (garantizan integridad y validación de datos)
-- ============================================================================

-- PRIMARY KEY: Identifica únicamente cada registro
-- FOREIGN KEY: Garantiza relaciones válidas entre tablas
--   * ON DELETE RESTRICT: No permite eliminar si hay dependencias
--   * ON DELETE CASCADE: Elimina en cascada
--   * ON UPDATE CASCADE: Propaga cambios de ID
-- UNIQUE: Evita duplicados
-- NOT NULL: Campo obligatorio
-- CHECK: Valida rangos y formatos (ej: dia BETWEEN 1 AND 31)
-- DEFAULT: Valor automático (ej: CURRENT_TIMESTAMP)

-- ============================================================================
-- 1. CREACIÓN DE LA BASE DE DATOS
-- ============================================================================

-- Eliminar la base de datos si existe para empezar desde cero
DROP DATABASE IF EXISTS supermarket_sales;

-- Crear la base de datos
CREATE DATABASE supermarket_sales;

-- Usar la base de datos
USE supermarket_sales;

-- ============================================================================
-- 2. TABLAS DE DIMENSIONES (DIMENSION TABLES)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 2.1 DIM_CATEGORIAS
-- Descripción: Catálogo de categorías de productos
-- Granularidad: Una fila por categoría única
-- PK: category_id (clave subrogada autogenerada)
-- Normalización: Esta tabla está en 3NF, evita repetir nombres de categorías
-- Justificación: Separamos categorías de productos para:
--   - Evitar redundancia (el nombre no se repite miles de veces)
--   - Facilitar actualizaciones (cambiar nombre en un solo lugar)
--   - Mantener integridad referencial
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS dim_categorias (
    category_id INT AUTO_INCREMENT,
    category_code VARCHAR(50) NOT NULL,
    category_name VARCHAR(200) NOT NULL,

    PRIMARY KEY (category_id), 
    UNIQUE KEY uq_category_code (category_code), -- Evita códigos duplicados
    CONSTRAINT chk_category_code_format CHECK (category_code REGEXP '^[0-9]') -- Formato: debe empezar con número
);

-- ----------------------------------------------------------------------------
-- 2.2 DIM_PRODUCTOS
-- Descripción: Catálogo maestro de productos del supermercado
-- Granularidad: Una fila por producto único (identificado por Item Code)
-- PK: product_id (clave subrogada)
-- FK: category_id → dim_categorias
-- Normalización: Separamos productos de categorías (3NF)
-- Justificación FK:
--   - ON DELETE RESTRICT: No se puede eliminar categoría con productos
--   - ON UPDATE CASCADE: Si cambia category_id, se propaga a productos
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS dim_productos (
    product_id INT AUTO_INCREMENT,
    item_code BIGINT NOT NULL,
    item_name VARCHAR(200) NOT NULL,
    category_id INT NOT NULL,
    created_date DATETIME DEFAULT CURRENT_TIMESTAMP,  -- Auditoría: registra fecha de alta automáticamente

    PRIMARY KEY (product_id),
    UNIQUE KEY uq_item_code (item_code),              -- Evita productos duplicados
    CONSTRAINT fk_productos_categoria FOREIGN KEY (category_id)
        REFERENCES dim_categorias(category_id)
        ON DELETE RESTRICT  -- No permite eliminar categoría si tiene productos
        ON UPDATE CASCADE,  -- Si cambia category_id, se actualiza aquí
    CONSTRAINT chk_item_code_positive CHECK (item_code > 0)  -- Solo códigos positivos
);

-- ----------------------------------------------------------------------------
-- 2.3 DIM_CALENDARIO
-- Descripción: Dimensión temporal con atributos de fecha
-- Granularidad: Una fila por día
-- PK: date_id
-- Uso: Permite análisis temporal (día, mes, trimestre, día de semana)
-- Justificación: Desnormalizar atributos de fecha mejora performance:
--   - No necesitas calcular MONTH(), YEAR() cada vez
--   - Facilita agrupaciones y filtros por periodo
--   - Permite análisis de patrones (fin de semana vs laborable)
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS dim_calendario (
    date_id INT AUTO_INCREMENT,
    fecha DATE NOT NULL,
    dia TINYINT NOT NULL,
    mes TINYINT NOT NULL,
    anio SMALLINT NOT NULL,
    trimestre TINYINT NOT NULL,
    dia_semana TINYINT NOT NULL,  -- 1=Lunes, 7=Domingo
    nombre_dia VARCHAR(20) NOT NULL,
    nombre_mes VARCHAR(20) NOT NULL,
    es_fin_semana BOOLEAN NOT NULL DEFAULT FALSE,

    PRIMARY KEY (date_id),
    UNIQUE KEY uq_fecha (fecha),                             -- No duplicar fechas
    CONSTRAINT chk_dia CHECK (dia BETWEEN 1 AND 31),
    CONSTRAINT chk_mes CHECK (mes BETWEEN 1 AND 12),
    CONSTRAINT chk_trimestre CHECK (trimestre BETWEEN 1 AND 4),
    CONSTRAINT chk_dia_semana CHECK (dia_semana BETWEEN 1 AND 7),
    CONSTRAINT chk_anio CHECK (anio >= 2020 AND anio <= 2100)  -- Rango razonable de años
);

-- ----------------------------------------------------------------------------
-- 2.4 DIM_TIEMPO
-- Descripción: Dimensión de horas del día
-- Granularidad: Una fila por hora (0-23)
-- PK: time_id
-- Uso: Análisis de patrones de venta por hora/periodo del día
-- Justificación: Tabla pequeña (24 filas) que permite:
--   - Clasificar ventas por periodo (Madrugada, Mañana, Tarde, Noche)
--   - Análisis de horas pico
--   - Optimización de personal por horario
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS dim_tiempo (
    time_id TINYINT,
    hora TINYINT NOT NULL,
    periodo_dia VARCHAR(20) NOT NULL,

    PRIMARY KEY (time_id),
    CONSTRAINT chk_hora CHECK (hora BETWEEN 0 AND 23),
    CONSTRAINT chk_periodo_dia CHECK (periodo_dia IN ('Madrugada', 'Mañana', 'Tarde', 'Noche'))
);

-- ----------------------------------------------------------------------------
-- 2.5 DIM_PRECIOS
-- Descripción: Histórico de precios mayoristas por producto y fecha
-- Granularidad: Una fila por combinación producto-fecha
-- PK: price_id
-- FK: product_id → dim_productos, date_id → dim_calendario
-- Uso: Calcular márgenes (precio venta - precio mayorista)
-- Justificación: Mantener histórico permite:
--   - Análisis de márgenes temporales
--   - Identificar productos rentables
--   - Detectar impacto de cambios de precio
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS dim_precios (
    price_id INT AUTO_INCREMENT,
    product_id INT NOT NULL,
    date_id INT NOT NULL,
    wholesale_price DECIMAL(10, 2) NOT NULL,

    PRIMARY KEY (price_id),
    UNIQUE KEY uq_precio_producto_fecha (product_id, date_id),  -- Un precio por producto-fecha
    CONSTRAINT fk_precios_producto FOREIGN KEY (product_id)
        REFERENCES dim_productos(product_id)
        ON DELETE CASCADE  -- Precio sin producto no tiene sentido
        ON UPDATE CASCADE,
    CONSTRAINT fk_precios_fecha FOREIGN KEY (date_id)
        REFERENCES dim_calendario(date_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT chk_wholesale_price_positive CHECK (wholesale_price > 0)
);
-- ----------------------------------------------------------------------------
-- 2.6 DIM_PERDIDAS
-- Descripción: Tasa de pérdida (merma/deterioro) por producto
-- Granularidad: Una fila por producto
-- PK: loss_id
-- FK: product_id → dim_productos
-- Uso: Calcular margen real considerando mermas
-- Justificación: En productos frescos la pérdida es significativa:
--   - Permite calcular margen real
--   - Identificar productos con alta merma
--   - Optimizar precios para compensar deterioro
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS dim_perdidas (
    loss_id INT AUTO_INCREMENT,
    product_id INT NOT NULL,
    loss_rate DECIMAL(5, 2) NOT NULL,

    PRIMARY KEY (loss_id),
    UNIQUE KEY uq_perdida_producto (product_id),  -- Cada producto tiene una sola tasa
    CONSTRAINT fk_perdidas_producto FOREIGN KEY (product_id)
        REFERENCES dim_productos(product_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT chk_loss_rate_range CHECK (loss_rate BETWEEN 0 AND 100)  -- Porcentaje válido
);

-- ============================================================================
-- 3. TABLA DE HECHOS (FACT TABLE)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 3.1 FACT_VENTAS
-- Descripción: Tabla de hechos con transacciones de venta
-- Granularidad: Una fila por transacción individual
-- PK: sale_id
-- FKs: date_id, time_id, product_id
-- Modelo: Star Schema - tabla central conectada a dimensiones
-- Justificación del modelo:
--   - Star Schema optimizado para consultas analíticas (OLAP)
--   - Fact table contiene métricas (quantity, price, total)
--   - Dimensions contienen contexto (qué, cuándo)
--   - Fácil de consultar con JOINs simples
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS fact_ventas (
    sale_id INT AUTO_INCREMENT,
    date_id INT NOT NULL,
    time_id TINYINT NOT NULL,
    product_id INT NOT NULL,
    quantity_sold DECIMAL(10, 3) NOT NULL,
    unit_selling_price DECIMAL(10, 2) NOT NULL,
    total_sale_amount DECIMAL(12, 2) NOT NULL,
    has_discount BOOLEAN NOT NULL DEFAULT FALSE,
    is_return BOOLEAN NOT NULL DEFAULT FALSE,
    created_timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (sale_id),
    CONSTRAINT fk_ventas_fecha FOREIGN KEY (date_id)
        REFERENCES dim_calendario(date_id)
        ON DELETE RESTRICT  -- Ventas históricas deben preservarse
        ON UPDATE CASCADE,
    CONSTRAINT fk_ventas_tiempo FOREIGN KEY (time_id)
        REFERENCES dim_tiempo(time_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT fk_ventas_producto FOREIGN KEY (product_id)
        REFERENCES dim_productos(product_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT chk_quantity_sold_positive CHECK (quantity_sold > 0),
    CONSTRAINT chk_unit_price_positive CHECK (unit_selling_price > 0),
    CONSTRAINT chk_total_sale_positive CHECK (total_sale_amount > 0)
);

-- ============================================================================
-- 4. ÍNDICES PARA MEJORAR PERFORMANCE
-- ============================================================================

-- Justificación general: Los índices aceleran búsquedas y JOINs
-- Se crean en columnas usadas frecuentemente en WHERE, JOIN, ORDER BY

-- ----------------------------------------------------------------------------
-- Índice en dim_productos.category_id
-- Justificación: Usado en JOINs con dim_categorias y filtros WHERE
-- Performance: Reduce búsquedas de O(n) a O(log n)
-- ----------------------------------------------------------------------------

CREATE INDEX idx_productos_categoria
ON dim_productos(category_id);

-- ----------------------------------------------------------------------------
-- Índice compuesto en fact_ventas (date_id, product_id)
-- Justificación: Consultas comunes filtran por fecha y/o producto
-- Performance: Acelera queries de ventas por periodo y producto
-- ----------------------------------------------------------------------------

CREATE INDEX idx_ventas_fecha_producto
ON fact_ventas(date_id, product_id);

-- ----------------------------------------------------------------------------
-- Índice en fact_ventas.time_id
-- Justificación: Para análisis de patrones horarios
-- ----------------------------------------------------------------------------

CREATE INDEX idx_ventas_tiempo
ON fact_ventas(time_id);

-- ----------------------------------------------------------------------------
-- Índice en dim_calendario.fecha
-- Justificación: Búsquedas rápidas por fecha específica
-- ----------------------------------------------------------------------------

CREATE INDEX idx_calendario_fecha
ON dim_calendario(fecha);

-- ----------------------------------------------------------------------------
-- Índice compuesto en dim_precios (product_id, date_id)
-- Justificación: Para calcular márgenes rápidamente
-- ----------------------------------------------------------------------------

CREATE INDEX idx_precios_producto_fecha
ON dim_precios(product_id, date_id);

-- ============================================================================
-- 5. VISTAS (VIEWS)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- VIEW: vw_ventas_completas
-- Descripción: Vista desnormalizada que une fact table con dimensiones
-- Uso: Evita escribir múltiples JOINs repetidamente
-- Justificación: Mejora productividad de analistas:
--   - Una SELECT en lugar de 4 JOINs cada vez
--   - Nombres descriptivos
--   - Oculta complejidad del modelo
-- Performance: La vista no almacena datos, solo es un alias
-- ----------------------------------------------------------------------------

CREATE OR REPLACE VIEW vw_ventas_completas AS
SELECT
    -- Campos de la venta
    v.sale_id,
    v.quantity_sold,
    v.unit_selling_price,
    v.total_sale_amount,
    v.has_discount,
    v.is_return,

    -- Dimensión fecha
    c.fecha,
    c.dia,
    c.mes,
    c.anio,
    c.trimestre,
    c.dia_semana,
    c.nombre_dia,
    c.nombre_mes,
    c.es_fin_semana,

    -- Dimensión tiempo
    t.hora,
    t.periodo_dia,

    -- Dimensión producto
    p.item_code,
    p.item_name,

    -- Dimensión categoría
    cat.category_code,
    cat.category_name

FROM fact_ventas v
    INNER JOIN dim_calendario c ON v.date_id = c.date_id
    INNER JOIN dim_tiempo t ON v.time_id = t.time_id
    INNER JOIN dim_productos p ON v.product_id = p.product_id
    INNER JOIN dim_categorias cat ON p.category_id = cat.category_id;

-- Comentario: Simplifica análisis exploratorio
-- Uso: SELECT * FROM vw_ventas_completas WHERE mes = 7;

-- ============================================================================
-- 6. FUNCIONES DEFINIDAS POR USUARIO (USER-DEFINED FUNCTIONS)
-- ============================================================================

DELIMITER $$

-- ----------------------------------------------------------------------------
-- FUNCIÓN: fn_calcular_margen_producto
-- Descripción: Calcula el margen bruto de un producto en una fecha
-- Parámetros:
--   p_product_id: ID del producto
--   p_date_id: ID de la fecha
-- Retorna: Margen en RMB/kg (precio venta promedio - precio mayorista)
-- Justificación: Centraliza lógica de negocio:
--   - Reutilizable en múltiples queries
--   - Mantiene consistencia
--   - Facilita actualizaciones
-- ----------------------------------------------------------------------------

DROP FUNCTION IF EXISTS fn_calcular_margen_producto$$

CREATE FUNCTION fn_calcular_margen_producto(
    p_product_id INT,
    p_date_id INT
)
RETURNS DECIMAL(10, 2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_margen DECIMAL(10, 2);
    DECLARE v_avg_selling_price DECIMAL(10, 2);
    DECLARE v_wholesale_price DECIMAL(10, 2);

    -- Calcular precio de venta promedio
    SELECT AVG(unit_selling_price)
    INTO v_avg_selling_price
    FROM fact_ventas
    WHERE product_id = p_product_id
        AND date_id = p_date_id
        AND is_return = FALSE;

    -- Obtener precio mayorista
    SELECT wholesale_price
    INTO v_wholesale_price
    FROM dim_precios
    WHERE product_id = p_product_id
        AND date_id = p_date_id;

    -- Calcular margen
    IF v_avg_selling_price IS NOT NULL AND v_wholesale_price IS NOT NULL THEN
        SET v_margen = v_avg_selling_price - v_wholesale_price;
    ELSE
        SET v_margen = 0;
    END IF;

    RETURN v_margen;
END$$

-- ----------------------------------------------------------------------------
-- FUNCIÓN: fn_calcular_margen_con_perdida
-- Descripción: Calcula margen ajustado considerando pérdidas
-- Parámetros:
--   p_product_id: ID del producto
--   p_date_id: ID de la fecha
-- Retorna: Margen ajustado por pérdida
-- Lógica: margen_real = margen_bruto / (1 - loss_rate/100)
-- Justificación: El margen real debe considerar mermas:
--   - Si pérdida = 20%, solo se vende 80%
--   - El margen debe compensar productos perdidos
-- ----------------------------------------------------------------------------

DROP FUNCTION IF EXISTS fn_calcular_margen_con_perdida$$

CREATE FUNCTION fn_calcular_margen_con_perdida(
    p_product_id INT,
    p_date_id INT
)
RETURNS DECIMAL(10, 2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_margen_ajustado DECIMAL(10, 2);
    DECLARE v_margen_bruto DECIMAL(10, 2);
    DECLARE v_loss_rate DECIMAL(5, 2);

    -- Obtener margen bruto
    SET v_margen_bruto = fn_calcular_margen_producto(p_product_id, p_date_id);

    -- Obtener tasa de pérdida
    SELECT loss_rate
    INTO v_loss_rate
    FROM dim_perdidas
    WHERE product_id = p_product_id;

    -- Calcular margen ajustado
    IF v_loss_rate IS NOT NULL AND v_loss_rate < 100 THEN
        SET v_margen_ajustado = v_margen_bruto / (1 - v_loss_rate / 100.0);
    ELSE
        SET v_margen_ajustado = v_margen_bruto;
    END IF;

    RETURN v_margen_ajustado;
END$$

DELIMITER ;

-- Comentario: Estas funciones encapsulan lógica de negocio
-- Uso: SELECT fn_calcular_margen_producto(1, 1);