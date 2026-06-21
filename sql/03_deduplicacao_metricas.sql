/* ============================================================================================================
   03_deduplicacao_metricas.sql
   ------------------------------------------------------------------------------------------------------------
   Complemento depois de a modelagem normalizada já estar no schema.

   A normalização estrutural NÃO é feita aqui, porque já foi incorporada em 01_schema_tabelas.sql:
   - countries.nationality já existe;
   - drivers.country_id já existe;
   - constructors.country_id já existe;
   - drivers/constructors não possuem mais nationality textual.

   Este arquivo fica responsável apenas por:
   - registrar métricas de conferência;
   - conferir pilotos/escuderias sem country_id após a carga;
   - executar uma deduplicação conservadora de cidades;
   - atualizar FKs de airports e circuits para as cidades mantidas.
   ============================================================================================================ */

BEGIN;

CREATE EXTENSION IF NOT EXISTS cube;
CREATE EXTENSION IF NOT EXISTS earthdistance;

DROP TABLE IF EXISTS metrics_before;
-- Tabela especial metrics_before: snapshot antes da deduplicação. Campos: countries_before/drivers_before/constructors_before/cities_before/airports_before/circuits_before BIGINT.
CREATE TABLE metrics_before AS
SELECT
    (SELECT COUNT(*) FROM countries)    AS countries_before,
    (SELECT COUNT(*) FROM drivers)      AS drivers_before,
    (SELECT COUNT(*) FROM constructors) AS constructors_before,
    (SELECT COUNT(*) FROM cities)       AS cities_before,
    (SELECT COUNT(*) FROM airports)     AS airports_before,
    (SELECT COUNT(*) FROM circuits)     AS circuits_before;

DROP TABLE IF EXISTS country_reference_metrics;
-- Tabela especial country_reference_metrics: confere se pilotos/escuderias ficaram sem país. Campos: entity_type TEXT; total_records BIGINT; records_without_country_id BIGINT.
CREATE TABLE country_reference_metrics AS
SELECT
    'drivers' AS entity_type,
    COUNT(*) AS total_records,
    COUNT(*) FILTER (WHERE country_id IS NULL) AS records_without_country_id
FROM drivers
UNION ALL
SELECT
    'constructors' AS entity_type,
    COUNT(*) AS total_records,
    COUNT(*) FILTER (WHERE country_id IS NULL) AS records_without_country_id
FROM constructors;

/* Deduplicação conservadora: mesmo país e mesmo nome ASCII/nome normalizado.
   Critério simples e explicável para o relatório: dentro do mesmo país, registros com o mesmo nome ASCII
   normalizado são tratados como candidatos a duplicata. Mantém-se o registro com maior população, depois o
   que possui coordenadas, depois o menor id. */
DROP TABLE IF EXISTS city_dedup_map;
-- Tabela especial city_dedup_map: mapeia cidades duplicadas para a cidade mantida. Campos: duplicate_id INTEGER; keep_id INTEGER; country_id INTEGER; name/ascii_name VARCHAR.
CREATE TABLE city_dedup_map AS
WITH ranked AS (
    SELECT
        id AS duplicate_id,
        FIRST_VALUE(id) OVER (
            PARTITION BY country_id, LOWER(COALESCE(NULLIF(ascii_name, ''), name))
            ORDER BY population DESC NULLS LAST,
                     CASE WHEN latitude IS NOT NULL AND longitude IS NOT NULL THEN 0 ELSE 1 END,
                     id
        ) AS keep_id,
        country_id,
        name,
        ascii_name
    FROM cities
    WHERE country_id IS NOT NULL
      AND COALESCE(NULLIF(ascii_name, ''), name) IS NOT NULL
)
SELECT duplicate_id, keep_id, country_id, name, ascii_name
FROM ranked
WHERE duplicate_id <> keep_id;

UPDATE airports a
SET city_id = m.keep_id
FROM city_dedup_map m
WHERE a.city_id = m.duplicate_id;

UPDATE circuits c
SET city_id = m.keep_id
FROM city_dedup_map m
WHERE c.city_id = m.duplicate_id;

DELETE FROM cities c
USING city_dedup_map m
WHERE c.id = m.duplicate_id;

DROP TABLE IF EXISTS metrics_after;
-- Tabela especial metrics_after: snapshot após a deduplicação. Campos: countries_after/drivers_after/constructors_after/cities_after/airports_after/circuits_after/city_duplicates_treated BIGINT.
CREATE TABLE metrics_after AS
SELECT
    (SELECT COUNT(*) FROM countries)    AS countries_after,
    (SELECT COUNT(*) FROM drivers)      AS drivers_after,
    (SELECT COUNT(*) FROM constructors) AS constructors_after,
    (SELECT COUNT(*) FROM cities)       AS cities_after,
    (SELECT COUNT(*) FROM airports)     AS airports_after,
    (SELECT COUNT(*) FROM circuits)     AS circuits_after,
    (SELECT COUNT(*) FROM city_dedup_map) AS city_duplicates_treated;

/* ------------------------------------------------------------------------------------------------------------
   Correção de acentos corrompidos na origem (mojibake)
   ------------------------------------------------------------------------------------------------------------
   O arquivo data/circuits.csv fornecido já vinha com o caractere de substituição U+FFFD (mostrado como "?"/"�")
   no lugar de letras acentuadas da coluna name (ex.: "Autódromo" gravado como "Aut�dromo"). É um defeito do
   dado de origem, não da carga nem do banco (server_encoding = UTF8 e os bytes ef bf bd já estão no CSV).
   Como são poucos registros e todos de circuitos conhecidos, corrigimos os nomes explicitamente usando
   circuit_ref como chave (estável, única e sem acento). */
UPDATE circuits SET name = 'Autódromo Oscar y Juan Gálvez'          WHERE circuit_ref = 'galvez';
UPDATE circuits SET name = 'Autódromo Hermanos Rodríguez'           WHERE circuit_ref = 'rodriguez';
UPDATE circuits SET name = 'Montjuïc circuit'                       WHERE circuit_ref = 'montjuic';
UPDATE circuits SET name = 'Autódromo Internacional Nelson Piquet'  WHERE circuit_ref = 'jacarepagua';
UPDATE circuits SET name = 'Autódromo do Estoril (Estoril Circuit)' WHERE circuit_ref = 'estoril';
UPDATE circuits SET name = 'Autódromo Internacional do Algarve'     WHERE circuit_ref = 'portimao';

ANALYZE;

COMMIT;
