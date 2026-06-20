/* ============================================================================================================
   05_functions.sql
   ------------------------------------------------------------------------------------------------------------
   Arquivo dedicado às funções e procedures:
   - autenticação e log do P4;
   - funções/procedures inspiradas no gabarito T2;
   - funções de dashboard, relatórios e ações do P4.
   ============================================================================================================ */

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS cube;
CREATE EXTENSION IF NOT EXISTS earthdistance;

/* Autenticação usada pelo backend. Retorna 0 linhas se login/senha estiverem incorretos. */
CREATE OR REPLACE FUNCTION p4_authenticate(p_login TEXT, p_senha TEXT)
RETURNS TABLE (
    userid INTEGER,
    login TEXT,
    tipo TEXT,
    id_original INTEGER,
    nome_exibicao TEXT
)
LANGUAGE sql
STABLE
AS $$
    SELECT
        u.userid,
        u.login::TEXT,
        u.tipo::TEXT,
        u.id_original,
        CASE
            WHEN u.tipo = 'Admin' THEN 'Administrador'::TEXT
            WHEN u.tipo = 'Escuderia' THEN c.name::TEXT
            WHEN u.tipo = 'Piloto' THEN (d.given_name || ' ' || d.family_name)::TEXT
        END AS nome_exibicao
    FROM users u
    LEFT JOIN constructors c ON u.tipo = 'Escuderia' AND c.id = u.id_original
    LEFT JOIN drivers d ON u.tipo = 'Piloto' AND d.id = u.id_original
    WHERE u.login = LOWER(TRIM(p_login))
      AND u.password = crypt(p_senha, u.password);
$$;

CREATE OR REPLACE FUNCTION p4_log_access(p_userid INTEGER, p_action TEXT)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    IF UPPER(TRIM(p_action)) NOT IN ('LOGIN', 'LOGOUT') THEN
        RAISE EXCEPTION 'Ação inválida para log de acesso: %', p_action;
    END IF;

    INSERT INTO users_log(userid, action_type)
    VALUES (p_userid, UPPER(TRIM(p_action)));
END;
$$;

CREATE EXTENSION IF NOT EXISTS cube;
CREATE EXTENSION IF NOT EXISTS earthdistance;

/* ------------------------------------------------------------------------------------------------------------
   Funções/procedures compatíveis com o gabarito T2
   ------------------------------------------------------------------------------------------------------------ */
DROP FUNCTION IF EXISTS Nome_Nacionalidade(TEXT);
CREATE OR REPLACE FUNCTION Nome_Nacionalidade(Nome TEXT)
RETURNS TEXT AS $$
DECLARE
    Nacionalidade TEXT;
BEGIN
    SELECT p.nationality INTO Nacionalidade
    FROM constructors c
    JOIN countries p ON c.country_id = p.id
    WHERE c.name = Nome;

    RETURN Nacionalidade;
END;
$$ LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS Pilotos_Nacionalidade(TEXT);
CREATE OR REPLACE FUNCTION Pilotos_Nacionalidade(Nacionalidade TEXT)
RETURNS VOID AS $$
DECLARE
    pilotos CURSOR FOR
        SELECT d.given_name || ' ' || d.family_name AS Nome
        FROM drivers d
        JOIN countries p ON d.country_id = p.id
        WHERE p.nationality = Nacionalidade;
    piloto RECORD;
    i INTEGER;
BEGIN
    IF Nacionalidade IS NULL THEN
        RAISE EXCEPTION 'Nacionalidade inválida.';
    END IF;

    OPEN pilotos;
    i := 1;

    LOOP
        FETCH pilotos INTO piloto;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE '% Nome: %', i, piloto.nome;
        i := i + 1;
    END LOOP;

    CLOSE pilotos;

    IF i = 1 THEN
        RAISE EXCEPTION 'Nenhum piloto encontrado para a nacionalidade informada.';
    END IF;
