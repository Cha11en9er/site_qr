-- =============================================================================
-- 00_database.sql — подготовка сервера (DBeaver)
-- =============================================================================
-- Этот файл НЕ создаёт таблицы. Только роль и права на подключение.
--
-- ШАГ 1. Создайте базу через DBeaver (GUI, не SQL):
--   Database Navigator → ваш PostgreSQL → Databases → ПКМ → Create → Database
--   • Database name:  qr_pamyat
--   • Encoding:       UTF8
--   • Collation:      по умолчанию (или ru_RU.UTF-8 если доступно)
--
-- ШАГ 2. Подключитесь к базе postgres (НЕ к qr_pamyat) и выполните блок ниже.
--        В DBeaver: выделите код → Alt+Enter (Execute Statement)
-- =============================================================================

-- Роль приложения. ИЗМЕНИТЕ ПАРОЛЬ перед продакшеном!
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'qr_app') THEN
        CREATE ROLE qr_app WITH
            LOGIN
            PASSWORD 'qr_app'
            NOSUPERUSER
            NOCREATEDB
            NOCREATEROLE;
    END IF;
END
$$;

GRANT CONNECT ON DATABASE qr_pamyat TO qr_app;

-- =============================================================================
-- ШАГ 3. Подключитесь к базе qr_pamyat и выполните ОДИН из вариантов:
--
--   Вариант A (быстро):  00_full_schema.sql  — весь скрипт целиком
--   Вариант B (пошагово): 01 → 02 → … → 13  — по одному файлу
--
-- В DBeaver для длинного скрипта: Alt+X (Execute SQL Script)
-- =============================================================================
