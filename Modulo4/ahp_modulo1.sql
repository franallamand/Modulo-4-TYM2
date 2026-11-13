-- =====================================================================
-- Módulo 4 - Técnicas y Herramientas Modernas II (Ing. Industrial, UNCuyo)
-- Selección del tema del proyecto final (AHP del Módulo 1) resuelta con SQL
--
-- Qué hace: guarda en tablas los juicios por pares del Módulo 1 y calcula
-- con vistas SQL los pesos, la consistencia, las prioridades, el ranking y
-- la sensibilidad. Si se cambia un juicio, todo se recalcula solo.
--
-- Datos: son los MISMOS juicios de la planilla
-- "AHP_Optimizacion_Energia_IA_Modulo_1.xlsx" (Módulo 1). No se agregó
-- ningún dato nuevo.
-- Método: vector propio por el método de las potencias, 25 iteraciones,
-- igual que la planilla del Módulo 1.
-- Requiere SQLite 3.25 o superior (funciones de ventana).
-- =====================================================================

PRAGMA foreign_keys = ON;

-- Para poder volver a ejecutar el script desde cero
DROP VIEW IF EXISTS v_peso_critico;
DROP VIEW IF EXISTS v_escenarios;
DROP VIEW IF EXISTS v_escenarios_puntaje;
DROP VIEW IF EXISTS v_pesos_escenario;
DROP VIEW IF EXISTS v_aporte;
DROP VIEW IF EXISTS v_ranking;
DROP VIEW IF EXISTS v_puntaje_global;
DROP VIEW IF EXISTS v_prioridad_local;
DROP VIEW IF EXISTS v_consistencia_temas;
DROP VIEW IF EXISTS v_vector_temas;
DROP VIEW IF EXISTS v_matriz_temas_ancha;
DROP VIEW IF EXISTS v_matriz_temas;
DROP VIEW IF EXISTS v_consistencia_criterios;
DROP VIEW IF EXISTS v_pesos_criterios;
DROP VIEW IF EXISTS v_vector_criterios;
DROP VIEW IF EXISTS v_matriz_criterios_ancha;
DROP VIEW IF EXISTS v_matriz_criterios;
DROP TABLE IF EXISTS escenario_peso;
DROP TABLE IF EXISTS escenario;
DROP TABLE IF EXISTS comparacion_temas;
DROP TABLE IF EXISTS comparacion_criterios;
DROP TABLE IF EXISTS indice_aleatorio;
DROP TABLE IF EXISTS tema;
DROP TABLE IF EXISTS criterio;

-- ---------------------------------------------------------------------
-- 1. TABLAS (datos y juicios)
-- ---------------------------------------------------------------------

CREATE TABLE criterio (
  id_criterio INTEGER PRIMARY KEY,
  nombre      TEXT NOT NULL UNIQUE,
  descripcion TEXT NOT NULL
);

CREATE TABLE tema (
  id_tema     INTEGER PRIMARY KEY,
  codigo      TEXT NOT NULL UNIQUE,      -- A, B, C
  nombre      TEXT NOT NULL UNIQUE,
  descripcion TEXT NOT NULL
);

-- Solo se carga el triángulo superior de la matriz (id_fila < id_col).
-- 'prefiere' dice quién gana: 'fila', 'col' o 'igual'. valor es 1 a 9 (Saaty).
-- Los recíprocos y la diagonal los genera la vista v_matriz_criterios.
CREATE TABLE comparacion_criterios (
  id_fila  INTEGER NOT NULL REFERENCES criterio(id_criterio),
  id_col   INTEGER NOT NULL REFERENCES criterio(id_criterio),
  prefiere TEXT    NOT NULL CHECK (prefiere IN ('fila','col','igual')),
  valor    INTEGER NOT NULL CHECK (valor BETWEEN 1 AND 9),
  PRIMARY KEY (id_fila, id_col),
  CHECK (id_fila < id_col),
  CHECK (prefiere <> 'igual' OR valor = 1)
);

