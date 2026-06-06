-- =============================================================================
-- 00_full_schema.sql — ПОЛНАЯ СХЕМА (для DBeaver)
-- =============================================================================
-- Подключение: база qr_pamyat
-- Выполнение:  Alt+X (Execute SQL Script)
--
-- Содержит скрипты 01–13. Отдельные файлы — для пошаговой отладки.
-- Сгенерировано из частей; при изменении правьте 01–13 и пересоберите.
-- =============================================================================


-- ########## 01_extensions.sql ##########

-- =============================================================================
-- 01_extensions.sql
-- Расширения PostgreSQL. Выполнять внутри БД qr_pamyat.
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;   -- gen_random_uuid(), crypt()
CREATE EXTENSION IF NOT EXISTS citext;     -- email без учёта регистра


-- ########## 02_lookups.sql ##########

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


-- ########## 03_users_auth.sql ##########

-- =============================================================================
-- 03_users_auth.sql
-- Пользователи, сессии, сброс пароля. Без дублирования email (citext + partial unique).
-- =============================================================================

CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    role_id         SMALLINT     NOT NULL REFERENCES user_roles (id),
    email           CITEXT       NOT NULL,
    phone           VARCHAR(20),
    password_hash   VARCHAR(255) NOT NULL,
    full_name       VARCHAR(256),
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    email_verified  BOOLEAN      NOT NULL DEFAULT FALSE,
    must_change_password BOOLEAN NOT NULL DEFAULT FALSE,
    last_login_at   TIMESTAMPTZ,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    deleted_at      TIMESTAMPTZ,
    CONSTRAINT chk_users_phone_format CHECK (
        phone IS NULL OR phone ~ '^\+[0-9]{10,15}$'
    )
);

-- Один email = один активный аккаунт (мягкое удаление не блокирует повторную регистрацию)
CREATE UNIQUE INDEX uq_users_email_active
    ON users (email)
    WHERE deleted_at IS NULL;

CREATE INDEX idx_users_role_id ON users (role_id);
CREATE INDEX idx_users_created_at ON users (created_at);

-- Refresh-токены (JWT rotation)
CREATE TABLE refresh_tokens (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID         NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    token_hash      VARCHAR(128) NOT NULL,
    expires_at      TIMESTAMPTZ  NOT NULL,
    revoked_at      TIMESTAMPTZ,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    user_agent      VARCHAR(512),
    ip_address      INET,
    CONSTRAINT uq_refresh_tokens_hash UNIQUE (token_hash)
);

CREATE INDEX idx_refresh_tokens_user_id ON refresh_tokens (user_id);
CREATE INDEX idx_refresh_tokens_expires ON refresh_tokens (expires_at) WHERE revoked_at IS NULL;

-- Сброс пароля (одноразовые токены)
CREATE TABLE password_reset_tokens (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID         NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    token_hash      VARCHAR(128) NOT NULL,
    expires_at      TIMESTAMPTZ  NOT NULL,
    used_at         TIMESTAMPTZ,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT uq_password_reset_token_hash UNIQUE (token_hash)
);

CREATE INDEX idx_password_reset_user ON password_reset_tokens (user_id);

-- Согласие на обработку ПДн (152-ФЗ)
CREATE TABLE user_consents (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID         REFERENCES users (id) ON DELETE SET NULL,
    email           CITEXT,
    consent_type    VARCHAR(64)  NOT NULL,  -- privacy_policy, offer, pd_processing
    consent_version VARCHAR(32)  NOT NULL,
    ip_address      INET,
    user_agent      VARCHAR(512),
    accepted_at     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT chk_user_consents_actor CHECK (user_id IS NOT NULL OR email IS NOT NULL)
);

CREATE INDEX idx_user_consents_user ON user_consents (user_id);


-- ########## 04_orders.sql ##########

-- =============================================================================
-- 04_orders.sql
-- Заказы, позиции (снимок цены), доставка. Гостевой checkout: user_id nullable.
-- =============================================================================

