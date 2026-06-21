/* ============================================================================================================
   02_carga_csv.sql
   ------------------------------------------------------------------------------------------------------------
   Faz SOMENTE a carga dos dados-base a partir dos arquivos CSV/TSV da pasta ../data.

   A modelagem já segue o schema normalizado:
   - countries possui nationality;
   - drivers e constructors possuem country_id;
   - a nacionalidade textual dos CSVs é lida apenas no schema stg e convertida para country_id na carga final.

   Como executar:
       cd bd_schema_final_dados_csv/sql
       psql -d f1db -f 02_carga_csv.sql

   Observação:
   - Este arquivo usa \copy, que é um comando do psql.
   - Portanto, execute pelo psql, não por uma ferramenta que rode apenas SQL puro.
   - Os caminhos dos arquivos são relativos à pasta sql/.
   ============================================================================================================ */

\set ON_ERROR_STOP on

BEGIN;

DROP SCHEMA IF EXISTS stg CASCADE;
CREATE SCHEMA stg;

/* ------------------------------------------------------------------------------------------------------------
   1. Tabelas temporárias/staging com os dados brutos dos arquivos
   ------------------------------------------------------------------------------------------------------------ */
-- Tabela especial stg.countries_raw: staging de countries.csv. Campos: source_id/code/name/continent/wikipedia_link/keywords TEXT.
CREATE TABLE stg.countries_raw (
    source_id TEXT,
    code TEXT,
    name TEXT,
    continent TEXT,
    wikipedia_link TEXT,
    keywords TEXT
);

-- Tabela especial stg.time_zones_raw: staging de timeZones.tsv. Campos: country_code/time_zone_id/gmt_offset/dst_offset/raw_offset TEXT.
CREATE TABLE stg.time_zones_raw (
    country_code TEXT,
    time_zone_id TEXT,
    gmt_offset TEXT,
    dst_offset TEXT,
    raw_offset TEXT
);

-- Tabela especial stg.feature_codes_raw: staging de featureCodes_en.tsv. Campos: feature_full/name/description TEXT.
CREATE TABLE stg.feature_codes_raw (
    feature_full TEXT,
    name TEXT,
    description TEXT
);

-- Tabela especial stg.iso_language_codes_raw: staging de iso-languagecodes.tsv. Campos: iso_639_3/iso_639_2/iso_639_1/language_name TEXT.
CREATE TABLE stg.iso_language_codes_raw (
    iso_639_3 TEXT,
    iso_639_2 TEXT,
    iso_639_1 TEXT,
    language_name TEXT
);

-- Tabela especial stg.cities_raw: staging de cities.tsv. Campos principais: geoname_id/name/ascii_name/alternate_names/latitude/longitude/feature/country/admin/population/elevation/dem/time_zone/modification_date TEXT.
CREATE TABLE stg.cities_raw (
    geoname_id TEXT,
    name TEXT,
    ascii_name TEXT,
    alternate_names TEXT,
    latitude TEXT,
    longitude TEXT,
    feature_class TEXT,
    feature_code TEXT,
    country_code TEXT,
    cc2 TEXT,
    admin1_code TEXT,
    admin2_code TEXT,
    admin3_code TEXT,
    admin4_code TEXT,
    population TEXT,
    elevation TEXT,
    dem TEXT,
    time_zone TEXT,
    modification_date TEXT
);

-- Tabela especial stg.airports_raw: staging de airports.csv. Campos: id/ident/type/name/coordenadas/elevation/continent/iso/municipality/service/codes/links/keywords TEXT.
CREATE TABLE stg.airports_raw (
    id TEXT,
    ident TEXT,
    type TEXT,
    name TEXT,
    latitude_deg TEXT,
    longitude_deg TEXT,
    elevation_ft TEXT,
    continent TEXT,
    iso_country TEXT,
    iso_region TEXT,
    municipality TEXT,
    scheduled_service TEXT,
    icao_code TEXT,
    iata_code TEXT,
    gps_code TEXT,
    local_code TEXT,
    home_link TEXT,
    wikipedia_link TEXT,
    keywords TEXT
);

