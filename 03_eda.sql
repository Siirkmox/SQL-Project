
USE supermarket_sales;

-- ============================================================================
-- 1. ANÁLISIS DE VENTAS POR CATEGORÍA
-- ============================================================================
-- Demuestra: INNER JOIN, GROUP BY, ORDER BY, funciones agregadas
--
-- Objetivo: Mostrar resumen de ventas agrupado por categoría de productos
-- Insights: Identifica qué categorías generan más ingresos y cuál es su ticket promedio
--
-- Explicación:
-- - COUNT(DISTINCT p.product_id): Cuenta productos únicos por categoría
-- - COUNT(fv.sale_id): Total de transacciones (número de ventas)
-- - SUM(fv.quantity_sold): Suma todas las unidades vendidas
-- - AVG(fv.total_sale_amount): Calcula el ticket promedio por venta
-- - WHERE is_return = FALSE: Excluye devoluciones del análisis
-- - ORDER BY ingresos_totales DESC: Ordena de mayor a menor ingreso

SELECT
    c.category_name AS categoria,
    COUNT(DISTINCT p.product_id) AS total_productos,
    COUNT(fv.sale_id) AS total_ventas,
    SUM(fv.quantity_sold) AS unidades_vendidas,
    CAST(SUM(fv.total_sale_amount) AS DECIMAL(12, 2)) AS ingresos_totales,
    CAST(AVG(fv.total_sale_amount) AS DECIMAL(10, 2)) AS venta_promedio
FROM fact_ventas fv
    INNER JOIN dim_productos p ON fv.product_id = p.product_id
    INNER JOIN dim_categorias c ON p.category_id = c.category_id
WHERE fv.is_return = FALSE
GROUP BY c.category_id, c.category_name
ORDER BY ingresos_totales DESC;

-- ============================================================================
-- 2. TOP 10 PRODUCTOS MÁS VENDIDOS
-- ============================================================================
-- Demuestra: JOINs múltiples, LIMIT, ORDER BY con múltiples criterios
--
-- Objetivo: Identificar los 10 productos con mayores ingresos totales
-- Insights: Productos "estrella" del negocio para priorizar inventario y promociones
--
-- Explicación:
-- - LIMIT 10: Restringe resultado a los 10 primeros productos
-- - ORDER BY ingresos_totales DESC, numero_ventas DESC: Ordena primero por ingresos,
--   luego por número de ventas (criterio de desempate)
-- - GROUP BY incluye product_id, item_name, category_name para evitar duplicados

SELECT
    p.item_name AS producto,
    c.category_name AS categoria,
    COUNT(fv.sale_id) AS numero_ventas,
    SUM(fv.quantity_sold) AS unidades_vendidas,
    CAST(SUM(fv.total_sale_amount) AS DECIMAL(12, 2)) AS ingresos_totales,
    CAST(AVG(fv.unit_selling_price) AS DECIMAL(10, 2)) AS precio_promedio
FROM fact_ventas fv
    INNER JOIN dim_productos p ON fv.product_id = p.product_id
    INNER JOIN dim_categorias c ON p.category_id = c.category_id
WHERE fv.is_return = FALSE
GROUP BY p.product_id, p.item_name, c.category_name
ORDER BY ingresos_totales DESC, numero_ventas DESC
LIMIT 10;

-- ============================================================================
-- 3. VENTAS POR DÍA DE LA SEMANA
-- ============================================================================
-- Demuestra: INNER JOIN, GROUP BY con ORDER BY personalizado, CASE
--
-- Objetivo: Analizar comportamiento de ventas por día de la semana
-- Insights: Identifica si las ventas son mayores en fin de semana o entre semana
--
-- Explicación:
-- - cal.dia_semana: Campo numérico (1=Domingo, 2=Lunes... 7=Sábado)
-- - CASE evalúa es_fin_semana para etiquetar días
-- - GROUP BY incluye dia_semana, nombre_dia y es_fin_semana
-- - ORDER BY cal.dia_semana: Ordena cronológicamente (Domingo a Sábado)