CREATE TABLE orders (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_number    BIGINT GENERATED ALWAYS AS IDENTITY,
    user_id         UUID REFERENCES users (id) ON DELETE SET NULL,
    status_id       SMALLINT      NOT NULL REFERENCES order_statuses (id),
    buyer_email     CITEXT        NOT NULL,
    buyer_phone     VARCHAR(20)   NOT NULL,
    buyer_name      VARCHAR(256)  NOT NULL,  -- ФИО или организация
    currency        CHAR(3)       NOT NULL DEFAULT 'RUB',
    total_amount    NUMERIC(12,2) NOT NULL,
    notes           TEXT,
    paid_at         TIMESTAMPTZ,
    cancelled_at    TIMESTAMPTZ,
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ   NOT NULL DEFAULT now(),
    CONSTRAINT chk_orders_total_amount CHECK (total_amount >= 0),
    CONSTRAINT chk_orders_buyer_phone CHECK (buyer_phone ~ '^\+[0-9]{10,15}$')
);

CREATE UNIQUE INDEX uq_orders_order_number ON orders (order_number);
CREATE INDEX idx_orders_user_id ON orders (user_id);
CREATE INDEX idx_orders_status_id ON orders (status_id);
CREATE INDEX idx_orders_buyer_email ON orders (buyer_email);
CREATE INDEX idx_orders_created_at ON orders (created_at DESC);

-- Позиция заказа: снимок цены и лимитов на момент покупки (3NF — не зависит от будущих изменений package_types)
CREATE TABLE order_lines (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id                UUID          NOT NULL REFERENCES orders (id) ON DELETE CASCADE,
    package_type_id         SMALLINT      NOT NULL REFERENCES package_types (id),
    quantity                INTEGER       NOT NULL,
    unit_price_rub          NUMERIC(12,2) NOT NULL,
    line_total_rub          NUMERIC(12,2) NOT NULL,
    -- Снимок лимитов пакета на момент заказа
    snapshot_max_photos     INTEGER       NOT NULL,
    snapshot_max_video_sec  INTEGER       NOT NULL,
    snapshot_package_name   VARCHAR(128)  NOT NULL,
    created_at              TIMESTAMPTZ   NOT NULL DEFAULT now(),
    CONSTRAINT uq_order_lines_one_per_order UNIQUE (order_id),
    CONSTRAINT chk_order_lines_quantity    CHECK (quantity BETWEEN 1 AND 50),
    CONSTRAINT chk_order_lines_unit_price  CHECK (unit_price_rub >= 0),
    CONSTRAINT chk_order_lines_line_total    CHECK (line_total_rub >= 0)
);

CREATE INDEX idx_order_lines_package ON order_lines (package_type_id);

-- Доставка физической плашки (1:1 с заказом)
CREATE TABLE order_deliveries (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id                UUID         NOT NULL REFERENCES orders (id) ON DELETE CASCADE,
    fulfillment_status_id   SMALLINT     NOT NULL REFERENCES fulfillment_statuses (id),
    delivery_address        TEXT         NOT NULL,
    postal_code             VARCHAR(16),
    city                    VARCHAR(128),
    tracking_number         VARCHAR(64),
    shipped_at              TIMESTAMPTZ,
    delivered_at            TIMESTAMPTZ,
    created_at              TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at              TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT uq_order_deliveries_order UNIQUE (order_id)
);

CREATE INDEX idx_order_deliveries_status ON order_deliveries (fulfillment_status_id);


-- ########## 05_payments.sql ##########

-- =============================================================================
-- 05_payments.sql
-- Платежи ЮKassa, webhook-события (идемпотентность), защита от двойной оплаты.
-- =============================================================================

CREATE TABLE payments (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id                UUID          NOT NULL REFERENCES orders (id) ON DELETE RESTRICT,
    status_id               SMALLINT      NOT NULL REFERENCES payment_statuses (id),
    provider                VARCHAR(32)   NOT NULL DEFAULT 'yookassa',
    provider_payment_id     VARCHAR(64),
    idempotence_key         UUID          NOT NULL,
    amount_rub              NUMERIC(12,2) NOT NULL,
    currency                CHAR(3)       NOT NULL DEFAULT 'RUB',
    payment_method          VARCHAR(32),   -- card, sbp, sberpay
    receipt_url             TEXT,
    receipt_fiscal_id       VARCHAR(128),
    confirmation_url        TEXT,
    error_code              VARCHAR(64),
    error_message           TEXT,
    paid_at                 TIMESTAMPTZ,
    created_at              TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_at              TIMESTAMPTZ   NOT NULL DEFAULT now(),
    CONSTRAINT chk_payments_amount CHECK (amount_rub >= 0),
    CONSTRAINT uq_payments_idempotence_key UNIQUE (idempotence_key)
);

