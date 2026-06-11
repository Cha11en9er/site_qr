-- =============================================================================
-- 01_init.sql
-- Расширения PostgreSQL. Выполнять внутри БД qr_pamyat.
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;   -- gen_random_uuid(), crypt()
CREATE EXTENSION IF NOT EXISTS citext;     -- email без учёта регистра

-- =============================================================================
-- Прикладная схема (все таблицы, триггеры, sp_* — не в public)
-- =============================================================================
CREATE SCHEMA IF NOT EXISTS qr;

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