SELECT
    cal.nombre_dia AS dia_semana,
    cal.dia_semana AS numero_dia,
    COUNT(fv.sale_id) AS total_ventas,
    CAST(SUM(fv.total_sale_amount) AS DECIMAL(12, 2)) AS ingresos,
    CAST(AVG(fv.total_sale_amount) AS DECIMAL(10, 2)) AS venta_promedio,
    CASE
        WHEN cal.es_fin_semana = TRUE THEN 'Fin de semana'
        ELSE 'Entre semana'
    END AS tipo_dia
FROM fact_ventas fv
    INNER JOIN dim_calendario cal ON fv.date_id = cal.date_id
WHERE fv.is_return = FALSE
GROUP BY cal.dia_semana, cal.nombre_dia, cal.es_fin_semana
ORDER BY cal.dia_semana;

-- ============================================================================
-- 4. VENTAS POR PERIODO DEL DÍA
-- ============================================================================
-- Demuestra: INNER JOIN, GROUP BY, ORDER BY
--
-- Objetivo: Agrupa ventas por periodos (Madrugada, Mañana, Tarde, Noche)
-- Insights: Identifica horas pico para optimizar dotación de personal y logística
--
-- Explicación:
-- - MIN(t.hora) y MAX(t.hora): Muestra rango de horas para cada periodo
-- - dim_tiempo contiene campo periodo_dia pre-calculado
-- - ORDER BY ingresos DESC: Ordena por periodo más rentable

SELECT
    t.periodo_dia AS periodo,
    COUNT(fv.sale_id) AS total_ventas,
    CAST(SUM(fv.total_sale_amount) AS DECIMAL(12, 2)) AS ingresos,
    CAST(AVG(fv.total_sale_amount) AS DECIMAL(10, 2)) AS venta_promedio,
    MIN(t.hora) AS hora_inicio,
    MAX(t.hora) AS hora_fin
FROM fact_ventas fv
    INNER JOIN dim_tiempo t ON fv.time_id = t.time_id
WHERE fv.is_return = FALSE
GROUP BY t.periodo_dia
ORDER BY ingresos DESC;

-- ============================================================================
-- 5. ANÁLISIS DE DESCUENTOS
-- ============================================================================
-- Demuestra: CASE, GROUP BY, agregaciones con condiciones
--
-- Objetivo: Compara ventas con descuento vs. sin descuento
-- Insights: Evalúa si los descuentos incrementan volumen sin afectar ingresos totales
--
-- Explicación:
-- - CASE transforma has_discount (BOOLEAN) a etiqueta legible
-- - GROUP BY fv.has_discount: Agrupa en dos categorías (TRUE/FALSE)
-- - AVG(fv.quantity_sold): Cantidad promedio por transacción

SELECT
    CASE
        WHEN fv.has_discount = TRUE THEN 'Con descuento'
        ELSE 'Sin descuento'
    END AS tipo_venta,
    COUNT(fv.sale_id) AS total_ventas,
    CAST(SUM(fv.total_sale_amount) AS DECIMAL(12, 2)) AS ingresos,
    CAST(AVG(fv.total_sale_amount) AS DECIMAL(10, 2)) AS venta_promedio,
    CAST(AVG(fv.quantity_sold) AS DECIMAL(10, 2)) AS cantidad_promedio
FROM fact_ventas fv
WHERE fv.is_return = FALSE
GROUP BY fv.has_discount
ORDER BY ingresos DESC;

-- ============================================================================
-- 6. RANKING DE PRODUCTOS POR INGRESOS CON FUNCIÓN DE VENTANA
-- ============================================================================
-- Demuestra: RANK(), OVER(), PARTITION BY, funciones de ventana
--
-- Objetivo: Crear ranking de productos por ingresos dentro de cada categoría Y general
-- Insights: Identifica los mejores productos por categoría y globalmente
--
-- Explicación:
-- - RANK() OVER (PARTITION BY...): Ranking dentro de cada categoría (reinicia en cada una)
-- - RANK() OVER (ORDER BY...): Ranking general (sin PARTITION, todos los productos juntos)
-- - PARTITION BY c.category_id: Divide en grupos por categoría
-- - ranking_categoria reinicia en 1 para cada categoría
-- - ranking_general es único en toda la tabla