-- Comparación de los 3 temas respecto a cada criterio.
CREATE TABLE comparacion_temas (
  id_criterio INTEGER NOT NULL REFERENCES criterio(id_criterio),
  id_fila     INTEGER NOT NULL REFERENCES tema(id_tema),
  id_col      INTEGER NOT NULL REFERENCES tema(id_tema),
  prefiere    TEXT    NOT NULL CHECK (prefiere IN ('fila','col','igual')),
  valor       INTEGER NOT NULL CHECK (valor BETWEEN 1 AND 9),
  PRIMARY KEY (id_criterio, id_fila, id_col),
  CHECK (id_fila < id_col),
  CHECK (prefiere <> 'igual' OR valor = 1)
);

-- Índice de consistencia aleatorio de Saaty (hoja "Inicio" de la planilla)
CREATE TABLE indice_aleatorio (
  n  INTEGER PRIMARY KEY,
  ri REAL NOT NULL
);

-- Escenarios de sensibilidad (los mismos 5 de la hoja "Sensibilidad").
-- El escenario "Base" no se guarda: sale de los pesos calculados por el AHP.
CREATE TABLE escenario (
  id_escenario INTEGER PRIMARY KEY,
  nombre       TEXT NOT NULL UNIQUE
);

CREATE TABLE escenario_peso (
  id_escenario INTEGER NOT NULL REFERENCES escenario(id_escenario),
  id_criterio  INTEGER NOT NULL REFERENCES criterio(id_criterio),
  peso         REAL    NOT NULL CHECK (peso >= 0),
  PRIMARY KEY (id_escenario, id_criterio)
);

-- ---------------------------------------------------------------------
-- 2. DATOS (tomados de la planilla del Módulo 1)
-- ---------------------------------------------------------------------

INSERT INTO criterio VALUES
  (1, 'Pertinencia', 'Alineación con el perfil de Ing. Industrial y etapa CHECK de ISO 50001'),
  (2, 'Datos',       'Disponibilidad de información, series temporales y datos benchmark'),
  (3, 'Viabilidad',  'Factibilidad técnica, riesgo operativo y requerimientos de cómputo'),
  (4, 'Impacto',     'Aporte de innovación tecnológica, Green AI y explicabilidad (XAI)'),
  (5, 'Caso_real',   'Factibilidad temporal de ejecución en el plazo previsto de 8 a 10 meses');

INSERT INTO tema VALUES
  (1, 'A', 'Prediccion_ML',     'Predicción de consumo energético industrial con Machine Learning'),
  (2, 'B', 'Setpoints_RL',      'Optimización de setpoints de proceso con Reinforcement Learning'),
  (3, 'C', 'Anomalias_GreenAI', 'Detección de anomalías energéticas con IA y enfoque Green AI');

INSERT INTO indice_aleatorio VALUES (1, 0), (2, 0), (3, 0.58), (4, 0.90), (5, 1.12);

-- Criterios (id_fila, id_col, prefiere, valor)
INSERT INTO comparacion_criterios VALUES
  (1, 2, 'igual', 1),   -- Pertinencia = Datos
  (1, 3, 'igual', 1),   -- Pertinencia = Viabilidad
  (1, 4, 'fila',  2),   -- Pertinencia > Impacto (x2)
  (1, 5, 'fila',  2),   -- Pertinencia > Caso_real (x2)
  (2, 3, 'igual', 1),   -- Datos = Viabilidad
  (2, 4, 'igual', 1),   -- Datos = Impacto
  (2, 5, 'igual', 1),   -- Datos = Caso_real
  (3, 4, 'fila',  2),   -- Viabilidad > Impacto (x2)
  (3, 5, 'fila',  2),   -- Viabilidad > Caso_real (x2)
  (4, 5, 'igual', 1);   -- Impacto = Caso_real