-- Tabela especial stg.circuits_raw: staging de circuits.csv. Campos: circuit_id/name/lat/long/locality/country/wikipedia_url TEXT.
CREATE TABLE stg.circuits_raw (
    circuit_id TEXT,
    name TEXT,
    lat TEXT,
    long TEXT,
    locality TEXT,
    country TEXT,
    wikipedia_url TEXT
);

-- Tabela especial stg.constructors_raw: staging de constructors.csv. Campos: constructor_id/name/nationality/wikipedia_url TEXT.
CREATE TABLE stg.constructors_raw (
    constructor_id TEXT,
    name TEXT,
    nationality TEXT,
    wikipedia_url TEXT
);

-- Tabela especial stg.drivers_raw: staging de drivers.csv. Campos: driver_id/given_name/family_name/nationality/date_of_birth TEXT.
CREATE TABLE stg.drivers_raw (
    driver_id TEXT,
    given_name TEXT,
    family_name TEXT,
    nationality TEXT,
    date_of_birth TEXT
);

-- Tabela especial stg.races_raw: staging de races.csv. Campos: race_id/season/round/race_name/race_date/race_time/circuit_id TEXT.
CREATE TABLE stg.races_raw (
    race_id TEXT,
    season TEXT,
    round TEXT,
    race_name TEXT,
    race_date TEXT,
    race_time TEXT,
    circuit_id TEXT
);

-- Tabela especial stg.results_raw: staging de results.csv. Campos: race_id/driver_id/constructor_id/grid/position/position_order/points/laps/status TEXT.
CREATE TABLE stg.results_raw (
    race_id TEXT,
    driver_id TEXT,
    constructor_id TEXT,
    grid TEXT,
    position TEXT,
    position_order TEXT,
    points TEXT,
    laps TEXT,
    status TEXT
);

-- Tabela especial stg.qualifying_raw: staging de qualifying.csv. Campos: race_id/driver_id/constructor_id/position/q1/q2/q3 TEXT.
CREATE TABLE stg.qualifying_raw (
    race_id TEXT,
    driver_id TEXT,
    constructor_id TEXT,
    position TEXT,
    q1 TEXT,
    q2 TEXT,
    q3 TEXT
);

-- Tabela especial stg.driver_standings_raw: staging de driver_standings.csv. Campos: raw_id INTEGER PK; season/round/driver_id/position/points/wins TEXT.
CREATE TABLE stg.driver_standings_raw (
    raw_id INTEGER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    season TEXT,
    round TEXT,
    driver_id TEXT,
    position TEXT,
    points TEXT,
    wins TEXT
);

-- Tabela especial stg.constructor_standings_raw: staging de constructor_standings.csv. Campos: raw_id INTEGER PK; season/round/constructor_id/position/points/wins TEXT.
CREATE TABLE stg.constructor_standings_raw (
    raw_id INTEGER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    season TEXT,
    round TEXT,
    constructor_id TEXT,
    position TEXT,
    points TEXT,
    wins TEXT
);

/* ------------------------------------------------------------------------------------------------------------
   Funções auxiliares de conversão segura para a carga.
   Evitam erros quando o CSV traz vazio, texto inesperado ou inteiros escritos como decimal, por exemplo '1.0'.
   Valores inválidos são carregados como NULL, preservando a execução da carga.
   ------------------------------------------------------------------------------------------------------------ */
/* stg.safe_text: existe para normalizar texto vazio, null, nan e \n como NULL durante a carga. */
CREATE OR REPLACE FUNCTION stg.safe_text(v TEXT)
RETURNS TEXT AS $$
BEGIN
    IF v IS NULL OR BTRIM(v) = '' OR LOWER(BTRIM(v)) IN ('null', 'nan', '\\n') THEN
        RETURN NULL;
    END IF;
    RETURN BTRIM(v);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

/* stg.safe_numeric: existe para converter texto em NUMERIC sem quebrar a carga em valor inválido. */
CREATE OR REPLACE FUNCTION stg.safe_numeric(v TEXT)
RETURNS NUMERIC AS $$
DECLARE
    x TEXT;