SELECT
    c.category_name AS categoria,
    p.item_name AS producto,
    CAST(SUM(fv.total_sale_amount) AS DECIMAL(12, 2)) AS ingresos_totales,
    COUNT(fv.sale_id) AS numero_ventas,
    RANK() OVER (PARTITION BY c.category_id ORDER BY SUM(fv.total_sale_amount) DESC) AS ranking_categoria,
    RANK() OVER (ORDER BY SUM(fv.total_sale_amount) DESC) AS ranking_general
FROM fact_ventas fv
    INNER JOIN dim_productos p ON fv.product_id = p.product_id
    INNER JOIN dim_categorias c ON p.category_id = c.category_id
WHERE fv.is_return = FALSE
GROUP BY c.category_id, c.category_name, p.product_id, p.item_name
ORDER BY ranking_general
LIMIT 20;

-- ============================================================================
-- 7. ANÁLISIS DE MARGEN DE GANANCIA CON CTE
-- ============================================================================
-- Demuestra: WITH (CTE), LEFT JOIN, cálculos complejos, subconsultas
--
-- Objetivo: Calcular margen de ganancia comparando precio de venta vs. precio mayorista
-- Insights: Identifica productos más rentables y porcentaje de margen
--
-- Explicación:
-- - WITH crea CTEs (Common Table Expressions) - subconsultas temporales con nombre
-- - ventas_por_producto: Totaliza ventas y calcula precio promedio de venta
-- - precios_mayoristas: Calcula precio mayorista promedio por producto
-- - LEFT JOIN: Incluye productos aunque no tengan precio mayorista
-- - COALESCE(pm.precio_mayorista_promedio, 0): Si NULL, usa 0
-- - margen_unitario = precio_venta - precio_mayorista
-- - ganancia_total = margen_unitario × unidades_vendidas
-- - porcentaje_margen = (margen / precio_mayorista) × 100

WITH ventas_por_producto AS (
    SELECT
        fv.product_id,
        p.item_name,
        c.category_name,
        SUM(fv.quantity_sold) AS unidades_vendidas,
        CAST(SUM(fv.total_sale_amount) AS DECIMAL(12, 2)) AS ingresos_totales,
        CAST(AVG(fv.unit_selling_price) AS DECIMAL(10, 2)) AS precio_venta_promedio
    FROM fact_ventas fv
        INNER JOIN dim_productos p ON fv.product_id = p.product_id
        INNER JOIN dim_categorias c ON p.category_id = c.category_id
    WHERE fv.is_return = FALSE
    GROUP BY fv.product_id, p.item_name, c.category_name
),
precios_mayoristas AS (
    SELECT
        product_id,
        CAST(AVG(wholesale_price) AS DECIMAL(10, 2)) AS precio_mayorista_promedio
    FROM dim_precios
    GROUP BY product_id
)
SELECT
    v.item_name AS producto,
    v.category_name AS categoria,
    v.unidades_vendidas,
    v.precio_venta_promedio,
    COALESCE(pm.precio_mayorista_promedio, 0) AS precio_mayorista,
    CAST(v.precio_venta_promedio - COALESCE(pm.precio_mayorista_promedio, 0) AS DECIMAL(10, 2)) AS margen_unitario,
    CAST((v.precio_venta_promedio - COALESCE(pm.precio_mayorista_promedio, 0)) * v.unidades_vendidas AS DECIMAL(12, 2)) AS ganancia_total,
    CASE
        WHEN pm.precio_mayorista_promedio > 0 THEN
            CAST(((v.precio_venta_promedio - pm.precio_mayorista_promedio) / pm.precio_mayorista_promedio * 100) AS DECIMAL(10, 2))
        ELSE NULL
    END AS porcentaje_margen
FROM ventas_por_producto v
    LEFT JOIN precios_mayoristas pm ON v.product_id = pm.product_id
ORDER BY ganancia_total DESC
LIMIT 15;