END;
$$ LANGUAGE plpgsql;

DROP PROCEDURE IF EXISTS Cidade_Chamada(TEXT);
CREATE OR REPLACE PROCEDURE Cidade_Chamada(Nome TEXT)
AS $$
DECLARE
    Contagem INTEGER;
    Cidades CURSOR FOR
        SELECT c.name AS nome_cidade, c.population, p.name AS pais
        FROM cities c
        JOIN countries p ON c.country_id = p.id
        WHERE c.name = Nome;
    Cidade RECORD;
BEGIN
    IF Nome IS NULL THEN
        RAISE EXCEPTION 'Nome de cidade inválido.';
    END IF;

    SELECT COUNT(*) INTO Contagem
    FROM cities
    WHERE name = Nome;

    IF Contagem = 0 THEN
        RAISE EXCEPTION 'Nenhuma cidade encontrada com esse nome.';
    END IF;

    OPEN Cidades;
    RAISE NOTICE 'Contagem: %|', Contagem;

    LOOP
        FETCH Cidades INTO Cidade;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Nome: %, População: %, País: %', Cidade.nome_cidade, Cidade.population, Cidade.pais;
    END LOOP;

    CLOSE Cidades;
END;
$$ LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS Numero_Vitorias(TEXT, TEXT, INTEGER);
CREATE OR REPLACE FUNCTION Numero_Vitorias(
    Nome TEXT,
    Sobrenome TEXT,
    Ano INTEGER DEFAULT NULL
)
RETURNS INTEGER AS $$
DECLARE
    IdPiloto drivers.id%TYPE;
    Vitorias INTEGER;
BEGIN
    SELECT d.id INTO IdPiloto
    FROM drivers d
    WHERE d.given_name = Nome
      AND d.family_name = Sobrenome;

    IF IdPiloto IS NULL THEN
        RETURN 0;
    END IF;

    IF Ano IS NULL THEN
        SELECT COUNT(*) INTO Vitorias
        FROM results r
        WHERE r.position_order = 1
          AND r.driver_id = IdPiloto;
    ELSE
        SELECT COUNT(*) INTO Vitorias
        FROM results r
        JOIN races ra ON ra.id = r.race_id
        JOIN seasons s ON s.id = ra.season_id
        WHERE r.position_order = 1
          AND r.driver_id = IdPiloto
          AND s.year = Ano;
    END IF;

    RETURN Vitorias;
END;
$$ LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS Pais_Continente();
CREATE OR REPLACE FUNCTION Pais_Continente()
RETURNS TABLE(Nome TEXT, Continente TEXT) AS $$
DECLARE
    Paises CURSOR FOR
        SELECT p.name AS nome_pais, c.name AS nome_continente
        FROM countries p
        JOIN continents c ON p.continent_id = c.id;
    Pais RECORD;
    Qtd INTEGER;
BEGIN
    Qtd := 0;

    OPEN Paises;
    LOOP
        FETCH Paises INTO Pais;
        EXIT WHEN NOT FOUND;

        IF LENGTH(Pais.nome_pais) <= 15 THEN
            Nome := Pais.nome_pais;
            Continente := Pais.nome_continente;
            Qtd := Qtd + 1;
            RETURN NEXT;
        END IF;
    END LOOP;
    CLOSE Paises;

    IF Qtd = 0 THEN
        RAISE EXCEPTION 'Nenhum país encontrado com nome de até 15 caracteres.';
    END IF;
END;
$$ LANGUAGE plpgsql;

/* ------------------------------------------------------------------------------------------------------------
   Funções de dashboard do P4
   ------------------------------------------------------------------------------------------------------------ */
CREATE OR REPLACE FUNCTION p4_admin_counts()
RETURNS TABLE (
    total_pilotos BIGINT,
    total_escuderias BIGINT,
    total_temporadas BIGINT
)
LANGUAGE sql
STABLE
AS $$
    SELECT
        (SELECT COUNT(*) FROM drivers) AS total_pilotos,
        (SELECT COUNT(*) FROM constructors) AS total_escuderias,
        (SELECT COUNT(*) FROM seasons) AS total_temporadas;
