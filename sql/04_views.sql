/* ============================================================================================================
   04_views.sql - Views de relatórios, correções geográficas e dashboards

   Consultas sobre pontos, poles, países que sediam corridas, aeroportos, cidades brasileiras, circuitos,
   dashboards e relatórios.
   ============================================================================================================ */

BEGIN;

CREATE EXTENSION IF NOT EXISTS cube;
CREATE EXTENSION IF NOT EXISTS earthdistance;

/* ------------------------------------------------------------------------------------------------------------
   Views de consultas de Fórmula 1
   ------------------------------------------------------------------------------------------------------------ */
-- View vw_pontos_pilotos_ano: existe para consultar pontos finais por piloto e ano; pega a última rodada de cada temporada.
CREATE OR REPLACE VIEW vw_pontos_pilotos_ano AS
SELECT
    se.year AS ano,
    d.given_name,
    d.family_name,
    (d.given_name || ' ' || d.family_name) AS piloto,
    s.points AS pontos
FROM driver_standings ds
JOIN standings s ON s.id = ds.standing_id
JOIN seasons se ON se.id = s.season_id
JOIN drivers d ON d.id = ds.driver_id
JOIN (
    SELECT season_id, MAX(round) AS ultima_rodada
    FROM standings
    GROUP BY season_id
) u ON u.season_id = s.season_id AND u.ultima_rodada = s.round;

-- View vw_poles_por_piloto: existe para contar poles por piloto; considera grid = 1 nos resultados.
CREATE OR REPLACE VIEW vw_poles_por_piloto AS
SELECT
    d.id AS driver_id,
    (d.given_name || ' ' || d.family_name) AS piloto,
    COUNT(*) AS quantidade_poles
FROM drivers d
JOIN results r ON d.id = r.driver_id
WHERE r.grid = 1
GROUP BY d.id, d.given_name, d.family_name;

-- View vw_paises_sede_corridas_cidades_aeroportos: existe para comparar países com circuitos, contando cidades e aeroportos cadastrados.
CREATE OR REPLACE VIEW vw_paises_sede_corridas_cidades_aeroportos AS
SELECT
    conta_cidades.nome,
    conta_cidades.nc AS quantidade_cidades,
    COALESCE(conta_aeroportos.na, 0) AS quantidade_aeroportos
FROM (
    SELECT co.name AS nome, COUNT(*) AS nc
    FROM countries co
    JOIN cities ci ON co.id = ci.country_id
    WHERE co.id IN (
        SELECT DISTINCT c.country_id
        FROM circuits cr
        JOIN cities c ON cr.city_id = c.id
    )
    GROUP BY co.name
) conta_cidades
LEFT JOIN (
    SELECT co.name AS nome, COUNT(a.id) AS na
    FROM countries co
    JOIN cities ci ON co.id = ci.country_id
    LEFT JOIN airports a ON a.city_id = ci.id
    WHERE co.id IN (
        SELECT DISTINCT c.country_id
        FROM circuits cr
        JOIN cities c ON cr.city_id = c.id
    )
    GROUP BY co.name
) conta_aeroportos ON conta_cidades.nome = conta_aeroportos.nome;

/* ------------------------------------------------------------------------------------------------------------
   Views de aeroportos, cidades e circuitos
   ------------------------------------------------------------------------------------------------------------ */
DROP MATERIALIZED VIEW IF EXISTS Aeroportos_Brasileiros CASCADE;
-- Materialized view Aeroportos_Brasileiros: existe para acelerar consultas repetidas de aeroportos brasileiros com cidade, país e continente.
CREATE MATERIALIZED VIEW Aeroportos_Brasileiros AS
SELECT
    a.name AS Aeroporto,
    a.latitude_deg AS Latitude,
    a.longitude_deg AS Longitude,
    p.name AS Pais,
    co.name AS Continente,
    ci.name AS Cidade,
    ci.population AS Populacao
FROM airports a
JOIN cities ci ON a.city_id = ci.id
JOIN countries p ON ci.country_id = p.id
JOIN continents co ON p.continent_id = co.id
WHERE p.name = 'Brazil';