-- Один успешный платёж на заказ — триггер trg_payments_one_succeeded в 11_functions_triggers.sql

CREATE UNIQUE INDEX uq_payments_provider_payment_id
    ON payments (provider, provider_payment_id)
    WHERE provider_payment_id IS NOT NULL;

CREATE INDEX idx_payments_order_id ON payments (order_id);
CREATE INDEX idx_payments_status ON payments (status_id);
CREATE INDEX idx_payments_created_at ON payments (created_at DESC);

-- Webhook от ЮKassa: храним сырые события для идемпотентной обработки
CREATE TABLE payment_webhook_events (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider            VARCHAR(32)  NOT NULL DEFAULT 'yookassa',
    provider_event_id   VARCHAR(128) NOT NULL,
    event_type          VARCHAR(64)  NOT NULL,
    provider_payment_id VARCHAR(64),
    payload             JSONB        NOT NULL,
    processed_at        TIMESTAMPTZ,
    processing_error    TEXT,
    received_at         TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT uq_payment_webhook_events_provider UNIQUE (provider, provider_event_id)
);

CREATE INDEX idx_payment_webhook_payment_id ON payment_webhook_events (provider_payment_id);
CREATE INDEX idx_payment_webhook_unprocessed ON payment_webhook_events (received_at)
    WHERE processed_at IS NULL;


-- ########## 06_qr_codes.sql ##########

-- =============================================================================
-- 06_qr_codes.sql
-- QR-коды: короткий slug для /r/{slug}, привязка к заказу и мемориалу.
-- =============================================================================

CREATE TABLE qr_codes (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id        UUID         NOT NULL REFERENCES orders (id) ON DELETE RESTRICT,
    order_line_id   UUID         NOT NULL REFERENCES order_lines (id) ON DELETE RESTRICT,
    status_id       SMALLINT     NOT NULL REFERENCES qr_code_statuses (id),
    code_slug       VARCHAR(16)  NOT NULL,   -- URL: /r/Ab3xK9mN
    sequence_num    INTEGER      NOT NULL,   -- номер в реестре заказа: 1..N
    memorial_id     UUID,                    -- FK добавляется в 07_memorials.sql
    scan_count      INTEGER      NOT NULL DEFAULT 0,
    first_scanned_at TIMESTAMPTZ,
    last_scanned_at  TIMESTAMPTZ,
    activated_at    TIMESTAMPTZ,
    suspended_at    TIMESTAMPTZ,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT uq_qr_codes_slug UNIQUE (code_slug),
    CONSTRAINT uq_qr_codes_order_sequence UNIQUE (order_id, sequence_num),
    CONSTRAINT chk_qr_codes_sequence CHECK (sequence_num >= 1),
    CONSTRAINT chk_qr_codes_scan_count CHECK (scan_count >= 0)
);

CREATE INDEX idx_qr_codes_order_id ON qr_codes (order_id);
CREATE INDEX idx_qr_codes_status_id ON qr_codes (status_id);
CREATE INDEX idx_qr_codes_memorial_id ON qr_codes (memorial_id) WHERE memorial_id IS NOT NULL;

-- Детальная аналитика сканов (опционально; счётчик в qr_codes — для дашборда)
CREATE TABLE qr_scan_events (
    id              BIGSERIAL PRIMARY KEY,
    qr_code_id      UUID         NOT NULL REFERENCES qr_codes (id) ON DELETE CASCADE,
    scanned_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    ip_hash         VARCHAR(64),   -- SHA256 IP, не храним сырой IP вечно
    user_agent      VARCHAR(512),
    referer         VARCHAR(512)
);

CREATE INDEX idx_qr_scan_events_qr_code ON qr_scan_events (qr_code_id, scanned_at DESC);


-- ########## 07_memorials.sql ##########

-- =============================================================================
-- 07_memorials.sql
-- Мемориальные страницы. Лимиты пакета — снимок из order_lines при активации QR.
-- =============================================================================