$$;

CREATE OR REPLACE FUNCTION p4_admin_latest_races()
RETURNS TABLE (
    temporada INTEGER,
    corrida TEXT,
    circuito TEXT,
    data_corrida DATE,
    horario TIME,
    voltas_registradas INTEGER
)
LANGUAGE sql
STABLE
AS $$
    SELECT
        v.season_year AS temporada,
        v.race_name::TEXT AS corrida,
        v.circuit_name::TEXT AS circuito,
        v.race_date,
        v.race_time,
        MAX(v.laps)::INTEGER AS voltas_registradas
    FROM vw_p4_results_full v
    WHERE v.season_year = (SELECT MAX(year) FROM seasons)
    GROUP BY v.season_year, v.race_id, v.race_name, v.circuit_name, v.race_date, v.race_time, v.round
    ORDER BY v.round;
$$;

CREATE OR REPLACE FUNCTION p4_admin_latest_constructors_points()
RETURNS TABLE (
    temporada INTEGER,
    escuderia TEXT,
    total_pontos NUMERIC
)
LANGUAGE sql
STABLE
AS $$
    SELECT
        v.season_year AS temporada,
        v.constructor_name::TEXT AS escuderia,
        SUM(v.points)::NUMERIC(12,2) AS total_pontos
    FROM vw_p4_results_full v
    WHERE v.season_year = (SELECT MAX(year) FROM seasons)
    GROUP BY v.season_year, v.constructor_id, v.constructor_name
    ORDER BY 3 DESC, 2;
$$;

CREATE OR REPLACE FUNCTION p4_admin_latest_drivers_points()
RETURNS TABLE (
    temporada INTEGER,
    piloto TEXT,
    escuderia_mais_recente TEXT,
    total_pontos NUMERIC
)
LANGUAGE sql
STABLE
AS $$
    SELECT
        v.season_year AS temporada,
        v.driver_full_name::TEXT AS piloto,
        MAX(lc.constructor_name)::TEXT AS escuderia_mais_recente,
        SUM(v.points)::NUMERIC(12,2) AS total_pontos
    FROM vw_p4_results_full v
    LEFT JOIN vw_p4_driver_latest_constructor lc ON lc.driver_id = v.driver_id
    WHERE v.season_year = (SELECT MAX(year) FROM seasons)
    GROUP BY v.season_year, v.driver_id, v.driver_full_name
    ORDER BY 4 DESC, 2;
$$;

CREATE OR REPLACE FUNCTION p4_constructor_dashboard(p_constructor_id INTEGER)
RETURNS TABLE (
    escuderia TEXT,
    quantidade_vitorias BIGINT,
    quantidade_pilotos BIGINT,
    primeiro_ano INTEGER,
    ultimo_ano INTEGER
)
LANGUAGE sql
STABLE
AS $$
    SELECT
        c.name::TEXT AS escuderia,
        COUNT(*) FILTER (WHERE r.position_order = 1) AS quantidade_vitorias,
        COUNT(DISTINCT r.driver_id) AS quantidade_pilotos,
        MIN(s.year)::INTEGER AS primeiro_ano,
        MAX(s.year)::INTEGER AS ultimo_ano
    FROM constructors c
    LEFT JOIN results r ON r.constructor_id = c.id
    LEFT JOIN races ra ON ra.id = r.race_id
    LEFT JOIN seasons s ON s.id = ra.season_id
    WHERE c.id = p_constructor_id
    GROUP BY c.id, c.name;
$$;

