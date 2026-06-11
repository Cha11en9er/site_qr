-- =============================================================================
-- 99_drop_all.sql
-- ОПАСНО: полное удаление прикладной схемы. Только dev / тестовая БД!
--
-- DBeaver: подключиться к qr_pamyat → Alt+X (Execute SQL Script)
-- =============================================================================

DROP SCHEMA IF EXISTS qr CASCADE;

CREATE SCHEMA qr;
COMMENT ON SCHEMA qr IS 'QR Память: таблицы, триггеры fn_*, процедуры sp_*';

REVOKE ALL ON SCHEMA qr FROM PUBLIC;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'qr_app') THEN
        GRANT USAGE ON SCHEMA qr TO qr_app;
        ALTER ROLE qr_app SET search_path TO qr, public;
    END IF;
END;
$$;

-- public не трогаем (расширения pgcrypto, citext остаются там)
-- После сброса снова выполните 00_full_schema.sql (или 01_init … 09_grants по шагам)