-- ============================================================================
-- 8. TENDENCIA DE VENTAS POR MES CON CTE Y FUNCIONES DE VENTANA
-- ============================================================================
-- Demuestra: CTE, LAG(), funciones de ventana, cálculos de variación
--
-- Objetivo: Mostrar cómo cambian las ventas mes a mes (crecimiento o caída)
-- Insights: Identifica tendencias de crecimiento o caída en las ventas mensuales
--
-- Explicación:
-- - LAG(ingresos) OVER (ORDER BY periodo): Obtiene ingresos del MES ANTERIOR
-- - LAG() es una función de ventana que accede a la fila anterior
-- - diferencia = ingresos_mes_actual - ingresos_mes_anterior
-- - porcentaje_cambio = (diferencia / ingresos_mes_anterior) × 100
-- - DATE_FORMAT('%Y-%m'): Formato 2024-01 para ordenar correctamente
-- - DATE_FORMAT('%M %Y'): Formato legible "January 2024"

WITH ventas_mensuales AS (
    SELECT
        cal.anio,
        cal.mes,
        DATE_FORMAT(cal.fecha, '%Y-%m') AS periodo,
        DATE_FORMAT(cal.fecha, '%M %Y') AS mes_nombre,
        COUNT(fv.sale_id) AS total_ventas,
        CAST(SUM(fv.total_sale_amount) AS DECIMAL(12, 2)) AS ingresos
    FROM fact_ventas fv
        INNER JOIN dim_calendario cal ON fv.date_id = cal.date_id
    WHERE fv.is_return = FALSE
    GROUP BY cal.anio, cal.mes, DATE_FORMAT(cal.fecha, '%Y-%m'), DATE_FORMAT(cal.fecha, '%M %Y')
)
SELECT
    periodo,
    mes_nombre,
    total_ventas,
    ingresos,
    LAG(ingresos) OVER (ORDER BY periodo) AS ingresos_mes_anterior,
    CAST(ingresos - LAG(ingresos) OVER (ORDER BY periodo) AS DECIMAL(12, 2)) AS diferencia,
    CASE
        WHEN LAG(ingresos) OVER (ORDER BY periodo) IS NOT NULL THEN
            CAST(((ingresos - LAG(ingresos) OVER (ORDER BY periodo)) / LAG(ingresos) OVER (ORDER BY periodo) * 100) AS DECIMAL(10, 2))
        ELSE NULL
    END AS porcentaje_cambio
FROM ventas_mensuales
ORDER BY periodo;

-- ============================================================================
-- 9. ANÁLISIS DE PRODUCTOS CON PÉRDIDAS
-- ============================================================================
-- Demuestra: LEFT JOIN, COALESCE, HAVING, filtros con agregaciones
--
-- Objetivo: Estima unidades perdidas por mermas/desperdicios según tasa de pérdida
-- Insights: Identifica productos perecederos o frágiles que generan mermas significativas
--
-- Explicación:
-- - LEFT JOIN dim_perdidas: Incluye productos sin tasa de pérdida registrada
-- - COALESCE(AVG(dl.loss_rate), 0): Si no tiene pérdida, usa 0
-- - unidades_perdidas_estimadas = unidades_vendidas × (tasa_perdida / 100)
-- - HAVING filtra DESPUÉS de GROUP BY (solo productos con pérdidas > 0)
-- - Diferencia WHERE vs HAVING: WHERE filtra filas, HAVING filtra grupos

SELECT
    p.item_name AS producto,
    c.category_name AS categoria,
    COUNT(fv.sale_id) AS total_ventas,
    SUM(fv.quantity_sold) AS unidades_vendidas,
    CAST(COALESCE(AVG(dl.loss_rate), 0) AS DECIMAL(5, 2)) AS tasa_perdida_promedio,
    CAST(SUM(fv.quantity_sold) * COALESCE(AVG(dl.loss_rate), 0) / 100 AS DECIMAL(10, 2)) AS unidades_perdidas_estimadas,
    CAST(SUM(fv.total_sale_amount) AS DECIMAL(12, 2)) AS ingresos_totales
FROM fact_ventas fv
    INNER JOIN dim_productos p ON fv.product_id = p.product_id
    INNER JOIN dim_categorias c ON p.category_id = c.category_id
    LEFT JOIN dim_perdidas dl ON p.product_id = dl.product_id