BEGIN
    x := stg.safe_text(v);
    IF x IS NULL THEN
        RETURN NULL;
    END IF;
    x := REPLACE(x, ',', '.');
    IF x ~ '^[+-]?[0-9]+(\.[0-9]+)?$' THEN
        RETURN x::NUMERIC;
    END IF;
    RETURN NULL;
EXCEPTION WHEN OTHERS THEN
    RETURN NULL;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

/* stg.safe_int: existe para converter texto em INTEGER arredondado, retornando NULL se inválido. */
CREATE OR REPLACE FUNCTION stg.safe_int(v TEXT)
RETURNS INTEGER AS $$
DECLARE
    n NUMERIC;
BEGIN
    n := stg.safe_numeric(v);
    IF n IS NULL THEN
        RETURN NULL;
    END IF;
    RETURN ROUND(n)::INTEGER;
EXCEPTION WHEN OTHERS THEN
    RETURN NULL;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

/* stg.safe_bigint: existe para converter texto em BIGINT, retornando NULL se inválido. */
CREATE OR REPLACE FUNCTION stg.safe_bigint(v TEXT)
RETURNS BIGINT AS $$
DECLARE
    n NUMERIC;
BEGIN
    n := stg.safe_numeric(v);
    IF n IS NULL THEN
        RETURN NULL;
    END IF;
    RETURN ROUND(n)::BIGINT;
EXCEPTION WHEN OTHERS THEN
    RETURN NULL;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

/* stg.safe_smallint: existe para converter texto em SMALLINT, retornando NULL se inválido. */
CREATE OR REPLACE FUNCTION stg.safe_smallint(v TEXT)
RETURNS SMALLINT AS $$
DECLARE
    i INTEGER;
BEGIN
    i := stg.safe_int(v);
    IF i IS NULL THEN
        RETURN NULL;
    END IF;
    RETURN i::SMALLINT;
EXCEPTION WHEN OTHERS THEN
    RETURN NULL;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

/* stg.safe_date: existe para converter texto em DATE, retornando NULL se inválido. */
CREATE OR REPLACE FUNCTION stg.safe_date(v TEXT)
RETURNS DATE AS $$
DECLARE
    x TEXT;
BEGIN
    x := stg.safe_text(v);
    IF x IS NULL THEN
        RETURN NULL;
    END IF;
    RETURN x::DATE;
EXCEPTION WHEN OTHERS THEN
    RETURN NULL;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

/* stg.safe_time: existe para converter texto em TIME e remover sufixo Z quando vier do CSV. */
CREATE OR REPLACE FUNCTION stg.safe_time(v TEXT)
RETURNS TIME AS $$
DECLARE
    x TEXT;
BEGIN
    x := stg.safe_text(v);
    IF x IS NULL THEN
        RETURN NULL;
    END IF;
    -- Os horários de races.csv vêm como '14:00:00Z'. Para TIME, removemos o sufixo Z.
    x := REGEXP_REPLACE(x, 'Z$', '', 'i');
    RETURN x::TIME;
EXCEPTION WHEN OTHERS THEN
    RETURN NULL;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

/* stg.safe_minutes: existe para converter valor decimal em minutos inteiros. */
CREATE OR REPLACE FUNCTION stg.safe_minutes(v TEXT)
RETURNS INTEGER AS $$
DECLARE
    n NUMERIC;
BEGIN
    n := stg.safe_numeric(v);
    IF n IS NULL THEN
        RETURN NULL;
    END IF;
    RETURN ROUND(n * 60)::INTEGER;
EXCEPTION WHEN OTHERS THEN
    RETURN NULL;
END;
$$ LANGUAGE plpgsql IMMUTABLE;


COMMIT;

/* ------------------------------------------------------------------------------------------------------------
   2. Leitura dos arquivos da pasta ../data
   ------------------------------------------------------------------------------------------------------------ */
