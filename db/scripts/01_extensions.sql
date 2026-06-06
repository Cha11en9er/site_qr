-- =============================================================================
-- 01_extensions.sql
-- Расширения PostgreSQL. Выполнять внутри БД qr_pamyat.
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;   -- gen_random_uuid(), crypt()
CREATE EXTENSION IF NOT EXISTS citext;     -- email без учёта регистра
