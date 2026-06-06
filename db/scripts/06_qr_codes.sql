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