CREATE TABLE memorials (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id           UUID          NOT NULL REFERENCES users (id) ON DELETE RESTRICT,
    public_slug             VARCHAR(64)   NOT NULL,  -- URL: /m/{slug}
    deceased_full_name      VARCHAR(256)  NOT NULL,
    birth_date              DATE,
    death_date              DATE,
    father_full_name        VARCHAR(256),
    mother_full_name        VARCHAR(256),
    epitaph                 VARCHAR(500),
    -- Геолокация могилы
    grave_latitude          NUMERIC(10, 7),
    grave_longitude         NUMERIC(10, 7),
    grave_location_label    VARCHAR(256),
    -- Лимиты из пакета на момент активации (снимок, не JOIN к package_types)
    package_type_id         SMALLINT      NOT NULL REFERENCES package_types (id),
    max_photos              INTEGER       NOT NULL,
    max_video_seconds       INTEGER       NOT NULL,
    is_published            BOOLEAN       NOT NULL DEFAULT FALSE,
    published_at            TIMESTAMPTZ,
    created_at              TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_at              TIMESTAMPTZ   NOT NULL DEFAULT now(),
    deleted_at              TIMESTAMPTZ,
    CONSTRAINT uq_memorials_public_slug UNIQUE (public_slug),
    CONSTRAINT chk_memorials_dates CHECK (
        birth_date IS NULL OR death_date IS NULL OR birth_date <= death_date
    ),
    CONSTRAINT chk_memorials_lat CHECK (
        grave_latitude IS NULL OR (grave_latitude BETWEEN -90 AND 90)
    ),
    CONSTRAINT chk_memorials_lon CHECK (
        grave_longitude IS NULL OR (grave_longitude BETWEEN -180 AND 180)
    ),
    CONSTRAINT chk_memorials_max_photos CHECK (max_photos >= 0),
    CONSTRAINT chk_memorials_max_video CHECK (max_video_seconds >= 0)
);

CREATE INDEX idx_memorials_owner ON memorials (owner_user_id);
CREATE INDEX idx_memorials_published ON memorials (is_published) WHERE deleted_at IS NULL;
CREATE INDEX idx_memorials_created_at ON memorials (created_at DESC);

-- FK qr_codes → memorials (циклическая зависимость решена порядком скриптов)
ALTER TABLE qr_codes
    ADD CONSTRAINT fk_qr_codes_memorial
    FOREIGN KEY (memorial_id) REFERENCES memorials (id) ON DELETE SET NULL;

-- Один активный QR на мемориал (нельзя привязать два кода к одной странице)
CREATE UNIQUE INDEX uq_qr_codes_one_per_memorial
    ON qr_codes (memorial_id)
    WHERE memorial_id IS NOT NULL;


-- ########## 08_media.sql ##########

-- =============================================================================
-- 08_media.sql
-- Медиафайлы в Object Storage. Уникальный storage_key, контроль лимитов — триггер.
-- =============================================================================

CREATE TABLE media_upload_sessions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    memorial_id     UUID         NOT NULL REFERENCES memorials (id) ON DELETE CASCADE,
    user_id         UUID         NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    media_type_id   SMALLINT     NOT NULL REFERENCES media_types (id),
    storage_key     VARCHAR(512) NOT NULL,
    expected_mime   VARCHAR(128) NOT NULL,
    max_size_bytes  BIGINT       NOT NULL,
    presigned_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    expires_at      TIMESTAMPTZ  NOT NULL,
    confirmed_at    TIMESTAMPTZ,
    cancelled_at    TIMESTAMPTZ,
    CONSTRAINT uq_media_upload_sessions_storage_key UNIQUE (storage_key),
    CONSTRAINT chk_media_upload_max_size CHECK (max_size_bytes > 0)
);

CREATE INDEX idx_media_upload_sessions_memorial ON media_upload_sessions (memorial_id);
CREATE INDEX idx_media_upload_pending ON media_upload_sessions (expires_at)
    WHERE confirmed_at IS NULL AND cancelled_at IS NULL;

