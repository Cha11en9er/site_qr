-- =============================================================================
-- 04_commerce.sql
-- Заказы, платежи, QR-коды
-- =============================================================================

SET search_path TO qr, public;

-- ---------------------------------------------------------------------------
-- Заказы, позиции (снимок цены), доставка. Гостевой checkout: user_id nullable.
-- ---------------------------------------------------------------------------


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

-- ---------------------------------------------------------------------------
-- Платежи ЮKassa, webhook-события (идемпотентность), защита от двойной оплаты.
-- ---------------------------------------------------------------------------


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

-- Один успешный платёж на заказ — триггер trg_payments_one_succeeded в 07_logic.sql

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

-- ---------------------------------------------------------------------------
-- QR-коды: короткий slug для /r/{slug}, привязка к заказу и мемориалу.
-- ---------------------------------------------------------------------------


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