CREATE OR REPLACE FUNCTION p4_driver_dashboard(p_driver_id INTEGER)
RETURNS TABLE (
    piloto TEXT,
    escuderia_mais_recente TEXT,
    primeiro_ano INTEGER,
    ultimo_ano INTEGER,
    ano INTEGER,
    circuito TEXT,
    pontos NUMERIC,
    vitorias BIGINT,
    total_corridas BIGINT
)
LANGUAGE sql
STABLE
AS $$
    WITH faixa AS (
        SELECT driver_id, MIN(season_year)::INTEGER AS primeiro_ano, MAX(season_year)::INTEGER AS ultimo_ano
        FROM vw_p4_results_full
        WHERE driver_id = p_driver_id
        GROUP BY driver_id
    )
    SELECT
        v.driver_full_name::TEXT AS piloto,
        lc.constructor_name::TEXT AS escuderia_mais_recente,
        f.primeiro_ano,
        f.ultimo_ano,
        v.season_year AS ano,
        v.circuit_name::TEXT AS circuito,
        SUM(v.points)::NUMERIC(12,2) AS pontos,
        COUNT(*) FILTER (WHERE v.position_order = 1) AS vitorias,
        COUNT(*) AS total_corridas
    FROM vw_p4_results_full v
    JOIN faixa f ON f.driver_id = v.driver_id
    LEFT JOIN vw_p4_driver_latest_constructor lc ON lc.driver_id = v.driver_id
    WHERE v.driver_id = p_driver_id
    GROUP BY v.driver_id, v.driver_full_name, lc.constructor_name, f.primeiro_ano, f.ultimo_ano, v.season_year, v.circuit_id, v.circuit_name
    ORDER BY v.season_year, v.circuit_name;
$$;

/* ------------------------------------------------------------------------------------------------------------
   Relatórios do P4
   ------------------------------------------------------------------------------------------------------------ */
CREATE OR REPLACE FUNCTION p4_report_admin_status_count()
RETURNS TABLE (status TEXT, quantidade BIGINT)
LANGUAGE sql
STABLE
AS $$
    SELECT st.status::TEXT AS status, COUNT(*) AS quantidade
    FROM results r
    JOIN status st ON st.id = r.status_id
    GROUP BY st.status
    ORDER BY COUNT(*) DESC, st.status;
$$;

CREATE OR REPLACE FUNCTION p4_report_admin_airports_near_city(p_nome_cidade TEXT)
RETURNS TABLE (
    cidade_pesquisada TEXT,
    codigo_iata TEXT,
    aeroporto TEXT,
    cidade_aeroporto TEXT,
    distancia_km NUMERIC,
    tipo_aeroporto TEXT
)
LANGUAGE sql
STABLE
AS $$
    WITH cidades_pesquisadas AS (
        SELECT id, name, latitude, longitude
        FROM vw_p4_cidades_brasileiras_todas
        WHERE name ILIKE p_nome_cidade
    ), candidatos AS (
        SELECT
            cp.name AS cidade_pesquisada,
            a.iata_code AS codigo_iata,
            a.airport_name AS aeroporto,
            a.airport_city AS cidade_aeroporto,
            a.airport_type AS tipo_aeroporto,
            earth_distance(
                ll_to_earth(cp.latitude::FLOAT8, cp.longitude::FLOAT8),
                ll_to_earth(a.latitude_deg::FLOAT8, a.longitude_deg::FLOAT8)
            ) AS distancia_metros
        FROM cidades_pesquisadas cp
        JOIN vw_p4_aeroportos_brasileiros_medium_large a
          ON earth_box(ll_to_earth(cp.latitude::FLOAT8, cp.longitude::FLOAT8), 100000)
             @> ll_to_earth(a.latitude_deg::FLOAT8, a.longitude_deg::FLOAT8)
    )
    SELECT
        c.cidade_pesquisada::TEXT,
        c.codigo_iata::TEXT,
        c.aeroporto::TEXT,
        c.cidade_aeroporto::TEXT,
        ROUND((c.distancia_metros / 1000.0)::NUMERIC, 3) AS distancia_km,
        c.tipo_aeroporto::TEXT
    FROM candidatos c
    WHERE c.distancia_metros <= 100000
    ORDER BY c.cidade_pesquisada, ROUND((c.distancia_metros / 1000.0)::NUMERIC, 3), c.aeroporto;
