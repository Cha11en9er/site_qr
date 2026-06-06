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
