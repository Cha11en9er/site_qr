-- =============================================================================
-- 09_grants.sql
-- Права для роли приложения. Выполнять от владельца таблиц (postgres / qr_app).
-- Схема приложения: qr (не public).
-- =============================================================================

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'qr_app') THEN
        GRANT USAGE ON SCHEMA qr TO qr_app;
        ALTER ROLE qr_app SET search_path TO qr, public;

        -- Чтение справочников и ORM-select; запись только через sp_* функции
        GRANT SELECT ON ALL TABLES IN SCHEMA qr TO qr_app;
        REVOKE INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA qr FROM qr_app;

        GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA qr TO qr_app;

        GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA qr TO qr_app;

        ALTER DEFAULT PRIVILEGES IN SCHEMA qr
            GRANT SELECT ON TABLES TO qr_app;
        ALTER DEFAULT PRIVILEGES IN SCHEMA qr
            REVOKE INSERT, UPDATE, DELETE ON TABLES FROM qr_app;
        ALTER DEFAULT PRIVILEGES IN SCHEMA qr
            GRANT USAGE, SELECT ON SEQUENCES TO qr_app;
        ALTER DEFAULT PRIVILEGES IN SCHEMA qr
            GRANT EXECUTE ON FUNCTIONS TO qr_app;
    END IF;
END;
$$;