\copy stg.countries_raw FROM '../data/countries.csv' WITH (FORMAT csv, HEADER true);
\copy stg.time_zones_raw FROM '../data/timeZones.tsv' WITH (FORMAT csv, HEADER true, DELIMITER E'\t');
\copy stg.feature_codes_raw FROM '../data/featureCodes_en.tsv' WITH (FORMAT csv, HEADER false, DELIMITER E'\t');
\copy stg.iso_language_codes_raw FROM '../data/iso-languagecodes.tsv' WITH (FORMAT csv, HEADER true, DELIMITER E'\t');
\copy stg.cities_raw FROM '../data/cities.tsv' WITH (FORMAT csv, HEADER false, DELIMITER E'\t');
\copy stg.airports_raw FROM '../data/airports.csv' WITH (FORMAT csv, HEADER true);
\copy stg.circuits_raw FROM '../data/circuits.csv' WITH (FORMAT csv, HEADER true);
\copy stg.constructors_raw FROM '../data/constructors.csv' WITH (FORMAT csv, HEADER true);
\copy stg.drivers_raw FROM '../data/drivers.csv' WITH (FORMAT csv, HEADER true);
\copy stg.races_raw FROM '../data/races.csv' WITH (FORMAT csv, HEADER true);
\copy stg.results_raw FROM '../data/results.csv' WITH (FORMAT csv, HEADER true);
\copy stg.qualifying_raw FROM '../data/qualifying.csv' WITH (FORMAT csv, HEADER true);
\copy stg.driver_standings_raw(season, round, driver_id, position, points, wins) FROM '../data/driver_standings.csv' WITH (FORMAT csv, HEADER true);
\copy stg.constructor_standings_raw(season, round, constructor_id, position, points, wins) FROM '../data/constructor_standings.csv' WITH (FORMAT csv, HEADER true);

BEGIN;

/* ------------------------------------------------------------------------------------------------------------
   3. Mapeamento de nacionalidade textual dos CSVs -> país normalizado
   ------------------------------------------------------------------------------------------------------------
   O CSV de drivers/constructors ainda traz nationality como texto. Como o schema final já está normalizado,
   essa informação é usada apenas na staging para descobrir o country_id.
   ------------------------------------------------------------------------------------------------------------ */
-- Tabela especial tmp_nationality_map: mapeia nationality textual para código de país. Campos: nationality_text VARCHAR(255) PK; country_code VARCHAR(2).
CREATE TEMP TABLE tmp_nationality_map (
    nationality_text VARCHAR(255) PRIMARY KEY,
    country_code VARCHAR(2) NOT NULL
);

INSERT INTO tmp_nationality_map(nationality_text, country_code) VALUES
    ('american', 'US'),
    ('argentine', 'AR'),
    ('argentinian', 'AR'),
    ('australian', 'AU'),
    ('austrian', 'AT'),
    ('belgian', 'BE'),
    ('brazilian', 'BR'),
    ('british', 'GB'),
    ('canadian', 'CA'),
    ('chilean', 'CL'),
    ('chinese', 'CN'),
    ('colombian', 'CO'),
    ('czech', 'CZ'),
    ('danish', 'DK'),
    ('dutch', 'NL'),
    ('east german', 'DE'),
    ('emirati', 'AE'),
    ('finnish', 'FI'),
    ('french', 'FR'),
    ('german', 'DE'),
    ('hong kong', 'HK'),
    ('hungarian', 'HU'),
    ('indian', 'IN'),
    ('indonesian', 'ID'),
    ('irish', 'IE'),
    ('italian', 'IT'),
    ('japanese', 'JP'),
    ('liechtensteiner', 'LI'),
    ('malaysian', 'MY'),
    ('mexican', 'MX'),
    ('monegasque', 'MC'),
    ('new zealander', 'NZ'),
    ('polish', 'PL'),
    ('portuguese', 'PT'),
    ('rhodesian', 'ZW'),
    ('romanian', 'RO'),
    ('russian', 'RU'),
    ('south african', 'ZA'),
    ('spanish', 'ES'),
    ('swedish', 'SE'),
    ('swiss', 'CH'),
    ('thai', 'TH'),
    ('uruguayan', 'UY'),
    ('venezuelan', 'VE')
ON CONFLICT DO NOTHING;