$$;

CREATE OR REPLACE FUNCTION p4_report_admin_constructor_driver_count()
RETURNS TABLE (escuderia TEXT, quantidade_pilotos BIGINT)
LANGUAGE sql
STABLE
AS $$
    SELECT
        c.name::TEXT AS escuderia,
        COUNT(DISTINCT h.driver_id) AS quantidade_pilotos
    FROM constructors c
    LEFT JOIN vw_p4_constructor_driver_history h ON h.constructor_id = c.id
    GROUP BY c.id, c.name
    ORDER BY c.name;
$$;

CREATE OR REPLACE FUNCTION p4_report_admin_races_total()
RETURNS TABLE (quantidade_corridas BIGINT)
LANGUAGE sql
STABLE
AS $$
    SELECT COUNT(*) FROM races;
$$;

CREATE OR REPLACE FUNCTION p4_report_admin_races_by_circuit()
RETURNS TABLE (
    circuito TEXT,
    quantidade_corridas BIGINT,
    minimo_voltas INTEGER,
    media_voltas NUMERIC,
    maximo_voltas INTEGER
)
LANGUAGE sql
STABLE
AS $$
    WITH voltas_por_corrida AS (
        SELECT
            ra.id AS race_id,
            cir.name AS circuito,
            MAX(r.laps)::INTEGER AS voltas
        FROM races ra
        JOIN circuits cir ON cir.id = ra.circuit_id
        LEFT JOIN results r ON r.race_id = ra.id
        GROUP BY ra.id, cir.name
    )
    SELECT
        vpc.circuito::TEXT AS circuito,
        COUNT(*) AS quantidade_corridas,
        MIN(vpc.voltas)::INTEGER AS minimo_voltas,
        ROUND(AVG(vpc.voltas)::NUMERIC, 2) AS media_voltas,
        MAX(vpc.voltas)::INTEGER AS maximo_voltas
    FROM voltas_por_corrida vpc
    GROUP BY vpc.circuito
    ORDER BY vpc.circuito;
$$;

CREATE OR REPLACE FUNCTION p4_report_admin_race_details()
RETURNS TABLE (
    circuito TEXT,
    corrida TEXT,
    ano INTEGER,
    voltas_registradas INTEGER,
    quantidade_pilotos BIGINT
)
LANGUAGE sql
STABLE
AS $$
    SELECT
        cir.name::TEXT AS circuito,
        ra.race_name::TEXT AS corrida,
        s.year::INTEGER AS ano,
        MAX(r.laps)::INTEGER AS voltas_registradas,
        COUNT(DISTINCT r.driver_id) AS quantidade_pilotos
    FROM races ra
    JOIN seasons s ON s.id = ra.season_id
    JOIN circuits cir ON cir.id = ra.circuit_id
    LEFT JOIN results r ON r.race_id = ra.id
    GROUP BY cir.name, ra.id, ra.race_name, s.year
    ORDER BY cir.name, s.year, ra.race_name;
$$;

CREATE OR REPLACE FUNCTION p4_report_constructor_driver_wins(p_constructor_id INTEGER)
RETURNS TABLE (piloto TEXT, quantidade_vitorias BIGINT)
LANGUAGE sql
STABLE
AS $$
    SELECT
        v.driver_full_name::TEXT AS piloto,
        COUNT(*) FILTER (WHERE v.position_order = 1) AS quantidade_vitorias
    FROM vw_p4_results_full v
    WHERE v.constructor_id = p_constructor_id
    GROUP BY v.driver_id, v.driver_full_name
    ORDER BY COUNT(*) FILTER (WHERE v.position_order = 1) DESC, v.driver_full_name;
