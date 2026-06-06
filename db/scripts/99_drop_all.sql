-- =============================================================================
-- 99_drop_all.sql
-- ОПАСНО: полное удаление всех таблиц. Только dev / тестовая БД!
--
-- DBeaver: подключиться к qr_pamyat → Alt+X (Execute SQL Script)
-- =============================================================================

DROP SCHEMA public CASCADE;
CREATE SCHEMA public;
GRANT ALL ON SCHEMA public TO public;
GRANT ALL ON SCHEMA public TO qr_app;

-- После сброса снова выполните 00_full_schema.sql (или 01 … 13)