-- Tabela especial tmp_country_nationality_canonical: escolhe uma nacionalidade canônica por país. Campos: country_code VARCHAR(2); nationality_text VARCHAR(255).
CREATE TEMP TABLE tmp_country_nationality_canonical AS
SELECT country_code, MIN(nationality_text) AS nationality_text
FROM tmp_nationality_map
GROUP BY country_code;

UPDATE tmp_country_nationality_canonical SET nationality_text = 'german' WHERE country_code = 'DE';
UPDATE tmp_country_nationality_canonical SET nationality_text = 'argentine' WHERE country_code = 'AR';
UPDATE tmp_country_nationality_canonical SET nationality_text = 'new zealander' WHERE country_code = 'NZ';

/* ------------------------------------------------------------------------------------------------------------
   4. Carga das tabelas de localização e referência
   ------------------------------------------------------------------------------------------------------------ */
INSERT INTO continents (code, name) VALUES
('AF', 'Africa'),
('AN', 'Antarctica'),
('AS', 'Asia'),
('EU', 'Europe'),
('NA', 'North America'),
('OC', 'Oceania'),
('SA', 'South America');

INSERT INTO time_zones (name, gmt_offset, dst_offset, raw_offset)
SELECT DISTINCT
    stg.safe_text(time_zone_id),
    stg.safe_numeric(gmt_offset),
    stg.safe_numeric(dst_offset),
    stg.safe_numeric(raw_offset)
FROM stg.time_zones_raw
WHERE stg.safe_text(time_zone_id) IS NOT NULL
ORDER BY 1;

INSERT INTO language_names (name)
SELECT DISTINCT NULLIF(TRIM(language_name), '')
FROM stg.iso_language_codes_raw
WHERE NULLIF(TRIM(language_name), '') IS NOT NULL
ORDER BY 1;

INSERT INTO feature_codes (feature_class, feature_code, name, description)
SELECT
    split_part(feature_full, '.', 1),
    split_part(feature_full, '.', 2),
    NULLIF(TRIM(name), ''),
    NULLIF(TRIM(description), '')
FROM stg.feature_codes_raw
WHERE NULLIF(TRIM(feature_full), '') IS NOT NULL;

INSERT INTO countries (code, name, wikipedia_link, keywords, continent_id, nationality)
SELECT
    TRIM(cr.code),
    NULLIF(TRIM(cr.name), ''),
    NULLIF(TRIM(cr.wikipedia_link), ''),
    NULLIF(TRIM(cr.keywords), ''),
    co.id,
    INITCAP(t.nationality_text)
FROM stg.countries_raw cr
LEFT JOIN continents co ON co.code = TRIM(cr.continent)
LEFT JOIN tmp_country_nationality_canonical t ON t.country_code = TRIM(cr.code)
WHERE NULLIF(TRIM(cr.code), '') IS NOT NULL
ORDER BY TRIM(cr.code);

INSERT INTO iso_language_codes (iso_639_3, iso_639_2, iso_639_1, language_id)
SELECT
    stg.safe_text(r.iso_639_3),
    -- O schema foi dimensionado para o dado real, então valores como 'bod / tib*' são preservados.
    stg.safe_text(r.iso_639_2),
    stg.safe_text(r.iso_639_1),
    ln.id
FROM stg.iso_language_codes_raw r
JOIN language_names ln ON ln.name = stg.safe_text(r.language_name)
WHERE stg.safe_text(r.language_name) IS NOT NULL;

/* country_languages fica vazia nesta carga simplificada, pois não é usada pelos relatórios do sistema. */

INSERT INTO cities (
    name, ascii_name, alternate_names, latitude, longitude,
    feature_code_id, country_id, time_zone_id, cc2, admin1_code,
    admin2_code, admin3_code, admin4_code, population, elevation, dem, modification_date
)
SELECT
    NULLIF(TRIM(c.name), ''),
    NULLIF(TRIM(c.ascii_name), ''),
    NULLIF(TRIM(c.alternate_names), ''),
    stg.safe_numeric(c.latitude),
    stg.safe_numeric(c.longitude),
    fc.id,
    co.id,
    tz.id,
    NULLIF(TRIM(c.cc2), ''),
    NULLIF(TRIM(c.admin1_code), ''),
    NULLIF(TRIM(c.admin2_code), ''),
    NULLIF(TRIM(c.admin3_code), ''),
    NULLIF(TRIM(c.admin4_code), ''),
    stg.safe_bigint(c.population),
    stg.safe_int(c.elevation),
    stg.safe_int(c.dem),
    stg.safe_date(c.modification_date)
