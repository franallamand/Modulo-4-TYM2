-- =====================================================================
-- Consultas de resultados (ejecutar después de ahp_modulo1.sql, o abrir
-- ahp_modulo1.db en DB Browser for SQLite -> pestaña "Ejecutar SQL").
-- Cada consulta se ejecuta por separado: seleccionarla y apretar Ctrl+Enter.
-- =====================================================================

-- 1. Pesos de los criterios (el Módulo 1 dio 25,48 / 19,69 / 25,48 / 14,68 / 14,68 %)
SELECT posicion, nombre AS criterio, ROUND(100 * peso, 2) AS peso_pct
FROM v_pesos_criterios
ORDER BY posicion, id_criterio;

-- 2. Consistencia de la matriz de criterios (el Módulo 1 dio CR = 1,73 %)
SELECT ROUND(lambda_max, 4) AS lambda_max, ROUND(ci, 4) AS ci, ri,
       ROUND(100 * cr, 2) AS cr_pct, estado
FROM v_consistencia_criterios;

-- 3. Consistencia de las matrices de temas (una por criterio)
SELECT criterio, ROUND(lambda_max, 4) AS lambda_max, ROUND(100 * cr, 2) AS cr_pct
FROM v_consistencia_temas
ORDER BY id_criterio;

-- 4. Prioridades locales de cada tema en cada criterio
SELECT criterio, tema, ROUND(prioridad, 4) AS prioridad
FROM v_prioridad_local
ORDER BY id_criterio, id_tema;

-- 5. Ranking final
SELECT posicion, codigo AS tema, nombre, puntaje_pct
FROM v_ranking
ORDER BY posicion;

-- 6. Aporte de cada criterio al puntaje de cada tema (puntos %)
SELECT tema, criterio, aporte_pct
FROM v_aporte
ORDER BY tema, criterio;

-- 7. Sensibilidad: ¿cambia el ganador si cambian los pesos?
SELECT escenario, puntaje_A, puntaje_B, puntaje_C, ganador
FROM v_escenarios
ORDER BY id_escenario;

-- 8. Peso crítico de cada criterio (vacío = no cambia al ganador)
SELECT criterio, peso_base_pct, rival, peso_critico_pct, sentido, resultado
FROM v_peso_critico
ORDER BY criterio, rival;

-- 9. Cambiar un juicio y ver cómo se recalcula todo (ejemplo, NO se guarda si se deshace):
--    "Impacto vs Caso_real" pasa de Igual a que Impacto gane x3.
-- BEGIN;
-- UPDATE comparacion_criterios SET prefiere = 'fila', valor = 3 WHERE id_fila = 4 AND id_col = 5;
-- SELECT posicion, codigo, puntaje_pct FROM v_ranking ORDER BY posicion;
-- ROLLBACK;