WHERE fv.is_return = FALSE
GROUP BY p.product_id, p.item_name, c.category_name
-- HAVING COALESCE(AVG(dl.loss_rate), 0) > 0
ORDER BY tasa_perdida_promedio DESC, unidades_perdidas_estimadas DESC
LIMIT 15;

-- ============================================================================
-- 10. ANÁLISIS DE VENTAS POR TRIMESTRE CON ROW_NUMBER
-- ============================================================================
-- Demuestra: ROW_NUMBER(), PARTITION BY, múltiples funciones de ventana
--
-- Objetivo: Ranking de categorías por ingresos en cada trimestre
-- Insights: Identifica qué categorías dominan cada trimestre del año
--
-- Explicación:
-- - ROW_NUMBER() OVER (...): Asigna números únicos sin empates (1, 2, 3, 4...)
-- - RANK() permite empates (1, 2, 2, 4...), ROW_NUMBER no (1, 2, 3, 4...)
-- - PARTITION BY cal.anio, cal.trimestre: Reinicia ranking cada trimestre
-- - ranking_trimestre reinicia en cada Q1, Q2, Q3, Q4
-- - ranking_general es único en toda la tabla

SELECT
    cal.anio AS año,
    cal.trimestre,
    c.category_name AS categoria,
    COUNT(fv.sale_id) AS total_ventas,
    CAST(SUM(fv.total_sale_amount) AS DECIMAL(12, 2)) AS ingresos,
    ROW_NUMBER() OVER (PARTITION BY cal.anio, cal.trimestre ORDER BY SUM(fv.total_sale_amount) DESC) AS ranking_trimestre,
    RANK() OVER (ORDER BY SUM(fv.total_sale_amount) DESC) AS ranking_general
FROM fact_ventas fv
    INNER JOIN dim_calendario cal ON fv.date_id = cal.date_id
    INNER JOIN dim_productos p ON fv.product_id = p.product_id
    INNER JOIN dim_categorias c ON p.category_id = c.category_id
WHERE fv.is_return = FALSE
GROUP BY cal.anio, cal.trimestre, c.category_id, c.category_name
ORDER BY cal.anio, cal.trimestre, ranking_trimestre;

-- ============================================================================
-- 11. PRODUCTOS CON VENTAS CONSISTENTES (CTE MÚLTIPLES)
-- ============================================================================
-- Demuestra: CTEs múltiples, STDDEV, varianza, análisis estadístico
--
-- Objetivo: Identifica productos con ventas estables (poca variación día a día)
-- Insights: Productos con desviación baja = ventas predecibles (ej: leche)
--           Productos con desviación alta = ventas irregulares (ej: estacionales)
--
-- Explicación:
-- - CTE ventas_diarias: Calcula ingresos por producto por día
-- - CTE estadisticas_producto: Usa el CTE anterior para calcular STDDEV
-- - STDDEV (desviación estándar): Mide cuánto varían las ventas diarias
-- - nivel_consistencia clasifica según desviación vs promedio:
--   * desviacion = 0 → "Muy consistente"
--   * desviacion < promedio × 0.5 → "Consistente"
--   * desviacion < promedio → "Moderado"
--   * desviacion >= promedio → "Volátil"

WITH ventas_diarias AS (
    SELECT
        p.product_id,
        p.item_name,
        cal.fecha,
        COUNT(fv.sale_id) AS ventas_dia,
        CAST(SUM(fv.total_sale_amount) AS DECIMAL(10, 2)) AS ingresos_dia
    FROM fact_ventas fv
        INNER JOIN dim_productos p ON fv.product_id = p.product_id
        INNER JOIN dim_calendario cal ON fv.date_id = cal.date_id
    WHERE fv.is_return = FALSE
    GROUP BY p.product_id, p.item_name, cal.fecha
),
estadisticas_producto AS (
    SELECT
        product_id,
        item_name,
        COUNT(DISTINCT fecha) AS dias_con_ventas,
        CAST(AVG(ingresos_dia) AS DECIMAL(10, 2)) AS ingreso_diario_promedio,
        CAST(STDDEV(ingresos_dia) AS DECIMAL(10, 2)) AS desviacion_estandar,
        CAST(SUM(ingresos_dia) AS DECIMAL(12, 2)) AS ingresos_totales
    FROM ventas_diarias
    GROUP BY product_id, item_name
)
SELECT
    item_name AS producto,
    dias_con_ventas,
    ingreso_diario_promedio,
    desviacion_estandar,
    ingresos_totales,
    CASE
        WHEN desviacion_estandar = 0 THEN 'Muy consistente'
        WHEN desviacion_estandar < ingreso_diario_promedio * 0.5 THEN 'Consistente'
        WHEN desviacion_estandar < ingreso_diario_promedio THEN 'Moderado'
        ELSE 'Volátil'
    END AS nivel_consistencia