FROM stg.cities_raw c
LEFT JOIN feature_codes fc
       ON fc.feature_class = c.feature_class
      AND fc.feature_code = c.feature_code
LEFT JOIN countries co ON co.code = c.country_code
LEFT JOIN time_zones tz ON tz.name = c.time_zone;

INSERT INTO airport_types (type)
SELECT DISTINCT NULLIF(TRIM(type), '')
FROM stg.airports_raw
WHERE NULLIF(TRIM(type), '') IS NOT NULL
ORDER BY 1;

/*
   Índices temporários de carga.
   Sem estes índices, a associação de aeroportos às cidades pode ficar muito lenta,
   porque cada aeroporto tenta encontrar uma cidade correspondente pelo nome e país.
*/
-- idx_load_countries_code: acelera busca de país por código durante a carga.
CREATE INDEX IF NOT EXISTS idx_load_countries_code ON countries(code);
-- idx_load_countries_name: acelera busca de país por nome durante a carga.
CREATE INDEX IF NOT EXISTS idx_load_countries_name ON countries(name);
-- idx_load_cities_country_name: acelera associação de aeroporto/circuito por país e nome da cidade.
CREATE INDEX IF NOT EXISTS idx_load_cities_country_name ON cities(country_id, name);
-- idx_load_cities_country_ascii_name: acelera associação por país e nome ASCII da cidade.
CREATE INDEX IF NOT EXISTS idx_load_cities_country_ascii_name ON cities(country_id, ascii_name);
-- idx_load_airport_types_type: acelera associação de aeroportos ao tipo.
CREATE INDEX IF NOT EXISTS idx_load_airport_types_type ON airport_types(type);
ANALYZE countries;
ANALYZE cities;
ANALYZE airport_types;


/* ------------------------------------------------------------------------------------------------------------
   5. Carga das entidades principais
   ------------------------------------------------------------------------------------------------------------ */
INSERT INTO airports (
    ident, airport_type_id, name, latitude_deg, longitude_deg, elevation_ft, city_id,
    scheduled_service, icao_code, iata_code, gps_code, local_code, home_link, wikipedia_link, keywords
)
SELECT
    NULLIF(TRIM(a.ident), ''),
    at.id,
    NULLIF(TRIM(a.name), ''),
    stg.safe_numeric(a.latitude_deg),
    stg.safe_numeric(a.longitude_deg),
    stg.safe_int(a.elevation_ft),
    city_match.id,
    NULLIF(TRIM(a.scheduled_service), ''),
    NULLIF(TRIM(a.icao_code), ''),
    NULLIF(TRIM(a.iata_code), ''),
    NULLIF(TRIM(a.gps_code), ''),
    NULLIF(TRIM(a.local_code), ''),
    NULLIF(TRIM(a.home_link), ''),
    NULLIF(TRIM(a.wikipedia_link), ''),
    NULLIF(TRIM(a.keywords), '')
FROM stg.airports_raw a
LEFT JOIN airport_types at ON at.type = NULLIF(TRIM(a.type), '')
LEFT JOIN LATERAL (
    SELECT c.id
    FROM cities c
    JOIN countries co ON co.id = c.country_id
    JOIN LATERAL (
        SELECT DISTINCT TRIM(v) AS nome
        FROM unnest(ARRAY[
            a.municipality,
            regexp_replace(COALESCE(a.municipality, ''), '\s*\([^)]*\)', '', 'g'),
            split_part(COALESCE(a.municipality, ''), ',', 1),
            split_part(COALESCE(a.municipality, ''), '/', 1)
        ]) AS v
        WHERE TRIM(v) <> ''
    ) nomes ON c.name = nomes.nome OR c.ascii_name = nomes.nome
    WHERE co.code = NULLIF(TRIM(a.iso_country), '')
    ORDER BY c.population DESC NULLS LAST, c.id
    LIMIT 1
) city_match ON true
WHERE NULLIF(TRIM(a.ident), '') IS NOT NULL;