$$;

CREATE OR REPLACE FUNCTION p4_report_constructor_status_count(p_constructor_id INTEGER)
RETURNS TABLE (status TEXT, quantidade BIGINT)
LANGUAGE sql
STABLE
AS $$
    SELECT
        v.status::TEXT AS status,
        COUNT(*) AS quantidade
    FROM vw_p4_results_full v
    WHERE v.constructor_id = p_constructor_id
    GROUP BY v.status
    ORDER BY COUNT(*) DESC, v.status;
$$;

/* DROP necessario: as colunas de retorno mudaram (total por ano + pontos por corrida),
   e o PostgreSQL nao permite CREATE OR REPLACE quando o tipo de retorno e alterado. */
DROP FUNCTION IF EXISTS p4_report_driver_points_by_year_race(INTEGER);

CREATE OR REPLACE FUNCTION p4_report_driver_points_by_year_race(
    p_driver_id INTEGER
)
RETURNS TABLE (
    ano INTEGER,
    total_pontos_ano NUMERIC,
    corrida TEXT,
    circuito TEXT,
    pontos_corrida NUMERIC
)
LANGUAGE sql
STABLE
AS $$
    /*
     * Relatório 6 do Piloto.
     *
     * O primeiro agrupamento calcula o total de pontos em cada ano
     * de participação do piloto.
     *
     * O segundo agrupamento identifica as corridas em que o piloto
     * efetivamente obteve pontos.
     *
     * O LEFT JOIN mantém também anos em que o piloto participou,
     * mas não pontuou.
     */
    WITH anos_participacao AS (
        SELECT
            v.season_year AS ano_participacao,
            COALESCE(SUM(v.points), 0)::NUMERIC(12,2)
                AS total_ano
        FROM vw_p4_results_full v
        WHERE v.driver_id = p_driver_id
        GROUP BY v.season_year
    ),
    corridas_pontuadas AS (
        SELECT
            v.season_year AS ano_participacao,
            v.race_id,
            v.round AS numero_rodada,
            v.race_name::TEXT AS nome_corrida,
            v.circuit_name::TEXT AS nome_circuito,
            SUM(v.points)::NUMERIC(12,2) AS pontos_obtidos
        FROM vw_p4_results_full v
        WHERE v.driver_id = p_driver_id
          AND v.points > 0
        GROUP BY
            v.season_year,
            v.race_id,
            v.round,
            v.race_name,
            v.circuit_name
    )
    SELECT
        a.ano_participacao,
        a.total_ano,
        c.nome_corrida,
        c.nome_circuito,
        c.pontos_obtidos
    FROM anos_participacao a
    LEFT JOIN corridas_pontuadas c
        ON c.ano_participacao = a.ano_participacao
    ORDER BY
        a.ano_participacao,
        c.numero_rodada NULLS LAST,
        c.nome_corrida;
$$;

CREATE OR REPLACE FUNCTION p4_report_driver_status_count(p_driver_id INTEGER)
RETURNS TABLE (status TEXT, quantidade BIGINT)
LANGUAGE sql
STABLE
AS $$
    SELECT
        v.status::TEXT AS status,
        COUNT(*) AS quantidade
    FROM vw_p4_results_full v
    WHERE v.driver_id = p_driver_id
    GROUP BY v.status
    ORDER BY COUNT(*) DESC, v.status;
$$;

/* ------------------------------------------------------------------------------------------------------------
   Ações do P4: cadastros e consulta por sobrenome
   ------------------------------------------------------------------------------------------------------------ */