DROP VIEW IF EXISTS Aeroportos_sem_cidades CASCADE;
-- View Aeroportos_sem_cidades: existe para listar aeroportos sem cidade vinculada, mas com coordenadas úteis para correção.
CREATE OR REPLACE VIEW Aeroportos_sem_cidades AS
SELECT
    a.id,
    a.name AS Aeroporto,
    a.latitude_deg AS Latitude,
    a.longitude_deg AS Longitude
FROM airports a
WHERE a.city_id IS NULL
  AND a.latitude_deg IS NOT NULL
  AND a.longitude_deg IS NOT NULL;

DROP VIEW IF EXISTS Cidades_brasileiras CASCADE;
-- View Cidades_brasileiras: existe para listar cidades brasileiras grandes com coordenadas; usada na correção de aeroportos próximos.
CREATE OR REPLACE VIEW Cidades_brasileiras AS
SELECT
    ci.id,
    ci.name AS Cidade,
    ci.population AS Populacao,
    ci.latitude AS Latitude,
    ci.longitude AS Longitude
FROM cities ci
JOIN countries p ON ci.country_id = p.id
WHERE p.name = 'Brazil'
  AND ci.population >= 100000
  AND ci.latitude IS NOT NULL
  AND ci.longitude IS NOT NULL;

DROP VIEW IF EXISTS Circuitos_completa CASCADE;
-- View Circuitos_completa: existe para exibir circuitos com cidade, país e continente já unidos.
CREATE OR REPLACE VIEW Circuitos_completa AS
SELECT
    cir.name AS Circuito,
    cir.lat AS Latitude,
    cir."long" AS Longitude,
    c.name AS Cidade,
    p.name AS Pais,
    p.code AS Codigo_Pais,
    co.name AS Continente
FROM circuits cir
LEFT JOIN cities c ON cir.city_id = c.id
LEFT JOIN countries p ON c.country_id = p.id
LEFT JOIN continents co ON p.continent_id = co.id;

DROP VIEW IF EXISTS Problemas_aeroportos CASCADE;
-- View Problemas_aeroportos: existe para encontrar aeroportos sem cidade que ficam próximos de cidades brasileiras grandes.
CREATE OR REPLACE VIEW Problemas_aeroportos AS
WITH distancias AS (
    SELECT
        a.id,
        a.name AS Aeroporto,
        a.latitude_deg AS Latitude,
        a.longitude_deg AS Longitude,
        c.id AS Cidade_Id,
        c.Cidade,
        c.Populacao,
        earth_distance(
            ll_to_earth(a.latitude_deg::FLOAT8, a.longitude_deg::FLOAT8),
            ll_to_earth(c.Latitude::FLOAT8, c.Longitude::FLOAT8)
        ) AS Distancia
    FROM airports a
    JOIN Cidades_brasileiras c ON earth_distance(
            ll_to_earth(a.latitude_deg::FLOAT8, a.longitude_deg::FLOAT8),
            ll_to_earth(c.Latitude::FLOAT8, c.Longitude::FLOAT8)
        ) <= 10000
    WHERE a.city_id IS NULL
      AND a.latitude_deg IS NOT NULL
      AND a.longitude_deg IS NOT NULL
)
SELECT id, Aeroporto, Latitude, Longitude, Cidade, Populacao, Distancia
FROM distancias;

DROP VIEW IF EXISTS Correcao_aeroportos CASCADE;
-- View Correcao_aeroportos: existe para listar os aeroportos candidatos a correção de cidade.
CREATE OR REPLACE VIEW Correcao_aeroportos AS
SELECT DISTINCT
    a.id,
    a.name,
    a.latitude_deg,
    a.longitude_deg,
    a.city_id
FROM airports a
JOIN Problemas_aeroportos p ON p.id = a.id;

/* ------------------------------------------------------------------------------------------------------------
   Views auxiliares do sistema
   ------------------------------------------------------------------------------------------------------------ */