CREATE TABLE media_files (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    memorial_id             UUID          NOT NULL REFERENCES memorials (id) ON DELETE CASCADE,
    upload_session_id       UUID          REFERENCES media_upload_sessions (id) ON DELETE SET NULL,
    media_type_id           SMALLINT      NOT NULL REFERENCES media_types (id),
    processing_status_id    SMALLINT      NOT NULL REFERENCES media_processing_statuses (id),
    uploaded_by_user_id     UUID          NOT NULL REFERENCES users (id) ON DELETE RESTRICT,
    storage_bucket          VARCHAR(128)  NOT NULL,
    storage_key             VARCHAR(512)  NOT NULL,
    thumb_storage_key       VARCHAR(512),
    original_filename       VARCHAR(256)  NOT NULL,
    mime_type               VARCHAR(128)  NOT NULL,
    size_bytes              BIGINT        NOT NULL,
    width_px                INTEGER,
    height_px               INTEGER,
    duration_seconds        INTEGER,      -- только для video
    sort_order              INTEGER       NOT NULL DEFAULT 0,
    created_at              TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_at              TIMESTAMPTZ   NOT NULL DEFAULT now(),
    deleted_at              TIMESTAMPTZ,
    CONSTRAINT uq_media_files_storage_key UNIQUE (storage_key),
    CONSTRAINT chk_media_files_size CHECK (size_bytes > 0),
    CONSTRAINT chk_media_files_duration CHECK (
        duration_seconds IS NULL OR duration_seconds >= 0
    ),
    CONSTRAINT chk_media_files_dimensions CHECK (
        (width_px IS NULL AND height_px IS NULL)
        OR (width_px > 0 AND height_px > 0)
    )
);