CREATE OR REPLACE FUNCTION p4_create_constructor(
    p_constructor_ref TEXT,
    p_name TEXT,
    p_country_id INTEGER,
    p_wikipedia_url TEXT
)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_id INTEGER;
BEGIN
    IF p_country_id IS NULL THEN
        RAISE EXCEPTION 'country_id é obrigatório para cadastrar escuderia.';
    END IF;

    INSERT INTO constructors(constructor_ref, name, country_id, wikipedia_url)
    VALUES (LOWER(TRIM(p_constructor_ref)), p_name, p_country_id, p_wikipedia_url)
    RETURNING id INTO v_id;

    RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION p4_create_driver(
    p_driver_ref TEXT,
    p_given_name TEXT,
    p_family_name TEXT,
    p_date_of_birth DATE,
    p_country_id INTEGER
)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_id INTEGER;
BEGIN
    IF p_driver_ref IS NULL OR TRIM(p_driver_ref) = '' THEN
        RAISE EXCEPTION 'driver_ref é obrigatório para cadastrar piloto.';
    END IF;

    IF p_given_name IS NULL OR TRIM(p_given_name) = '' THEN
        RAISE EXCEPTION 'given_name é obrigatório para cadastrar piloto.';
    END IF;

    IF p_family_name IS NULL OR TRIM(p_family_name) = '' THEN
        RAISE EXCEPTION 'family_name é obrigatório para cadastrar piloto.';
    END IF;

    IF p_date_of_birth IS NULL THEN
        RAISE EXCEPTION 'date_of_birth é obrigatório para cadastrar piloto.';
    END IF;

    IF p_date_of_birth > CURRENT_DATE THEN
        RAISE EXCEPTION 'date_of_birth não pode ser uma data futura.';
    END IF;

    IF p_country_id IS NULL THEN
        RAISE EXCEPTION 'country_id é obrigatório para cadastrar piloto.';
    END IF;

    IF EXISTS (
        SELECT 1 FROM drivers
        WHERE LOWER(TRIM(given_name)) = LOWER(TRIM(p_given_name))
          AND LOWER(TRIM(family_name)) = LOWER(TRIM(p_family_name))
    ) THEN
        RAISE EXCEPTION 'Já existe piloto com o mesmo nome e sobrenome. Inserção cancelada.';
    END IF;

    INSERT INTO drivers(driver_ref, given_name, family_name, country_id, date_of_birth)
    VALUES (LOWER(TRIM(p_driver_ref)), TRIM(p_given_name), TRIM(p_family_name), p_country_id, p_date_of_birth)
    RETURNING id INTO v_id;

    RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION p4_create_driver_for_constructor(
    p_constructor_id INTEGER,
    p_driver_ref TEXT,
    p_given_name TEXT,
    p_family_name TEXT,
    p_date_of_birth DATE,
    p_country_id INTEGER
)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_driver_id INTEGER;
BEGIN
    v_driver_id := p4_create_driver(p_driver_ref, p_given_name, p_family_name, p_date_of_birth, p_country_id);

    INSERT INTO constructor_drivers(constructor_id, driver_id)
    VALUES (p_constructor_id, v_driver_id)
    ON CONFLICT DO NOTHING;

    RETURN v_driver_id;
END;
$$;

CREATE OR REPLACE FUNCTION p4_constructor_find_driver_by_family_name(
    p_constructor_id INTEGER,
    p_family_name TEXT
)
RETURNS TABLE (
    nome_completo TEXT,
    data_nascimento DATE,
    pais_ou_nacionalidade TEXT
)
LANGUAGE sql
STABLE
AS $$
    SELECT DISTINCT
        (d.given_name || ' ' || d.family_name)::TEXT AS nome_completo,
        d.date_of_birth AS data_nascimento,
        COALESCE(co.nationality, co.name)::TEXT AS pais_ou_nacionalidade
    FROM drivers d
    JOIN countries co ON co.id = d.country_id
    JOIN results r ON r.driver_id = d.id
    WHERE r.constructor_id = p_constructor_id
      AND LOWER(d.family_name) = LOWER(TRIM(p_family_name))
    ORDER BY 1;
$$;

COMMIT;
