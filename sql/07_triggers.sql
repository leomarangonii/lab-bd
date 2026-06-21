/* ============================================================================================================
   07_triggers.sql - Triggers de sincronização de usuários

   Objetivo:
   - ao inserir/atualizar DRIVERS, sincronizar USERS;
   - ao inserir/atualizar CONSTRUCTORS, sincronizar USERS;
   - se o login gerado já pertencer a outro usuário, cancelar operação com RAISE EXCEPTION.
   ============================================================================================================ */

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

DROP TRIGGER IF EXISTS tr_sync_driver_user ON drivers;
DROP FUNCTION IF EXISTS sync_driver_user();

-- sync_driver_user: aciona após inserir piloto ou alterar driver_ref; cria/atualiza usuário Piloto e bloqueia login duplicado.
CREATE OR REPLACE FUNCTION sync_driver_user()
RETURNS TRIGGER AS $$
DECLARE
    v_login TEXT;
    v_senha TEXT;
BEGIN
    IF NEW.driver_ref IS NULL OR TRIM(NEW.driver_ref) = '' THEN
        RAISE EXCEPTION 'driver_ref não pode ser vazio, pois ele gera o login do piloto.';
    END IF;

    v_login := LOWER(TRIM(NEW.driver_ref)) || '_d';
    v_senha := TRIM(NEW.driver_ref);

    IF EXISTS (
        SELECT 1
        FROM users u
        WHERE u.login = v_login
          AND NOT (u.tipo = 'Piloto' AND u.id_original = NEW.id)
    ) THEN
        RAISE EXCEPTION 'Login % já existe. Operação cancelada.', v_login;
    END IF;

    IF EXISTS (SELECT 1 FROM users u WHERE u.tipo = 'Piloto' AND u.id_original = NEW.id) THEN
        UPDATE users
        SET login = v_login,
            password = crypt(v_senha, gen_salt('bf')),
            updated_at = CURRENT_TIMESTAMP
        WHERE tipo = 'Piloto'
          AND id_original = NEW.id;
    ELSE
        INSERT INTO users(login, password, tipo, id_original)
        VALUES (v_login, crypt(v_senha, gen_salt('bf')), 'Piloto', NEW.id);
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

/* tr_sync_driver_user: ativa AFTER INSERT OR UPDATE OF driver_ref em drivers, para manter users sincronizada automaticamente. */
CREATE TRIGGER tr_sync_driver_user
AFTER INSERT OR UPDATE OF driver_ref ON drivers
FOR EACH ROW
EXECUTE FUNCTION sync_driver_user();

DROP TRIGGER IF EXISTS tr_sync_constructor_user ON constructors;
DROP FUNCTION IF EXISTS sync_constructor_user();

-- sync_constructor_user: aciona após inserir escuderia ou alterar constructor_ref; cria/atualiza usuário Escuderia e bloqueia login duplicado.
CREATE OR REPLACE FUNCTION sync_constructor_user()
RETURNS TRIGGER AS $$
DECLARE
    v_login TEXT;
    v_senha TEXT;
BEGIN
    IF NEW.constructor_ref IS NULL OR TRIM(NEW.constructor_ref) = '' THEN
        RAISE EXCEPTION 'constructor_ref não pode ser vazio, pois ele gera o login da escuderia.';
    END IF;

    v_login := LOWER(TRIM(NEW.constructor_ref)) || '_c';
    v_senha := TRIM(NEW.constructor_ref);

    IF EXISTS (
        SELECT 1
        FROM users u
        WHERE u.login = v_login
          AND NOT (u.tipo = 'Escuderia' AND u.id_original = NEW.id)
    ) THEN
        RAISE EXCEPTION 'Login % já existe. Operação cancelada.', v_login;
    END IF;

    IF EXISTS (SELECT 1 FROM users u WHERE u.tipo = 'Escuderia' AND u.id_original = NEW.id) THEN
        UPDATE users
        SET login = v_login,
            password = crypt(v_senha, gen_salt('bf')),
            updated_at = CURRENT_TIMESTAMP
        WHERE tipo = 'Escuderia'
          AND id_original = NEW.id;
    ELSE
        INSERT INTO users(login, password, tipo, id_original)
        VALUES (v_login, crypt(v_senha, gen_salt('bf')), 'Escuderia', NEW.id);
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

/* tr_sync_constructor_user: ativa AFTER INSERT OR UPDATE OF constructor_ref em constructors, para manter users sincronizada automaticamente. */
CREATE TRIGGER tr_sync_constructor_user
AFTER INSERT OR UPDATE OF constructor_ref ON constructors
FOR EACH ROW
EXECUTE FUNCTION sync_constructor_user();

COMMIT;
