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
