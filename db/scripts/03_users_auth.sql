-- =============================================================================
-- 03_users_auth.sql
-- Пользователи, сессии, сброс пароля. Без дублирования email (citext + partial unique).
-- =============================================================================

SET search_path TO qr, public;

CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    role_id         SMALLINT     NOT NULL REFERENCES user_roles (id),
    email           CITEXT,
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
    ),
    CONSTRAINT chk_users_email_or_phone CHECK (
        email IS NOT NULL OR phone IS NOT NULL
    )
);

-- Один email = один активный аккаунт (мягкое удаление не блокирует повторную регистрацию)
CREATE UNIQUE INDEX uq_users_email_active
    ON users (email)
    WHERE deleted_at IS NULL AND email IS NOT NULL;

CREATE UNIQUE INDEX uq_users_phone_active
    ON users (phone)
    WHERE deleted_at IS NULL AND phone IS NOT NULL;

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