CREATE INDEX idx_media_files_memorial ON media_files (memorial_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_media_files_type ON media_files (memorial_id, media_type_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_media_files_sort ON media_files (memorial_id, sort_order);

-- Не более одного фото могилы — триггер trg_media_one_grave_photo в 11_functions_triggers.sql


-- ########## 09_reviews.sql ##########

-- =============================================================================
-- 09_reviews.sql
-- Отзывы о усопшем. Модерация админом. Защита от спама — уникальность автор+текст.
-- =============================================================================

CREATE TABLE memorial_reviews (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    memorial_id             UUID         NOT NULL REFERENCES memorials (id) ON DELETE CASCADE,
    author_user_id          UUID         REFERENCES users (id) ON DELETE SET NULL,
    author_name             VARCHAR(128) NOT NULL,
    author_email            CITEXT,
    body                    TEXT         NOT NULL,
    moderation_status_id    SMALLINT     NOT NULL REFERENCES review_moderation_statuses (id),
    moderated_by_user_id    UUID         REFERENCES users (id) ON DELETE SET NULL,
    moderated_at            TIMESTAMPTZ,
    moderation_note         VARCHAR(256),
    created_at              TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at              TIMESTAMPTZ  NOT NULL DEFAULT now(),
    deleted_at              TIMESTAMPTZ,
    CONSTRAINT chk_memorial_reviews_body_len CHECK (char_length(body) BETWEEN 3 AND 5000)
);

CREATE INDEX idx_memorial_reviews_memorial ON memorial_reviews (memorial_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_memorial_reviews_moderation ON memorial_reviews (moderation_status_id)
    WHERE deleted_at IS NULL;

-- Один отзыв от одного авторизованного пользователя на мемориал
CREATE UNIQUE INDEX uq_memorial_reviews_user_per_memorial
    ON memorial_reviews (memorial_id, author_user_id)
    WHERE author_user_id IS NOT NULL AND deleted_at IS NULL;


-- ########## 10_system.sql ##########

-- =============================================================================
-- 10_system.sql
-- Идемпотентность API, уведомления, аудит. Защита от повторной отправки email.
-- =============================================================================

-- Идемпотентность REST-запросов (создание заказа, платежа)
CREATE TABLE api_idempotency_keys (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    idempotency_key UUID         NOT NULL,
    endpoint        VARCHAR(128) NOT NULL,
    user_id         UUID         REFERENCES users (id) ON DELETE SET NULL,
    request_hash    VARCHAR(64)  NOT NULL,
    response_status SMALLINT,
    response_body   JSONB,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    expires_at      TIMESTAMPTZ  NOT NULL,
    CONSTRAINT uq_api_idempotency UNIQUE (idempotency_key, endpoint)
);

CREATE INDEX idx_api_idempotency_expires ON api_idempotency_keys (expires_at);

-- Лог отправленных уведомлений (не дублировать чек/QR на один email по одному заказу)
CREATE TABLE notification_log (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    notification_type_id SMALLINT    NOT NULL REFERENCES notification_types (id),
    order_id            UUID         REFERENCES orders (id) ON DELETE SET NULL,
    user_id             UUID         REFERENCES users (id) ON DELETE SET NULL,
    recipient_email     CITEXT       NOT NULL,
    subject             VARCHAR(256),
    external_message_id VARCHAR(128),
    sent_at             TIMESTAMPTZ  NOT NULL DEFAULT now(),
    failed_at           TIMESTAMPTZ,
    error_message       TEXT,
    CONSTRAINT uq_notification_per_order_type UNIQUE (order_id, notification_type_id)
);

CREATE INDEX idx_notification_log_email ON notification_log (recipient_email, sent_at DESC);

-- Аудит действий админа и критичных операций
CREATE TABLE audit_log (
    id              BIGSERIAL PRIMARY KEY,
    actor_user_id   UUID         REFERENCES users (id) ON DELETE SET NULL,
    action          VARCHAR(64)  NOT NULL,  -- qr.assign, review.approve, user.deactivate
    entity_type     VARCHAR(64)  NOT NULL,
    entity_id       UUID         NOT NULL,
    old_values      JSONB,
    new_values      JSONB,
    ip_address      INET,
    user_agent      VARCHAR(512),
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX idx_audit_log_entity ON audit_log (entity_type, entity_id, created_at DESC);
CREATE INDEX idx_audit_log_actor ON audit_log (actor_user_id, created_at DESC);


-- ########## 11_functions_triggers.sql ##########

-- =============================================================================
-- 11_functions_triggers.sql
-- Бизнес-правила на уровне БД: updated_at, лимиты медиа, один платёж, одно фото могилы.
-- =============================================================================

-- Универсальное обновление updated_at
CREATE OR REPLACE FUNCTION fn_set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

-- Список таблиц с updated_at
DO $$
DECLARE
    t TEXT;
BEGIN
    FOREACH t IN ARRAY ARRAY[
        'users', 'orders', 'order_deliveries', 'payments',
        'qr_codes', 'memorials', 'media_files', 'memorial_reviews'
    ]
    LOOP
        EXECUTE format(
            'CREATE TRIGGER trg_%s_updated_at
             BEFORE UPDATE ON %I
             FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at()',
            t, t
        );
    END LOOP;
END;
$$;

-- ---------------------------------------------------------------------------
-- Один успешный платёж на заказ
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_check_single_succeeded_payment()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_succeeded_id SMALLINT;
BEGIN
    SELECT id INTO v_succeeded_id FROM payment_statuses WHERE code = 'succeeded';

    IF NEW.status_id = v_succeeded_id THEN
        IF EXISTS (
            SELECT 1
            FROM payments p
            WHERE p.order_id = NEW.order_id
              AND p.status_id = v_succeeded_id
              AND p.id IS DISTINCT FROM NEW.id
        ) THEN
            RAISE EXCEPTION 'ORDER_ALREADY_PAID: order_id=%', NEW.order_id
                USING ERRCODE = 'unique_violation';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_payments_one_succeeded
    BEFORE INSERT OR UPDATE OF status_id ON payments
    FOR EACH ROW EXECUTE FUNCTION fn_check_single_succeeded_payment();

-- ---------------------------------------------------------------------------
-- Лимиты фото и видео при добавлении media_files
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_check_media_limits()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_photo_type_id  SMALLINT;
    v_video_type_id  SMALLINT;
    v_grave_type_id  SMALLINT;
    v_photo_count    INTEGER;
    v_video_seconds  INTEGER;
    v_max_photos     INTEGER;
    v_max_video_sec  INTEGER;
BEGIN
    IF NEW.deleted_at IS NOT NULL THEN
        RETURN NEW;
    END IF;

    SELECT id INTO v_photo_type_id FROM media_types WHERE code = 'photo';
    SELECT id INTO v_video_type_id FROM media_types WHERE code = 'video';
    SELECT id INTO v_grave_type_id FROM media_types WHERE code = 'grave_photo';

    SELECT m.max_photos, m.max_video_seconds
    INTO v_max_photos, v_max_video_sec
    FROM memorials m
    WHERE m.id = NEW.memorial_id AND m.deleted_at IS NULL;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'MEMORIAL_NOT_FOUND: id=%', NEW.memorial_id;
    END IF;

    -- Фото могилы не входит в лимит галереи, но только одно
    IF NEW.media_type_id = v_grave_type_id THEN
        IF EXISTS (
            SELECT 1 FROM media_files mf
            WHERE mf.memorial_id = NEW.memorial_id
              AND mf.media_type_id = v_grave_type_id
              AND mf.deleted_at IS NULL
              AND mf.id IS DISTINCT FROM NEW.id
        ) THEN
            RAISE EXCEPTION 'GRAVE_PHOTO_ALREADY_EXISTS: memorial_id=%', NEW.memorial_id
                USING ERRCODE = 'unique_violation';
        END IF;
        RETURN NEW;
    END IF;

    IF NEW.media_type_id = v_photo_type_id THEN
        SELECT count(*) INTO v_photo_count
        FROM media_files mf
        WHERE mf.memorial_id = NEW.memorial_id
          AND mf.media_type_id = v_photo_type_id
          AND mf.deleted_at IS NULL
          AND mf.id IS DISTINCT FROM NEW.id;

        IF v_photo_count >= v_max_photos THEN
            RAISE EXCEPTION 'PHOTO_LIMIT_EXCEEDED: limit=% current=%', v_max_photos, v_photo_count
                USING ERRCODE = 'check_violation';
        END IF;
    END IF;

    IF NEW.media_type_id = v_video_type_id THEN
        SELECT coalesce(sum(mf.duration_seconds), 0) INTO v_video_seconds
        FROM media_files mf
        WHERE mf.memorial_id = NEW.memorial_id
          AND mf.media_type_id = v_video_type_id
          AND mf.deleted_at IS NULL
          AND mf.id IS DISTINCT FROM NEW.id;

        IF v_video_seconds + coalesce(NEW.duration_seconds, 0) > v_max_video_sec THEN
            RAISE EXCEPTION 'VIDEO_LIMIT_EXCEEDED: limit_sec=% current=% adding=%',
                v_max_video_sec, v_video_seconds, coalesce(NEW.duration_seconds, 0)
                USING ERRCODE = 'check_violation';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_media_files_limits
    BEFORE INSERT OR UPDATE ON media_files
    FOR EACH ROW EXECUTE FUNCTION fn_check_media_limits();

-- ---------------------------------------------------------------------------
-- Согласованность суммы заказа с позицией
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_sync_order_total_from_line()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE orders o
    SET total_amount = NEW.line_total_rub,
        updated_at = now()
    WHERE o.id = NEW.order_id;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_order_lines_sync_total
    AFTER INSERT OR UPDATE OF line_total_rub ON order_lines
    FOR EACH ROW EXECUTE FUNCTION fn_sync_order_total_from_line();

-- ---------------------------------------------------------------------------
-- Привязка QR к мемориалу: обновить статус и лимиты мемориала из order_lines
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_on_qr_assign_memorial()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_active_status_id SMALLINT;
    v_line             order_lines%ROWTYPE;
BEGIN
    IF NEW.memorial_id IS NOT NULL AND (OLD.memorial_id IS DISTINCT FROM NEW.memorial_id) THEN
        SELECT id INTO v_active_status_id FROM qr_code_statuses WHERE code = 'active';

        SELECT ol.* INTO v_line
        FROM order_lines ol
        WHERE ol.id = NEW.order_line_id;

        UPDATE memorials m
        SET package_type_id = v_line.package_type_id,
            max_photos = v_line.snapshot_max_photos,
            max_video_seconds = v_line.snapshot_max_video_sec,
            updated_at = now()
        WHERE m.id = NEW.memorial_id;

        NEW.status_id := v_active_status_id;
        NEW.activated_at := coalesce(NEW.activated_at, now());
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_qr_codes_assign_memorial
    BEFORE UPDATE OF memorial_id ON qr_codes
    FOR EACH ROW EXECUTE FUNCTION fn_on_qr_assign_memorial();

-- ---------------------------------------------------------------------------
-- При регистрации: привязать гостевые заказы по email
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_link_guest_orders_to_user(p_user_id UUID, p_email CITEXT)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_linked INTEGER;
BEGIN
    UPDATE orders
    SET user_id = p_user_id,
        updated_at = now()
    WHERE buyer_email = p_email
      AND user_id IS NULL;

    GET DIAGNOSTICS v_linked = ROW_COUNT;
    RETURN v_linked;
END;
$$;


-- ########## 12_seed.sql ##########

-- =============================================================================
-- 12_seed.sql
-- Справочные данные и тестовый админ (пароль задать через API — здесь placeholder hash).
-- =============================================================================

-- Роли
INSERT INTO user_roles (code, name) VALUES
    ('buyer', 'Покупатель'),
    ('admin', 'Администратор')
ON CONFLICT (code) DO NOTHING;

-- Пакеты
INSERT INTO package_types (code, name, price_rub, max_photos, max_video_seconds, sort_order) VALUES
    ('standard', 'Стандарт', 2990.00, 40,  0,    1),
    ('premium',  'Премиум',  5990.00, 80,  1200, 2),   -- 20 мин
    ('maximum',  'Максимум', 11990.00, 200, 3600, 3)    -- 60 мин
ON CONFLICT (code) DO NOTHING;

-- Статусы заказа
INSERT INTO order_statuses (code, name, is_terminal) VALUES
    ('draft',           'Черновик',              FALSE),
    ('pending_payment', 'Ожидает оплаты',        FALSE),
    ('paid',            'Оплачен',               FALSE),
    ('fulfilled',       'Выполнен',              TRUE),
    ('cancelled',       'Отменён',               TRUE),
    ('refunded',        'Возврат',               TRUE)
ON CONFLICT (code) DO NOTHING;

-- Статусы платежа
INSERT INTO payment_statuses (code, name, is_terminal) VALUES
    ('pending',   'Создан',        FALSE),
    ('waiting',   'Ожидает оплаты', FALSE),
    ('succeeded', 'Успешно',       TRUE),
    ('cancelled', 'Отменён',       TRUE),
    ('failed',    'Ошибка',        TRUE)
ON CONFLICT (code) DO NOTHING;

-- Статусы QR
INSERT INTO qr_code_statuses (code, name) VALUES
    ('generated',  'Сгенерирован'),
    ('assigned',   'Привязан к мемориалу'),
    ('active',     'Активен'),
    ('suspended',  'Приостановлен'),
    ('revoked',    'Отозван')
ON CONFLICT (code) DO NOTHING;

-- Доставка
INSERT INTO fulfillment_statuses (code, name) VALUES
    ('pending',    'Ожидает отправки'),
    ('processing', 'В обработке'),
    ('shipped',    'Отправлен'),
    ('delivered',  'Доставлен'),
    ('failed',     'Не доставлен')
ON CONFLICT (code) DO NOTHING;

-- Медиа
INSERT INTO media_types (code, name) VALUES
    ('photo',       'Фото усопшего'),
    ('video',       'Видео усопшего'),
    ('grave_photo', 'Фото могилы')
ON CONFLICT (code) DO NOTHING;

INSERT INTO media_processing_statuses (code, name) VALUES
    ('pending',    'Ожидает обработки'),
    ('processing', 'Обрабатывается'),
    ('ready',      'Готово'),
    ('failed',     'Ошибка')
ON CONFLICT (code) DO NOTHING;

-- Модерация отзывов
INSERT INTO review_moderation_statuses (code, name) VALUES
    ('pending',  'На модерации'),
    ('approved', 'Одобрен'),
    ('rejected', 'Отклонён')
ON CONFLICT (code) DO NOTHING;

-- Типы уведомлений
INSERT INTO notification_types (code, name) VALUES
    ('payment_receipt',   'Чек об оплате'),
    ('qr_registry',       'Реестр QR-кодов'),
    ('delivery_info',     'Сроки доставки плашки'),
    ('sticker_guide',     'Инструкция по приклеиванию'),
    ('cabinet_guide',     'Инструкция входа в ЛК'),
    ('password_reset',    'Сброс пароля')
ON CONFLICT (code) DO NOTHING;

-- Тестовые пользователи (только dev/staging).
-- Пароль задаётся через API при первом запуске backend.
-- Ниже — placeholder hash; замените на реальный bcrypt от passlib.
--
-- Python: from passlib.hash import bcrypt; bcrypt.hash("1234")
--
-- INSERT вручную после генерации hash:
--
-- INSERT INTO users (role_id, email, phone, password_hash, full_name, email_verified)
-- SELECT r.id, 'admin@qr-pamyat.ru', '+79000000001', '<BCRYPT_HASH>', 'Администратор', TRUE
-- FROM user_roles r WHERE r.code = 'admin'
--   AND NOT EXISTS (SELECT 1 FROM users WHERE email = 'admin@qr-pamyat.ru' AND deleted_at IS NULL);
--
-- INSERT INTO users (role_id, email, phone, password_hash, full_name, email_verified)
-- SELECT r.id, 'test@qr-memory.ru', '+79001234567', '<BCRYPT_HASH>', 'Тестовый Покупатель', TRUE
-- FROM user_roles r WHERE r.code = 'buyer'
--   AND NOT EXISTS (SELECT 1 FROM users WHERE email = 'test@qr-memory.ru' AND deleted_at IS NULL);



-- ########## 13_grants.sql ##########

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