-- Temas por criterio (id_criterio, id_fila, id_col, prefiere, valor)
INSERT INTO comparacion_temas VALUES
  -- Pertinencia
  (1, 1, 2, 'fila', 2),  -- A > B (x2)
  (1, 1, 3, 'col',  3),  -- C > A (x3)
  (1, 2, 3, 'col',  5),  -- C > B (x5)
  -- Datos
  (2, 1, 2, 'fila', 3),  -- A > B (x3)
  (2, 1, 3, 'igual',1),  -- A = C
  (2, 2, 3, 'col',  3),  -- C > B (x3)
  -- Viabilidad
  (3, 1, 2, 'fila', 4),  -- A > B (x4)
  (3, 1, 3, 'igual',1),  -- A = C
  (3, 2, 3, 'col',  4),  -- C > B (x4)
  -- Impacto
  (4, 1, 2, 'col',  4),  -- B > A (x4)
  (4, 1, 3, 'col',  4),  -- C > A (x4)
  (4, 2, 3, 'igual',1),  -- B = C
  -- Caso_real
  (5, 1, 2, 'fila', 3),  -- A > B (x3)
  (5, 1, 3, 'igual',1),  -- A = C
  (5, 2, 3, 'col',  3);  -- C > B (x3)

INSERT INTO escenario VALUES
  (1, 'Viabilidad baja'), (2, 'Pesos iguales'), (3, 'Impacto alto'),
  (4, 'Caso real alto'),  (5, 'Sin Viabilidad');

-- Pesos por escenario (orden de criterios: 1 Pertinencia, 2 Datos, 3 Viabilidad, 4 Impacto, 5 Caso_real)
INSERT INTO escenario_peso VALUES
  (1,1,0.25),(1,2,0.25),(1,3,0.30),(1,4,0.10),(1,5,0.10),
  (2,1,0.20),(2,2,0.20),(2,3,0.20),(2,4,0.20),(2,5,0.20),
  (3,1,0.15),(3,2,0.15),(3,3,0.30),(3,4,0.30),(3,5,0.10),
  (4,1,0.15),(4,2,0.15),(4,3,0.30),(4,4,0.10),(4,5,0.30),
  (5,1,0.30),(5,2,0.30),(5,3,0.00),(5,4,0.20),(5,5,0.20);

-- ---------------------------------------------------------------------
-- 3. VISTAS: PESOS DE LOS CRITERIOS
-- ---------------------------------------------------------------------

-- Matriz completa (fila i, columna j, valor a). Los recíprocos y la diagonal se generan acá.
CREATE VIEW v_matriz_criterios AS
WITH tri AS (
  SELECT id_fila AS i, id_col AS j,
         CASE prefiere WHEN 'fila' THEN valor * 1.0
                       WHEN 'col'  THEN 1.0 / valor
                       ELSE 1.0 END AS a
  FROM comparacion_criterios
)
SELECT i, j, a FROM tri
UNION ALL SELECT j, i, 1.0 / a FROM tri
UNION ALL SELECT id_criterio, id_criterio, 1.0 FROM criterio;