FROM estadisticas_producto
WHERE dias_con_ventas >= 10
ORDER BY ingresos_totales DESC
LIMIT 20;

-- ============================================================================
-- 12. CROSS JOIN - MATRIZ DE DISPONIBILIDAD
-- ============================================================================
-- Demuestra: CROSS JOIN, LEFT JOIN, agregaciones con CASE
--
-- Objetivo: Crea matriz mostrando qué categorías tienen ventas en cada periodo del día
-- Insights: Identifica gaps de disponibilidad o periodos sin ventas
--
-- Explicación:
-- - CROSS JOIN: Producto cartesiano (todas categorías × todos periodos)
-- - Genera TODAS las combinaciones posibles, incluso sin ventas
-- - LEFT JOIN fact_ventas: Trae ventas si existen, NULL si no hay
-- - CASE COUNT > 0: Etiqueta como "Sí" o "No" si hay ventas
-- - ORDER BY con CASE personalizado: Ordena Mañana(1), Tarde(2), Noche(3)

SELECT
    c.category_name AS categoria,
    t.periodo_dia,
    COUNT(fv.sale_id) AS ventas_realizadas,
    CASE
        WHEN COUNT(fv.sale_id) > 0 THEN 'Sí'
        ELSE 'No'
    END AS tiene_ventas
FROM dim_categorias c
    CROSS JOIN dim_tiempo t
    LEFT JOIN fact_ventas fv ON fv.time_id = t.time_id
    LEFT JOIN dim_productos p ON fv.product_id = p.product_id AND p.category_id = c.category_id
WHERE t.periodo_dia IN ('Mañana', 'Tarde', 'Noche')
GROUP BY c.category_id, c.category_name, t.periodo_dia
ORDER BY c.category_name,
    CASE t.periodo_dia
        WHEN 'Mañana' THEN 1
        WHEN 'Tarde' THEN 2
        WHEN 'Noche' THEN 3
    END;

-- ============================================================================
-- 13. ANÁLISIS DE DEVOLUCIONES
-- ============================================================================
-- Demuestra: filtros con BOOLEAN, subconsultas, porcentajes
--
-- Objetivo: Calcula porcentaje de devolución por producto
-- Insights: Identifica productos problemáticos con alta tasa de devolución
--
-- Explicación:
-- - COUNT(CASE WHEN is_return = FALSE THEN 1 END): Conteo condicional de ventas
-- - COUNT(CASE WHEN is_return = TRUE THEN 1 END): Conteo condicional de devoluciones
-- - porcentaje_devolucion = (devoluciones / total) × 100
-- - HAVING devoluciones > 0: Filtra solo productos con al menos 1 devolución
-- - COUNT dentro de CASE solo cuenta filas que cumplen condición

SELECT
    c.category_name AS categoria,
    p.item_name AS producto,
    COUNT(CASE WHEN fv.is_return = FALSE THEN 1 END) AS ventas_exitosas,
    COUNT(CASE WHEN fv.is_return = TRUE THEN 1 END) AS devoluciones,
    COUNT(fv.sale_id) AS total_transacciones,
    CAST(COUNT(CASE WHEN fv.is_return = TRUE THEN 1 END) * 100.0 / COUNT(fv.sale_id) AS DECIMAL(5, 2)) AS porcentaje_devolucion
FROM fact_ventas fv
    INNER JOIN dim_productos p ON fv.product_id = p.product_id
    INNER JOIN dim_categorias c ON p.category_id = c.category_id
