-- =============================================================================
-- 13_grants.sql
-- Права для роли приложения. Выполнять от владельца таблиц (postgres / qr_app).
-- =============================================================================

-- Если таблицы созданы от postgres, а приложение — qr_app:
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'qr_app') THEN
        GRANT USAGE ON SCHEMA public TO qr_app;
        GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO qr_app;
        GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO qr_app;
        ALTER DEFAULT PRIVILEGES IN SCHEMA public
            GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO qr_app;
        ALTER DEFAULT PRIVILEGES IN SCHEMA public
            GRANT USAGE, SELECT ON SEQUENCES TO qr_app;
    END IF;
END;
$$;