-- La matriz en una sola fila (a11..a55) y la suma de cada columna (c1..c5).
-- Hace falta para poder iterar el método de las potencias con una consulta recursiva.
CREATE VIEW v_matriz_criterios_ancha AS
SELECT
  SUM(CASE WHEN i = 1 AND j = 1 THEN a END) AS a11,
  SUM(CASE WHEN i = 1 AND j = 2 THEN a END) AS a12,
  SUM(CASE WHEN i = 1 AND j = 3 THEN a END) AS a13,
  SUM(CASE WHEN i = 1 AND j = 4 THEN a END) AS a14,
  SUM(CASE WHEN i = 1 AND j = 5 THEN a END) AS a15,
  SUM(CASE WHEN i = 2 AND j = 1 THEN a END) AS a21,
  SUM(CASE WHEN i = 2 AND j = 2 THEN a END) AS a22,
  SUM(CASE WHEN i = 2 AND j = 3 THEN a END) AS a23,
  SUM(CASE WHEN i = 2 AND j = 4 THEN a END) AS a24,
  SUM(CASE WHEN i = 2 AND j = 5 THEN a END) AS a25,
  SUM(CASE WHEN i = 3 AND j = 1 THEN a END) AS a31,
  SUM(CASE WHEN i = 3 AND j = 2 THEN a END) AS a32,
  SUM(CASE WHEN i = 3 AND j = 3 THEN a END) AS a33,
  SUM(CASE WHEN i = 3 AND j = 4 THEN a END) AS a34,
  SUM(CASE WHEN i = 3 AND j = 5 THEN a END) AS a35,
  SUM(CASE WHEN i = 4 AND j = 1 THEN a END) AS a41,
  SUM(CASE WHEN i = 4 AND j = 2 THEN a END) AS a42,
  SUM(CASE WHEN i = 4 AND j = 3 THEN a END) AS a43,
  SUM(CASE WHEN i = 4 AND j = 4 THEN a END) AS a44,
  SUM(CASE WHEN i = 4 AND j = 5 THEN a END) AS a45,
  SUM(CASE WHEN i = 5 AND j = 1 THEN a END) AS a51,
  SUM(CASE WHEN i = 5 AND j = 2 THEN a END) AS a52,
  SUM(CASE WHEN i = 5 AND j = 3 THEN a END) AS a53,
  SUM(CASE WHEN i = 5 AND j = 4 THEN a END) AS a54,
  SUM(CASE WHEN i = 5 AND j = 5 THEN a END) AS a55,
  SUM(CASE WHEN j = 1 THEN a END) AS c1,
  SUM(CASE WHEN j = 2 THEN a END) AS c2,
  SUM(CASE WHEN j = 3 THEN a END) AS c3,
  SUM(CASE WHEN j = 4 THEN a END) AS c4,
  SUM(CASE WHEN j = 5 THEN a END) AS c5
FROM v_matriz_criterios;

-- Método de las potencias: w(k+1) = A·w(k) / (suma de columnas · w(k)), 25 iteraciones
CREATE VIEW v_vector_criterios AS
WITH RECURSIVE it(k, w1, w2, w3, w4, w5) AS (
  SELECT 0, 1.0/5, 1.0/5, 1.0/5, 1.0/5, 1.0/5
  UNION ALL
  SELECT it.k + 1,
    (m.a11*it.w1 + m.a12*it.w2 + m.a13*it.w3 + m.a14*it.w4 + m.a15*it.w5) / (m.c1*it.w1 + m.c2*it.w2 + m.c3*it.w3 + m.c4*it.w4 + m.c5*it.w5),
    (m.a21*it.w1 + m.a22*it.w2 + m.a23*it.w3 + m.a24*it.w4 + m.a25*it.w5) / (m.c1*it.w1 + m.c2*it.w2 + m.c3*it.w3 + m.c4*it.w4 + m.c5*it.w5),
    (m.a31*it.w1 + m.a32*it.w2 + m.a33*it.w3 + m.a34*it.w4 + m.a35*it.w5) / (m.c1*it.w1 + m.c2*it.w2 + m.c3*it.w3 + m.c4*it.w4 + m.c5*it.w5),
    (m.a41*it.w1 + m.a42*it.w2 + m.a43*it.w3 + m.a44*it.w4 + m.a45*it.w5) / (m.c1*it.w1 + m.c2*it.w2 + m.c3*it.w3 + m.c4*it.w4 + m.c5*it.w5),
    (m.a51*it.w1 + m.a52*it.w2 + m.a53*it.w3 + m.a54*it.w4 + m.a55*it.w5) / (m.c1*it.w1 + m.c2*it.w2 + m.c3*it.w3 + m.c4*it.w4 + m.c5*it.w5)
  FROM it, v_matriz_criterios_ancha AS m
  WHERE it.k < 25
)
SELECT w1, w2, w3, w4, w5 FROM it WHERE k = 25;