GROUP BY c.category_name, p.product_id, p.item_name
HAVING COUNT(CASE WHEN fv.is_return = TRUE THEN 1 END) > 0
ORDER BY porcentaje_devolucion DESC, devoluciones DESC
LIMIT 15;

-- ============================================================================
-- 14. PRODUCTOS SIN VENTAS EN CIERTOS PERÍODOS
-- ============================================================================
-- Demuestra: NOT EXISTS, subconsultas correlacionadas, RIGHT JOIN
--
-- Objetivo: Encuentra productos con ventas históricas pero NO en el mes actual
-- Insights: Productos que solían venderse pero dejaron de moverse - revisar inventario
--
-- Explicación:
-- - NOT EXISTS: Verifica que NO exista ningún registro que cumpla la condición
-- - Subconsulta correlacionada: Usa p.product_id de la consulta externa
-- - MONTH(CURRENT_DATE): Obtiene el mes actual del sistema
-- - LEFT JOIN fact_ventas: Trae todas las ventas históricas del producto
-- - WHERE NOT EXISTS filtra productos SIN ventas en el mes actual

SELECT
    p.item_name AS producto,
    c.category_name AS categoria,
    COUNT(fv.sale_id) AS ventas_totales,
    MONTH(CURRENT_DATE) AS mes_sin_ventas,
    MONTHNAME(CURRENT_DATE) AS nombre_mes_sin_ventas
FROM dim_productos p
    INNER JOIN dim_categorias c ON p.category_id = c.category_id
    LEFT JOIN fact_ventas fv ON p.product_id = fv.product_id AND fv.is_return = FALSE
WHERE NOT EXISTS (
    SELECT 1
    FROM fact_ventas fv2
        INNER JOIN dim_calendario cal ON fv2.date_id = cal.date_id
    WHERE fv2.product_id = p.product_id
        AND cal.mes = MONTH(CURRENT_DATE)
        AND fv2.is_return = FALSE
)
GROUP BY p.product_id, p.item_name, c.category_name
ORDER BY ventas_totales DESC
LIMIT 20;

-- ============================================================================
-- 15. RESUMEN EJECUTIVO CON MÚLTIPLES CTEs
-- ============================================================================
-- Demuestra: CTEs múltiples, UNION ALL, agregaciones complejas
--
-- Objetivo: Genera reporte con métricas clave en formato vertical (una métrica por fila)
-- Insights: Dashboard ejecutivo con KPIs principales del negocio
--
-- Explicación:
-- - UNION ALL: Combina resultados de múltiples SELECT (NO elimina duplicados)
-- - UNION (sin ALL): Eliminaría duplicados (más lento, innecesario aquí)
-- - CAST(... AS CHAR): Convierte números a texto para uniformar columnas
-- - Formato vertical facilita presentación en dashboards y reportes
-- - Cada SELECT genera una fila con métrica y su valor
-- - is_return = TRUE cuenta devoluciones, FALSE cuenta ventas

WITH resumen_ventas AS (
    SELECT
        'Total ventas' AS metrica,
        CAST(COUNT(sale_id) AS CHAR) AS valor
    FROM fact_ventas
    WHERE is_return = FALSE

    UNION ALL

    SELECT
        'Ingresos totales (RMB)',
        CAST(CAST(SUM(total_sale_amount) AS DECIMAL(12, 2)) AS CHAR)
    FROM fact_ventas
    WHERE is_return = FALSE

    UNION ALL

    SELECT
        'Venta promedio (RMB)',
        CAST(CAST(AVG(total_sale_amount) AS DECIMAL(10, 2)) AS CHAR)
    FROM fact_ventas
    WHERE is_return = FALSE

    UNION ALL

    SELECT
        'Productos únicos',
        CAST(COUNT(DISTINCT product_id) AS CHAR)
    FROM fact_ventas

    UNION ALL

    SELECT
        'Tasa de devolución (%)',
        CAST(CAST(COUNT(CASE WHEN is_return = TRUE THEN 1 END) * 100.0 / COUNT(*) AS DECIMAL(5, 2)) AS CHAR)
    FROM fact_ventas
)
SELECT * FROM resumen_ventas;
