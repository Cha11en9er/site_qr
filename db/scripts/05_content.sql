-- =============================================================================
-- 05_content.sql
-- Мемориалы, медиа, отзывы
-- =============================================================================

SET search_path TO qr, public;

-- ---------------------------------------------------------------------------
-- Мемориальные страницы. Лимиты пакета — снимок из order_lines при активации QR.
-- ---------------------------------------------------------------------------


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

-- ---------------------------------------------------------------------------
-- Медиафайлы в Object Storage. Уникальный storage_key, контроль лимитов — триггер.
-- ---------------------------------------------------------------------------


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

-- Не более одного фото могилы — триггер trg_media_one_grave_photo в 07_logic.sql

-- ---------------------------------------------------------------------------
-- Отзывы о усопшем. Модерация админом. Защита от спама — уникальность автор+текст.
-- ---------------------------------------------------------------------------


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