CREATE VIEW v_pesos_criterios AS
WITH w AS (
  SELECT 1 AS id, w1 AS peso FROM v_vector_criterios
  UNION ALL
  SELECT 2 AS id, w2 AS peso FROM v_vector_criterios
  UNION ALL
  SELECT 3 AS id, w3 AS peso FROM v_vector_criterios
  UNION ALL
  SELECT 4 AS id, w4 AS peso FROM v_vector_criterios
  UNION ALL
  SELECT 5 AS id, w5 AS peso FROM v_vector_criterios
)
SELECT c.id_criterio, c.nombre, w.peso,
       RANK() OVER (ORDER BY ROUND(w.peso, 6) DESC) AS posicion
FROM w JOIN criterio c ON c.id_criterio = w.id;

-- Consistencia: lambda_max, CI = (lambda_max - n)/(n - 1), CR = CI / RI (debe ser < 0,10)
CREATE VIEW v_consistencia_criterios AS
SELECT m.c1*v.w1 + m.c2*v.w2 + m.c3*v.w3 + m.c4*v.w4 + m.c5*v.w5 AS lambda_max,
       (m.c1*v.w1 + m.c2*v.w2 + m.c3*v.w3 + m.c4*v.w4 + m.c5*v.w5 - 5) / 4.0 AS ci,
       ri.ri AS ri,
       ((m.c1*v.w1 + m.c2*v.w2 + m.c3*v.w3 + m.c4*v.w4 + m.c5*v.w5 - 5) / 4.0) / ri.ri AS cr,
       CASE WHEN ((m.c1*v.w1 + m.c2*v.w2 + m.c3*v.w3 + m.c4*v.w4 + m.c5*v.w5 - 5) / 4.0) / ri.ri < 0.10 THEN 'OK (CR < 10 %)' ELSE 'REVISAR' END AS estado
FROM v_vector_criterios v, v_matriz_criterios_ancha m, indice_aleatorio ri
WHERE ri.n = 5;

-- ---------------------------------------------------------------------
-- 4. VISTAS: PRIORIDADES LOCALES DE LOS TEMAS (una matriz de 3x3 por criterio)
-- ---------------------------------------------------------------------

CREATE VIEW v_matriz_temas AS
WITH tri AS (
  SELECT id_criterio, id_fila AS i, id_col AS j,
         CASE prefiere WHEN 'fila' THEN valor * 1.0
                       WHEN 'col'  THEN 1.0 / valor
                       ELSE 1.0 END AS a
  FROM comparacion_temas
)
SELECT id_criterio, i, j, a FROM tri
UNION ALL SELECT id_criterio, j, i, 1.0 / a FROM tri
UNION ALL SELECT c.id_criterio, t.id_tema, t.id_tema, 1.0 FROM criterio c, tema t;

CREATE VIEW v_matriz_temas_ancha AS
SELECT id_criterio,
  SUM(CASE WHEN i = 1 AND j = 1 THEN a END) AS a11,
  SUM(CASE WHEN i = 1 AND j = 2 THEN a END) AS a12,
  SUM(CASE WHEN i = 1 AND j = 3 THEN a END) AS a13,
  SUM(CASE WHEN i = 2 AND j = 1 THEN a END) AS a21,
  SUM(CASE WHEN i = 2 AND j = 2 THEN a END) AS a22,
  SUM(CASE WHEN i = 2 AND j = 3 THEN a END) AS a23,
  SUM(CASE WHEN i = 3 AND j = 1 THEN a END) AS a31,
  SUM(CASE WHEN i = 3 AND j = 2 THEN a END) AS a32,
  SUM(CASE WHEN i = 3 AND j = 3 THEN a END) AS a33,
  SUM(CASE WHEN j = 1 THEN a END) AS c1,
  SUM(CASE WHEN j = 2 THEN a END) AS c2,
  SUM(CASE WHEN j = 3 THEN a END) AS c3
FROM v_matriz_temas
GROUP BY id_criterio;

