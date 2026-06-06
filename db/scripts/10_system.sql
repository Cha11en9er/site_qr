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
