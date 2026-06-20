/* ============================================================================================================
   08_indices.sql - Índices baseados no gabarito T5 + índices específicos do P4

   T5:
   - índice Hash para igualdade em nome completo de piloto;
   - índice B-tree parcial para cidades brasileiras por prefixo, com INCLUDE e WHERE.

   P4:
   - índices para filtros por usuário, escuderia, piloto, status, corridas e relatório de aeroportos.
   ============================================================================================================ */

BEGIN;

CREATE EXTENSION IF NOT EXISTS cube;
CREATE EXTENSION IF NOT EXISTS earthdistance;


/* Índices básicos de chaves estrangeiras da base, separados do schema para manter a organização. */
CREATE INDEX IF NOT EXISTS idx_countries_continent_id ON countries(continent_id);
CREATE INDEX IF NOT EXISTS idx_iso_language_codes_language_id ON iso_language_codes(language_id);
CREATE INDEX IF NOT EXISTS idx_cities_feature_code_id ON cities(feature_code_id);
CREATE INDEX IF NOT EXISTS idx_cities_country_id ON cities(country_id);
CREATE INDEX IF NOT EXISTS idx_cities_time_zone_id ON cities(time_zone_id);
CREATE INDEX IF NOT EXISTS idx_airports_airport_type_id ON airports(airport_type_id);
CREATE INDEX IF NOT EXISTS idx_airports_city_id ON airports(city_id);
CREATE INDEX IF NOT EXISTS idx_circuits_city_id ON circuits(city_id);
CREATE INDEX IF NOT EXISTS idx_races_season_id ON races(season_id);
CREATE INDEX IF NOT EXISTS idx_races_circuit_id ON races(circuit_id);
CREATE INDEX IF NOT EXISTS idx_qualifying_race_id ON qualifying(race_id);
CREATE INDEX IF NOT EXISTS idx_qualifying_driver_id ON qualifying(driver_id);
CREATE INDEX IF NOT EXISTS idx_qualifying_constructor_id ON qualifying(constructor_id);
CREATE INDEX IF NOT EXISTS idx_results_race_id ON results(race_id);
CREATE INDEX IF NOT EXISTS idx_results_driver_id ON results(driver_id);
CREATE INDEX IF NOT EXISTS idx_results_constructor_id ON results(constructor_id);
CREATE INDEX IF NOT EXISTS idx_results_status_id ON results(status_id);
CREATE INDEX IF NOT EXISTS idx_standings_season_id ON standings(season_id);


/* Login é consultado em toda autenticação. */
CREATE INDEX IF NOT EXISTS idx_p4_users_login
ON users(login);

/* Gabarito T5 - Exercício 1: busca por igualdade no nome completo do piloto. */
DROP INDEX IF EXISTS idx_p4_drivers_nome_completo_hash;
CREATE INDEX idx_p4_drivers_nome_completo_hash
ON drivers USING HASH ((given_name || ' ' || family_name));

/* Gabarito T5 - Exercício 2: LIKE 'nome%' em cidades brasileiras.
   O gabarito usa um índice B-tree parcial com INCLUDE e WHERE country_id = Brasil.
   Aqui o id do Brasil é localizado automaticamente e fixado no predicado do índice. */
DO $$
DECLARE
    v_brazil_id INTEGER;
BEGIN
    SELECT id INTO v_brazil_id
    FROM countries
    WHERE code = 'BR' OR name = 'Brazil'
    ORDER BY CASE WHEN code = 'BR' THEN 0 ELSE 1 END
    LIMIT 1;

    IF v_brazil_id IS NULL THEN
        RAISE NOTICE 'Brasil não encontrado na tabela countries. idx_p4_city_brazil_name_prefix não foi criado.';
    ELSE
        EXECUTE format(
            'CREATE INDEX IF NOT EXISTS idx_p4_city_brazil_name_prefix
             ON cities (name text_pattern_ops)
             INCLUDE (latitude, longitude, population)
             WHERE country_id = %s',
            v_brazil_id
        );
    END IF;
END;
$$;

/* Índices para dashboards e relatórios do P4. */
CREATE INDEX IF NOT EXISTS idx_p4_results_constructor_position
ON results(constructor_id, position_order);

CREATE INDEX IF NOT EXISTS idx_p4_results_constructor_status
ON results(constructor_id, status_id);

CREATE INDEX IF NOT EXISTS idx_p4_results_driver_status
ON results(driver_id, status_id);

CREATE INDEX IF NOT EXISTS idx_p4_results_driver_race
ON results(driver_id, race_id);

CREATE INDEX IF NOT EXISTS idx_p4_results_constructor_driver
ON results(constructor_id, driver_id);

CREATE INDEX IF NOT EXISTS idx_p4_races_season_circuit
ON races(season_id, circuit_id);

CREATE INDEX IF NOT EXISTS idx_p4_airports_city_type
ON airports(city_id, airport_type_id);

CREATE INDEX IF NOT EXISTS idx_p4_drivers_family_name_lower
ON drivers(LOWER(family_name));

/* Índices espaciais auxiliares para consultas com earthdistance/earth_box. */
CREATE INDEX IF NOT EXISTS idx_p4_cities_brazil_ll_earth
ON cities USING gist (ll_to_earth(latitude::FLOAT8, longitude::FLOAT8))
WHERE latitude IS NOT NULL AND longitude IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_p4_airports_ll_earth
ON airports USING gist (ll_to_earth(latitude_deg::FLOAT8, longitude_deg::FLOAT8))
WHERE latitude_deg IS NOT NULL AND longitude_deg IS NOT NULL;

COMMIT;
