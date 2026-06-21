/* ============================================================================================================
   08_indices.sql - Índices da base

   Índices de consulta:
   - índice Hash para igualdade em nome completo de piloto;
   - índice B-tree parcial para cidades brasileiras por prefixo, com INCLUDE e WHERE.
   - índices para filtros por usuário, escuderia, piloto, status, corridas e relatório de aeroportos.
   ============================================================================================================ */

BEGIN;

CREATE EXTENSION IF NOT EXISTS cube;
CREATE EXTENSION IF NOT EXISTS earthdistance;


/* Índices básicos de chaves estrangeiras da base, separados do schema para manter a organização. */
-- idx_countries_continent_id: acelera joins/filtros de países por continente.
CREATE INDEX IF NOT EXISTS idx_countries_continent_id ON countries(continent_id);
-- idx_iso_language_codes_language_id: acelera joins de códigos ISO com idiomas.
CREATE INDEX IF NOT EXISTS idx_iso_language_codes_language_id ON iso_language_codes(language_id);
-- idx_cities_feature_code_id: acelera joins/filtros de cidades por código geográfico.
CREATE INDEX IF NOT EXISTS idx_cities_feature_code_id ON cities(feature_code_id);
-- idx_cities_country_id: acelera joins/filtros de cidades por país.
CREATE INDEX IF NOT EXISTS idx_cities_country_id ON cities(country_id);
-- idx_cities_time_zone_id: acelera joins/filtros de cidades por fuso horário.
CREATE INDEX IF NOT EXISTS idx_cities_time_zone_id ON cities(time_zone_id);
-- idx_airports_airport_type_id: acelera filtros de aeroportos por tipo.
CREATE INDEX IF NOT EXISTS idx_airports_airport_type_id ON airports(airport_type_id);
-- idx_airports_city_id: acelera joins de aeroportos com cidades.
CREATE INDEX IF NOT EXISTS idx_airports_city_id ON airports(city_id);
-- idx_circuits_city_id: acelera joins de circuitos com cidades.
CREATE INDEX IF NOT EXISTS idx_circuits_city_id ON circuits(city_id);
-- idx_races_season_id: acelera consultas de corridas por temporada.
CREATE INDEX IF NOT EXISTS idx_races_season_id ON races(season_id);
-- idx_races_circuit_id: acelera consultas de corridas por circuito.
CREATE INDEX IF NOT EXISTS idx_races_circuit_id ON races(circuit_id);
-- idx_qualifying_race_id: acelera consultas de classificação por corrida.
CREATE INDEX IF NOT EXISTS idx_qualifying_race_id ON qualifying(race_id);
-- idx_qualifying_driver_id: acelera consultas de classificação por piloto.
CREATE INDEX IF NOT EXISTS idx_qualifying_driver_id ON qualifying(driver_id);
-- idx_qualifying_constructor_id: acelera consultas de classificação por escuderia.
CREATE INDEX IF NOT EXISTS idx_qualifying_constructor_id ON qualifying(constructor_id);
-- idx_results_race_id: acelera consultas de resultados por corrida.
CREATE INDEX IF NOT EXISTS idx_results_race_id ON results(race_id);
-- idx_results_driver_id: acelera consultas de resultados por piloto.
CREATE INDEX IF NOT EXISTS idx_results_driver_id ON results(driver_id);
-- idx_results_constructor_id: acelera consultas de resultados por escuderia.
CREATE INDEX IF NOT EXISTS idx_results_constructor_id ON results(constructor_id);
-- idx_results_status_id: acelera consultas de resultados por status.
CREATE INDEX IF NOT EXISTS idx_results_status_id ON results(status_id);
-- idx_standings_season_id: acelera consultas de classificação por temporada.
CREATE INDEX IF NOT EXISTS idx_standings_season_id ON standings(season_id);


/* idx_users_login: acelera autenticação, porque login é consultado em todo acesso. */
CREATE INDEX IF NOT EXISTS idx_users_login
ON users(login);

/* idx_drivers_nome_completo_hash: acelera busca por igualdade no nome completo do piloto. */
DROP INDEX IF EXISTS idx_drivers_nome_completo_hash;
-- idx_drivers_nome_completo_hash: acelera busca por igualdade no nome completo do piloto.
CREATE INDEX idx_drivers_nome_completo_hash
ON drivers USING HASH ((given_name || ' ' || family_name));

/* idx_city_brazil_name_prefix: acelera busca por prefixo em cidades brasileiras com LIKE 'nome%'.
   Usa B-tree parcial com INCLUDE e WHERE country_id = Brasil.
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
        RAISE NOTICE 'Brasil não encontrado na tabela countries. idx_city_brazil_name_prefix não foi criado.';
    ELSE
        EXECUTE format(
            'CREATE INDEX IF NOT EXISTS idx_city_brazil_name_prefix
             ON cities (name text_pattern_ops)
             INCLUDE (latitude, longitude, population)
             WHERE country_id = %s',
            v_brazil_id
        );
    END IF;
END;
$$;

/* Índices para dashboards e relatórios do sistema. */
-- idx_results_constructor_position: acelera contagem de vitórias por escuderia usando position_order.
CREATE INDEX IF NOT EXISTS idx_results_constructor_position
ON results(constructor_id, position_order);

-- idx_results_constructor_status: acelera relatórios de status filtrados por escuderia.
CREATE INDEX IF NOT EXISTS idx_results_constructor_status
ON results(constructor_id, status_id);

-- idx_results_driver_status: acelera relatórios de status filtrados por piloto.
CREATE INDEX IF NOT EXISTS idx_results_driver_status
ON results(driver_id, status_id);

-- idx_results_driver_race: acelera dashboards e relatórios de corridas por piloto.
CREATE INDEX IF NOT EXISTS idx_results_driver_race
ON results(driver_id, race_id);

-- idx_results_constructor_driver: acelera histórico de pilotos por escuderia.
CREATE INDEX IF NOT EXISTS idx_results_constructor_driver
ON results(constructor_id, driver_id);

-- idx_races_season_circuit: acelera relatórios que agrupam corridas por temporada e circuito.
CREATE INDEX IF NOT EXISTS idx_races_season_circuit
ON races(season_id, circuit_id);

-- idx_airports_city_type: acelera filtros de aeroportos por cidade e tipo.
CREATE INDEX IF NOT EXISTS idx_airports_city_type
ON airports(city_id, airport_type_id);

-- idx_drivers_family_name_lower: acelera busca case-insensitive por sobrenome de piloto.
CREATE INDEX IF NOT EXISTS idx_drivers_family_name_lower
ON drivers(LOWER(family_name));

/* Índices espaciais auxiliares para consultas com earthdistance/earth_box. */
-- idx_cities_brazil_ll_earth: acelera busca geográfica a partir das coordenadas das cidades.
CREATE INDEX IF NOT EXISTS idx_cities_brazil_ll_earth
ON cities USING gist (ll_to_earth(latitude::FLOAT8, longitude::FLOAT8))
WHERE latitude IS NOT NULL AND longitude IS NOT NULL;

-- idx_airports_ll_earth: acelera busca geográfica a partir das coordenadas dos aeroportos.
CREATE INDEX IF NOT EXISTS idx_airports_ll_earth
ON airports USING gist (ll_to_earth(latitude_deg::FLOAT8, longitude_deg::FLOAT8))
WHERE latitude_deg IS NOT NULL AND longitude_deg IS NOT NULL;

COMMIT;