INSERT INTO circuits (circuit_ref, name, lat, "long", city_id, wikipedia_url)
SELECT
    NULLIF(TRIM(cir.circuit_id), ''),
    NULLIF(TRIM(cir.name), ''),
    stg.safe_numeric(cir.lat),
    stg.safe_numeric(cir.long),
    city_match.id,
    NULLIF(TRIM(cir.wikipedia_url), '')
FROM stg.circuits_raw cir
LEFT JOIN LATERAL (
    SELECT c.id
    FROM cities c
    JOIN countries co ON co.id = c.country_id
    WHERE co.name = NULLIF(TRIM(cir.country), '')
    ORDER BY
        CASE WHEN c.name = NULLIF(TRIM(cir.locality), '') OR c.ascii_name = NULLIF(TRIM(cir.locality), '') THEN 0 ELSE 1 END,
        ((c.latitude - stg.safe_numeric(cir.lat)) * (c.latitude - stg.safe_numeric(cir.lat))
        + (c.longitude - stg.safe_numeric(cir.long)) * (c.longitude - stg.safe_numeric(cir.long))),
        c.population DESC NULLS LAST,
        c.id
    LIMIT 1
) city_match ON true
WHERE NULLIF(TRIM(cir.circuit_id), '') IS NOT NULL;

INSERT INTO constructors (constructor_ref, name, country_id, wikipedia_url)
SELECT
    LOWER(TRIM(cn.constructor_id)),
    NULLIF(TRIM(cn.name), ''),
    co.id,
    NULLIF(TRIM(cn.wikipedia_url), '')
FROM stg.constructors_raw cn
LEFT JOIN tmp_nationality_map nm ON nm.nationality_text = LOWER(TRIM(cn.nationality))
LEFT JOIN countries co ON co.code = nm.country_code
WHERE NULLIF(TRIM(cn.constructor_id), '') IS NOT NULL;

INSERT INTO drivers (driver_ref, given_name, family_name, country_id, date_of_birth)
SELECT
    LOWER(TRIM(d.driver_id)),
    NULLIF(TRIM(d.given_name), ''),
    NULLIF(TRIM(d.family_name), ''),
    co.id,
    stg.safe_date(d.date_of_birth)
FROM stg.drivers_raw d
LEFT JOIN tmp_nationality_map nm ON nm.nationality_text = LOWER(TRIM(d.nationality))
LEFT JOIN countries co ON co.code = nm.country_code
WHERE NULLIF(TRIM(d.driver_id), '') IS NOT NULL;

INSERT INTO seasons (year)
SELECT DISTINCT stg.safe_smallint(season)
FROM (
    SELECT NULLIF(TRIM(season), '') AS season FROM stg.races_raw
    UNION
    SELECT NULLIF(TRIM(season), '') AS season FROM stg.driver_standings_raw
    UNION
    SELECT NULLIF(TRIM(season), '') AS season FROM stg.constructor_standings_raw
) x
WHERE season IS NOT NULL
ORDER BY stg.safe_smallint(season);

INSERT INTO races (race_ref, season_id, round, race_name, race_date, race_time, circuit_id)
SELECT
    NULLIF(TRIM(r.race_id), ''),
    s.id,
    stg.safe_int(r.round),
    NULLIF(TRIM(r.race_name), ''),
    stg.safe_date(r.race_date),
    stg.safe_time(r.race_time),
    cir.id
FROM stg.races_raw r
JOIN seasons s ON s.year = stg.safe_smallint(r.season)
JOIN circuits cir ON cir.circuit_ref = LOWER(TRIM(r.circuit_id))
WHERE NULLIF(TRIM(r.race_id), '') IS NOT NULL;