CREATE VIEW v_vector_temas AS
WITH RECURSIVE it(id_criterio, k, w1, w2, w3) AS (
  SELECT id_criterio, 0, 1.0/3, 1.0/3, 1.0/3 FROM v_matriz_temas_ancha
  UNION ALL
  SELECT it.id_criterio, it.k + 1,
    (m.a11*it.w1 + m.a12*it.w2 + m.a13*it.w3) / (m.c1*it.w1 + m.c2*it.w2 + m.c3*it.w3),
    (m.a21*it.w1 + m.a22*it.w2 + m.a23*it.w3) / (m.c1*it.w1 + m.c2*it.w2 + m.c3*it.w3),
    (m.a31*it.w1 + m.a32*it.w2 + m.a33*it.w3) / (m.c1*it.w1 + m.c2*it.w2 + m.c3*it.w3)
  FROM it JOIN v_matriz_temas_ancha AS m ON m.id_criterio = it.id_criterio
  WHERE it.k < 25
)
SELECT id_criterio, w1, w2, w3 FROM it WHERE k = 25;

CREATE VIEW v_prioridad_local AS
WITH w AS (
  SELECT id_criterio, 1 AS id, w1 AS peso FROM v_vector_temas
  UNION ALL
  SELECT id_criterio, 2 AS id, w2 AS peso FROM v_vector_temas
  UNION ALL
  SELECT id_criterio, 3 AS id, w3 AS peso FROM v_vector_temas
)
SELECT w.id_criterio, c.nombre AS criterio, w.id AS id_tema, t.codigo AS tema, w.peso AS prioridad
FROM w
JOIN criterio c ON c.id_criterio = w.id_criterio
JOIN tema t ON t.id_tema = w.id;

CREATE VIEW v_consistencia_temas AS
SELECT v.id_criterio, c.nombre AS criterio,
       m.c1*v.w1 + m.c2*v.w2 + m.c3*v.w3 AS lambda_max,
       (m.c1*v.w1 + m.c2*v.w2 + m.c3*v.w3 - 3) / 2.0 AS ci,
       ri.ri AS ri,
       ((m.c1*v.w1 + m.c2*v.w2 + m.c3*v.w3 - 3) / 2.0) / ri.ri AS cr
FROM v_vector_temas v
JOIN v_matriz_temas_ancha m ON m.id_criterio = v.id_criterio
JOIN criterio c ON c.id_criterio = v.id_criterio
JOIN indice_aleatorio ri ON ri.n = 3;

-- ---------------------------------------------------------------------
-- 5. VISTAS: RANKING FINAL
-- ---------------------------------------------------------------------

-- Puntaje global = suma de (peso del criterio x prioridad local del tema)
CREATE VIEW v_puntaje_global AS
SELECT t.id_tema, t.codigo, t.nombre, SUM(p.peso * l.prioridad) AS puntaje
FROM v_pesos_criterios p
JOIN v_prioridad_local l ON l.id_criterio = p.id_criterio
JOIN tema t ON t.id_tema = l.id_tema
GROUP BY t.id_tema, t.codigo, t.nombre;

CREATE VIEW v_ranking AS
SELECT RANK() OVER (ORDER BY puntaje DESC) AS posicion,
       id_tema, codigo, nombre,
       ROUND(100 * puntaje, 2) AS puntaje_pct,
       puntaje
FROM v_puntaje_global;

-- Cuánto aporta cada criterio al puntaje de cada tema (en puntos %)
CREATE VIEW v_aporte AS
SELECT t.codigo AS tema, c.nombre AS criterio,
       ROUND(100 * p.peso * l.prioridad, 2) AS aporte_pct
FROM v_pesos_criterios p
JOIN v_prioridad_local l ON l.id_criterio = p.id_criterio
JOIN tema t ON t.id_tema = l.id_tema
JOIN criterio c ON c.id_criterio = p.id_criterio;

