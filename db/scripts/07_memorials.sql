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