INSERT INTO status (status)
SELECT DISTINCT NULLIF(TRIM(status), '')
FROM stg.results_raw
WHERE NULLIF(TRIM(status), '') IS NOT NULL
ORDER BY 1;

INSERT INTO results (race_id, driver_id, constructor_id, grid, position, position_order, points, laps, status_id)
SELECT
    ra.id,
    d.id,
    c.id,
    stg.safe_int(r.grid),
    NULLIF(TRIM(r.position), ''),
    stg.safe_int(r.position_order),
    stg.safe_numeric(r.points),
    stg.safe_int(r.laps),
    st.id
FROM stg.results_raw r
JOIN races ra ON ra.race_ref = TRIM(r.race_id)
JOIN drivers d ON d.driver_ref = LOWER(TRIM(r.driver_id))
JOIN constructors c ON c.constructor_ref = LOWER(TRIM(r.constructor_id))
JOIN status st ON st.status = NULLIF(TRIM(r.status), '');

INSERT INTO qualifying (race_id, driver_id, constructor_id, position, q1, q2, q3)
SELECT
    ra.id,
    d.id,
    c.id,
    stg.safe_int(q.position),
    NULLIF(TRIM(q.q1), ''),
    NULLIF(TRIM(q.q2), ''),
    NULLIF(TRIM(q.q3), '')
FROM stg.qualifying_raw q
JOIN races ra ON ra.race_ref = TRIM(q.race_id)
JOIN drivers d ON d.driver_ref = LOWER(TRIM(q.driver_id))
JOIN constructors c ON c.constructor_ref = LOWER(TRIM(q.constructor_id));

/* ------------------------------------------------------------------------------------------------------------
   6. Carga de standings e tabelas associativas
   ------------------------------------------------------------------------------------------------------------ */
-- Tabela especial tmp_driver_standing_map: reserva ids de standings para classificação de pilotos. Campos: raw_id INTEGER; standing_id INTEGER.
CREATE TEMP TABLE tmp_driver_standing_map AS
SELECT raw_id, nextval(pg_get_serial_sequence('standings', 'id')::regclass) AS standing_id
FROM stg.driver_standings_raw;

INSERT INTO standings(id, season_id, round, position, points, wins)
SELECT
    m.standing_id,
    s.id,
    stg.safe_int(ds.round),
    stg.safe_int(ds.position),
    stg.safe_numeric(ds.points),
    stg.safe_int(ds.wins)
FROM stg.driver_standings_raw ds
JOIN tmp_driver_standing_map m ON m.raw_id = ds.raw_id
JOIN seasons s ON s.year = stg.safe_smallint(ds.season);

INSERT INTO driver_standings(standing_id, driver_id)
SELECT
    m.standing_id,
    d.id
FROM stg.driver_standings_raw ds
JOIN tmp_driver_standing_map m ON m.raw_id = ds.raw_id
JOIN drivers d ON d.driver_ref = LOWER(TRIM(ds.driver_id));

-- Tabela especial tmp_constructor_standing_map: reserva ids de standings para classificação de escuderias. Campos: raw_id INTEGER; standing_id INTEGER.
CREATE TEMP TABLE tmp_constructor_standing_map AS
SELECT raw_id, nextval(pg_get_serial_sequence('standings', 'id')::regclass) AS standing_id
FROM stg.constructor_standings_raw;

INSERT INTO standings(id, season_id, round, position, points, wins)
SELECT
    m.standing_id,
    s.id,
    stg.safe_int(cs.round),
    stg.safe_int(cs.position),
    stg.safe_numeric(cs.points),
    stg.safe_int(cs.wins)
FROM stg.constructor_standings_raw cs
JOIN tmp_constructor_standing_map m ON m.raw_id = cs.raw_id
JOIN seasons s ON s.year = stg.safe_smallint(cs.season);

INSERT INTO constructor_standings(standing_id, constructor_id)
SELECT
    m.standing_id,
    c.id
FROM stg.constructor_standings_raw cs
JOIN tmp_constructor_standing_map m ON m.raw_id = cs.raw_id
JOIN constructors c ON c.constructor_ref = LOWER(TRIM(cs.constructor_id));

ANALYZE;

COMMIT;
