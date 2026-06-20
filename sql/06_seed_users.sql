/* ============================================================================================================
   06_seed_users.sql
   ------------------------------------------------------------------------------------------------------------
   Faz SOMENTE a carga dos usuários iniciais do P4:
   - admin/admin;
   - um usuário para cada escuderia: <constructor_ref>_c / <constructor_ref>;
   - um usuário para cada piloto: <driver_ref>_d / <driver_ref>.

   As senhas são armazenadas com hash via pgcrypto/crypt, e não em texto puro.
   ============================================================================================================ */

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

INSERT INTO users (login, password, tipo, id_original)
VALUES ('admin', crypt('admin', gen_salt('bf')), 'Admin', NULL)
ON CONFLICT (login) DO UPDATE
SET password = EXCLUDED.password,
    tipo = EXCLUDED.tipo,
    id_original = EXCLUDED.id_original,
    updated_at = CURRENT_TIMESTAMP;

INSERT INTO users (login, password, tipo, id_original)
SELECT
    LOWER(TRIM(c.constructor_ref)) || '_c',
    crypt(TRIM(c.constructor_ref), gen_salt('bf')),
    'Escuderia',
    c.id
FROM constructors c
WHERE c.constructor_ref IS NOT NULL AND TRIM(c.constructor_ref) <> ''
ON CONFLICT (login) DO UPDATE
SET password = EXCLUDED.password,
    tipo = EXCLUDED.tipo,
    id_original = EXCLUDED.id_original,
    updated_at = CURRENT_TIMESTAMP;

INSERT INTO users (login, password, tipo, id_original)
SELECT
    LOWER(TRIM(d.driver_ref)) || '_d',
    crypt(TRIM(d.driver_ref), gen_salt('bf')),
    'Piloto',
    d.id
FROM drivers d
WHERE d.driver_ref IS NOT NULL AND TRIM(d.driver_ref) <> ''
ON CONFLICT (login) DO UPDATE
SET password = EXCLUDED.password,
    tipo = EXCLUDED.tipo,
    id_original = EXCLUDED.id_original,
    updated_at = CURRENT_TIMESTAMP;

COMMIT;