-- ---------------------------------------------------------------------
-- 6. VISTAS: ANÁLISIS DE SENSIBILIDAD
-- ---------------------------------------------------------------------

-- Pesos de cada escenario (se normalizan para que sumen 1). El escenario 0 es el Base.
CREATE VIEW v_pesos_escenario AS
SELECT 0 AS id_escenario, 'Base (AHP)' AS escenario, id_criterio, peso
FROM v_pesos_criterios
UNION ALL
SELECT e.id_escenario, e.nombre, ep.id_criterio,
       ep.peso * 1.0 / SUM(ep.peso) OVER (PARTITION BY ep.id_escenario)
FROM escenario_peso ep
JOIN escenario e ON e.id_escenario = ep.id_escenario;

CREATE VIEW v_escenarios_puntaje AS
SELECT pe.id_escenario, pe.escenario, l.id_tema, SUM(pe.peso * l.prioridad) AS puntaje
FROM v_pesos_escenario pe
JOIN v_prioridad_local l ON l.id_criterio = pe.id_criterio
GROUP BY pe.id_escenario, pe.escenario, l.id_tema;

-- Una fila por escenario: puntaje de cada tema (%) y ganador
CREATE VIEW v_escenarios AS
WITH s AS (
  SELECT ep.id_escenario, ep.escenario, t.codigo, ep.puntaje,
         RANK() OVER (PARTITION BY ep.id_escenario ORDER BY ep.puntaje DESC) AS pos
  FROM v_escenarios_puntaje ep
  JOIN tema t ON t.id_tema = ep.id_tema
)
SELECT id_escenario, escenario,
       ROUND(100 * SUM(CASE WHEN codigo = 'A' THEN puntaje END), 2) AS puntaje_A,
       ROUND(100 * SUM(CASE WHEN codigo = 'B' THEN puntaje END), 2) AS puntaje_B,
       ROUND(100 * SUM(CASE WHEN codigo = 'C' THEN puntaje END), 2) AS puntaje_C,
       MAX(CASE WHEN pos = 1 THEN codigo END) AS ganador
FROM s
GROUP BY id_escenario, escenario;

-- Peso crítico: cuánto tendría que pesar un criterio para que otro tema supere al ganador
-- (los demás pesos se reajustan en proporción). Vacío = ese criterio no cambia al ganador.
CREATE VIEW v_peso_critico AS
WITH base AS (
  SELECT p.id_criterio, g.id_tema, g.codigo, p.peso AS w0, l.prioridad AS pl,
         (g.puntaje - p.peso * l.prioridad) / (1 - p.peso) AS r
  FROM v_pesos_criterios p
  JOIN v_prioridad_local l ON l.id_criterio = p.id_criterio
  JOIN v_puntaje_global g ON g.id_tema = l.id_tema
),
cruce AS (
  SELECT w.id_criterio, w.w0, x.codigo AS rival,
         (x.r - w.r) / NULLIF((w.pl - w.r) - (x.pl - x.r), 0) AS wc
  FROM base w
  JOIN v_ranking rk ON rk.id_tema = w.id_tema AND rk.posicion = 1
  JOIN base x ON x.id_criterio = w.id_criterio AND x.id_tema <> w.id_tema
)
SELECT c.nombre AS criterio,
       ROUND(100 * cr.w0, 1) AS peso_base_pct,
       cr.rival,
       CASE WHEN cr.wc >= 0 AND cr.wc < 0.999999 THEN ROUND(100 * cr.wc, 1) END AS peso_critico_pct,
       CASE WHEN cr.wc >= 0 AND cr.wc < 0.999999
            THEN CASE WHEN cr.wc > cr.w0 THEN 'si sube' ELSE 'si baja' END END AS sentido,
       CASE WHEN cr.wc >= 0 AND cr.wc < 0.999999
            THEN 'el rival supera al ganador' ELSE 'no cambia el ganador' END AS resultado
FROM cruce cr
JOIN criterio c ON c.id_criterio = cr.id_criterio;