-- View vw_results_full: existe para centralizar joins de resultados, corridas, pilotos, escuderias, países e status.
CREATE OR REPLACE VIEW vw_results_full AS
SELECT
    r.id AS result_id,
    r.race_id,
    se.id AS season_id,
    se.year::INTEGER AS season_year,
    ra.round,
    ra.race_name,
    ra.race_date,
    ra.race_time,
    cir.id AS circuit_id,
    cir.name AS circuit_name,
    d.id AS driver_id,
    d.driver_ref,
    d.given_name,
    d.family_name,
    (d.given_name || ' ' || d.family_name) AS driver_full_name,
    d.country_id AS driver_country_id,
    dc.name AS driver_country,
    dc.nationality AS driver_nationality,
    con.id AS constructor_id,
    con.constructor_ref,
    con.name AS constructor_name,
    con.country_id AS constructor_country_id,
    cc.name AS constructor_country,
    cc.nationality AS constructor_nationality,
    r.grid,
    r.position,
    r.position_order,
    r.points,
    r.laps,
    st.id AS status_id,
    st.status
FROM results r
JOIN races ra ON ra.id = r.race_id
JOIN seasons se ON se.id = ra.season_id
JOIN circuits cir ON cir.id = ra.circuit_id
JOIN drivers d ON d.id = r.driver_id
JOIN constructors con ON con.id = r.constructor_id
LEFT JOIN countries dc ON dc.id = d.country_id
LEFT JOIN countries cc ON cc.id = con.country_id
LEFT JOIN status st ON st.id = r.status_id;

-- View vw_constructor_driver_history: existe para descobrir quais pilotos já correram por cada escuderia usando results.
CREATE OR REPLACE VIEW vw_constructor_driver_history AS
SELECT DISTINCT
    constructor_id,
    constructor_ref,
    constructor_name,
    driver_id,
    driver_ref,
    driver_full_name,
    given_name,
    family_name
FROM vw_results_full;

-- View vw_driver_latest_constructor: existe para obter a escuderia mais recente de cada piloto.
CREATE OR REPLACE VIEW vw_driver_latest_constructor AS
SELECT DISTINCT ON (driver_id)
    driver_id,
    driver_full_name,
    constructor_id,
    constructor_name,
    season_year,
    race_date,
    round
FROM vw_results_full
ORDER BY driver_id, season_year DESC, race_date DESC NULLS LAST, round DESC NULLS LAST;

/* Diferente da view Cidades_brasileiras, esta não filtra população >= 100000.
   Ela é usada no relatório de aeroportos, que pede todas as cidades brasileiras com o nome pesquisado. */
-- View vw_cidades_brasileiras_todas: existe para pesquisar cidades brasileiras por nome, sem descartar cidades menores.
CREATE OR REPLACE VIEW vw_cidades_brasileiras_todas AS
SELECT
    ci.id,
    ci.name,
    ci.population,
    ci.latitude,
    ci.longitude,
    ci.country_id
FROM cities ci
JOIN countries p ON ci.country_id = p.id
WHERE p.name = 'Brazil'
  AND ci.latitude IS NOT NULL
  AND ci.longitude IS NOT NULL;

-- View vw_aeroportos_brasileiros_medium_large: existe para restringir o relatório a aeroportos brasileiros médios/grandes com coordenadas.
CREATE OR REPLACE VIEW vw_aeroportos_brasileiros_medium_large AS
SELECT
    a.id,
    a.iata_code,
    a.name AS airport_name,
    a.latitude_deg,
    a.longitude_deg,
    at.type AS airport_type,
    ci.id AS city_id,
    ci.name AS airport_city,
    ci.country_id
FROM airports a
JOIN airport_types at ON at.id = a.airport_type_id
JOIN cities ci ON ci.id = a.city_id
JOIN countries p ON p.id = ci.country_id
WHERE p.name = 'Brazil'
  AND at.type IN ('medium_airport', 'large_airport')
  AND a.latitude_deg IS NOT NULL
  AND a.longitude_deg IS NOT NULL;

COMMIT;
