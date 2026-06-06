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
