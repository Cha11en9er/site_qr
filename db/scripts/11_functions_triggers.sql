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
