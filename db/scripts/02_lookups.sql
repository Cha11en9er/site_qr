-- =============================================================================
-- 02_lookups.sql
-- Справочники (3NF): статусы и типы вынесены из основных таблиц.
-- =============================================================================

-- Роли пользователей
CREATE TABLE user_roles (
    id          SMALLSERIAL PRIMARY KEY,
    code        VARCHAR(32)  NOT NULL,
    name        VARCHAR(128) NOT NULL,
    CONSTRAINT uq_user_roles_code UNIQUE (code)
);

-- Пакеты QR (цены и лимиты — единственный источник истины для каталога)
CREATE TABLE package_types (
    id                  SMALLSERIAL PRIMARY KEY,
    code                VARCHAR(32)   NOT NULL,
    name                VARCHAR(128)  NOT NULL,
    price_rub           NUMERIC(12,2) NOT NULL,
    max_photos          INTEGER       NOT NULL,
    max_video_seconds   INTEGER       NOT NULL,
    is_active           BOOLEAN       NOT NULL DEFAULT TRUE,
    sort_order          SMALLINT      NOT NULL DEFAULT 0,
    created_at          TIMESTAMPTZ   NOT NULL DEFAULT now(),
    CONSTRAINT uq_package_types_code UNIQUE (code),
    CONSTRAINT chk_package_types_price     CHECK (price_rub >= 0),
    CONSTRAINT chk_package_types_photos    CHECK (max_photos >= 0),
    CONSTRAINT chk_package_types_video_sec CHECK (max_video_seconds >= 0)
);

-- Статусы заказа
CREATE TABLE order_statuses (
    id          SMALLSERIAL PRIMARY KEY,
    code        VARCHAR(32)  NOT NULL,
    name        VARCHAR(128) NOT NULL,
    is_terminal BOOLEAN      NOT NULL DEFAULT FALSE,
    CONSTRAINT uq_order_statuses_code UNIQUE (code)
);

-- Статусы платежа
CREATE TABLE payment_statuses (
    id          SMALLSERIAL PRIMARY KEY,
    code        VARCHAR(32)  NOT NULL,
    name        VARCHAR(128) NOT NULL,
    is_terminal BOOLEAN      NOT NULL DEFAULT FALSE,
    CONSTRAINT uq_payment_statuses_code UNIQUE (code)
);

-- Статусы QR-кода
CREATE TABLE qr_code_statuses (
    id          SMALLSERIAL PRIMARY KEY,
    code        VARCHAR(32)  NOT NULL,
    name        VARCHAR(128) NOT NULL,
    CONSTRAINT uq_qr_code_statuses_code UNIQUE (code)
);

-- Статусы доставки физической плашки
CREATE TABLE fulfillment_statuses (
    id          SMALLSERIAL PRIMARY KEY,
    code        VARCHAR(32)  NOT NULL,
    name        VARCHAR(128) NOT NULL,
    CONSTRAINT uq_fulfillment_statuses_code UNIQUE (code)
);

-- Типы медиа
CREATE TABLE media_types (
    id          SMALLSERIAL PRIMARY KEY,
    code        VARCHAR(32)  NOT NULL,
    name        VARCHAR(128) NOT NULL,
    CONSTRAINT uq_media_types_code UNIQUE (code)
);

-- Статусы обработки файла (thumb, транскодинг)
CREATE TABLE media_processing_statuses (
    id          SMALLSERIAL PRIMARY KEY,
    code        VARCHAR(32)  NOT NULL,
    name        VARCHAR(128) NOT NULL,
    CONSTRAINT uq_media_processing_statuses_code UNIQUE (code)
);

-- Модерация отзывов
CREATE TABLE review_moderation_statuses (
    id          SMALLSERIAL PRIMARY KEY,
    code        VARCHAR(32)  NOT NULL,
    name        VARCHAR(128) NOT NULL,
    CONSTRAINT uq_review_moderation_statuses_code UNIQUE (code)
);

-- Типы уведомлений (чек, QR, инструкции)
CREATE TABLE notification_types (
    id          SMALLSERIAL PRIMARY KEY,
    code        VARCHAR(32)  NOT NULL,
    name        VARCHAR(256) NOT NULL,
    CONSTRAINT uq_notification_types_code UNIQUE (code)
);
