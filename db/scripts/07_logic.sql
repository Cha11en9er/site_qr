-- =============================================================================
-- 07_logic.sql
-- Триггеры fn_* и процедуры sp_*
-- =============================================================================

SET search_path TO qr, public;

-- ---------------------------------------------------------------------------
-- Триггерные функции fn_*
-- Бизнес-правила: updated_at, лимиты медиа, один платёж, привязка QR.
-- ---------------------------------------------------------------------------


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

-- ---------------------------------------------------------------------------
-- Процедуры sp_* (DML из backend, параметризованные, SECURITY DEFINER)
-- ---------------------------------------------------------------------------


-- ---------------------------------------------------------------------------
-- AUTH
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION sp_user_email_exists(p_email CITEXT)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
    SELECT EXISTS (
        SELECT 1 FROM users
        WHERE email = p_email AND deleted_at IS NULL
    );
$$;

CREATE OR REPLACE FUNCTION sp_user_phone_exists(p_phone VARCHAR(20))
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
    SELECT EXISTS (
        SELECT 1 FROM users
        WHERE phone = p_phone AND deleted_at IS NULL
    );
$$;

CREATE OR REPLACE FUNCTION sp_register_user(
    p_id UUID,
    p_role_id SMALLINT,
    p_email CITEXT,
    p_phone VARCHAR(20),
    p_password_hash VARCHAR(255),
    p_full_name VARCHAR(256)
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_email CITEXT;
BEGIN
    IF p_email IS NULL AND p_phone IS NULL THEN
        RAISE EXCEPTION 'LOGIN_REQUIRED'
            USING ERRCODE = 'check_violation';
    END IF;

    IF p_email IS NOT NULL THEN
        v_email := lower(p_email::text)::citext;
        IF sp_user_email_exists(v_email) THEN
            RAISE EXCEPTION 'LOGIN_ALREADY_EXISTS'
                USING ERRCODE = 'unique_violation';
        END IF;
    END IF;

    IF p_phone IS NOT NULL AND sp_user_phone_exists(p_phone) THEN
        RAISE EXCEPTION 'LOGIN_ALREADY_EXISTS'
            USING ERRCODE = 'unique_violation';
    END IF;

    INSERT INTO users (
        id, role_id, email, phone, password_hash, full_name, email_verified
    ) VALUES (
        p_id, p_role_id, v_email, p_phone,
        p_password_hash, NULLIF(btrim(p_full_name), ''), FALSE
    );

    IF v_email IS NOT NULL THEN
        PERFORM fn_link_guest_orders_to_user(p_id, v_email);
    END IF;

    RETURN p_id;
END;
$$;

CREATE OR REPLACE FUNCTION sp_update_user_profile(
    p_user_id UUID,
    p_set_full_name BOOLEAN,
    p_full_name VARCHAR(256),
    p_set_email BOOLEAN,
    p_email CITEXT,
    p_set_phone BOOLEAN,
    p_phone VARCHAR(20)
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_email CITEXT;
    v_current users%ROWTYPE;
BEGIN
    SELECT * INTO v_current
    FROM users
    WHERE id = p_user_id AND deleted_at IS NULL;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'USER_NOT_FOUND'
            USING ERRCODE = 'no_data_found';
    END IF;

    v_email := CASE
        WHEN p_set_email AND p_email IS NOT NULL THEN lower(p_email::text)::citext
        WHEN p_set_email THEN NULL
        ELSE v_current.email
    END;

    IF p_set_phone AND p_phone IS NOT NULL AND sp_user_phone_exists(p_phone)
       AND v_current.phone IS DISTINCT FROM p_phone THEN
        RAISE EXCEPTION 'PHONE_ALREADY_EXISTS'
            USING ERRCODE = 'unique_violation';
    END IF;

    IF p_set_email AND v_email IS NOT NULL AND sp_user_email_exists(v_email)
       AND v_current.email IS DISTINCT FROM v_email THEN
        RAISE EXCEPTION 'EMAIL_ALREADY_EXISTS'
            USING ERRCODE = 'unique_violation';
    END IF;

    IF coalesce(v_email, CASE WHEN p_set_phone THEN p_phone ELSE v_current.phone END) IS NULL THEN
        RAISE EXCEPTION 'EMAIL_OR_PHONE_REQUIRED'
            USING ERRCODE = 'check_violation';
    END IF;

    UPDATE users u
    SET
        full_name = CASE
            WHEN p_set_full_name THEN NULLIF(btrim(p_full_name), '')
            ELSE u.full_name
        END,
        email = CASE WHEN p_set_email THEN v_email ELSE u.email END,
        phone = CASE WHEN p_set_phone THEN p_phone ELSE u.phone END,
        updated_at = now()
    WHERE u.id = p_user_id;

    RETURN TRUE;
END;
$$;

CREATE OR REPLACE FUNCTION sp_update_last_login(p_user_id UUID)
RETURNS VOID
LANGUAGE sql
SECURITY DEFINER
AS $$
    UPDATE users
    SET last_login_at = now(), updated_at = now()
    WHERE id = p_user_id AND deleted_at IS NULL;
$$;

CREATE OR REPLACE FUNCTION sp_insert_refresh_token(
    p_id UUID,
    p_user_id UUID,
    p_token_hash VARCHAR(128),
    p_expires_at TIMESTAMPTZ,
    p_user_agent VARCHAR(512),
    p_ip_address INET
)
RETURNS UUID
LANGUAGE sql
SECURITY DEFINER
AS $$
    INSERT INTO refresh_tokens (
        id, user_id, token_hash, expires_at, user_agent, ip_address
    ) VALUES (
        p_id, p_user_id, p_token_hash, p_expires_at, p_user_agent, p_ip_address
    )
    RETURNING id;
$$;

CREATE OR REPLACE FUNCTION sp_revoke_refresh_token_by_hash(p_token_hash VARCHAR(128))
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE refresh_tokens
    SET revoked_at = now()
    WHERE token_hash = p_token_hash AND revoked_at IS NULL;

    RETURN FOUND;
END;
$$;

-- ---------------------------------------------------------------------------
-- ORDERS / PAYMENTS
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION sp_create_checkout_order(
    p_order_id UUID,
    p_user_id UUID,
    p_status_id SMALLINT,
    p_buyer_email CITEXT,
    p_buyer_phone VARCHAR(20),
    p_buyer_name VARCHAR(256),
    p_total_amount NUMERIC(12,2),
    p_package_type_id SMALLINT,
    p_quantity INTEGER,
    p_unit_price_rub NUMERIC(12,2),
    p_line_total_rub NUMERIC(12,2),
    p_snapshot_max_photos INTEGER,
    p_snapshot_max_video_sec INTEGER,
    p_snapshot_package_name VARCHAR(128),
    p_fulfillment_status_id SMALLINT,
    p_delivery_address TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO orders (
        id, user_id, status_id, buyer_email, buyer_phone, buyer_name, total_amount
    ) VALUES (
        p_order_id, p_user_id, p_status_id, lower(p_buyer_email::text)::citext,
        p_buyer_phone, p_buyer_name, p_total_amount
    );

    INSERT INTO order_lines (
        order_id, package_type_id, quantity, unit_price_rub, line_total_rub,
        snapshot_max_photos, snapshot_max_video_sec, snapshot_package_name
    ) VALUES (
        p_order_id, p_package_type_id, p_quantity, p_unit_price_rub, p_line_total_rub,
        p_snapshot_max_photos, p_snapshot_max_video_sec, p_snapshot_package_name
    );

    INSERT INTO order_deliveries (
        order_id, fulfillment_status_id, delivery_address
    ) VALUES (
        p_order_id, p_fulfillment_status_id, p_delivery_address
    );

    RETURN p_order_id;
END;
$$;

CREATE OR REPLACE FUNCTION sp_record_payment(
    p_id UUID,
    p_order_id UUID,
    p_status_id SMALLINT,
    p_provider_payment_id VARCHAR(64),
    p_idempotence_key UUID,
    p_amount_rub NUMERIC(12,2),
    p_confirmation_url TEXT
)
RETURNS UUID
LANGUAGE sql
SECURITY DEFINER
AS $$
    INSERT INTO payments (
        id, order_id, status_id, provider_payment_id, idempotence_key,
        amount_rub, confirmation_url
    ) VALUES (
        p_id, p_order_id, p_status_id, p_provider_payment_id, p_idempotence_key,
        p_amount_rub, p_confirmation_url
    )
    RETURNING id;
$$;

CREATE OR REPLACE FUNCTION sp_get_order_status(p_order_id UUID)
RETURNS TABLE (
    order_id UUID,
    status_code VARCHAR(32),
    total_amount NUMERIC(12,2),
    paid_at TIMESTAMPTZ
)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
    SELECT o.id, os.code, o.total_amount, o.paid_at
    FROM orders o
    JOIN order_statuses os ON os.id = o.status_id
    WHERE o.id = p_order_id;
$$;

CREATE OR REPLACE FUNCTION sp_webhook_event_exists(
    p_provider VARCHAR(32),
    p_provider_event_id VARCHAR(128)
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
    SELECT EXISTS (
        SELECT 1 FROM payment_webhook_events
        WHERE provider = p_provider AND provider_event_id = p_provider_event_id
    );
$$;

CREATE OR REPLACE FUNCTION sp_insert_webhook_event(
    p_provider VARCHAR(32),
    p_provider_event_id VARCHAR(128),
    p_event_type VARCHAR(64),
    p_provider_payment_id VARCHAR(64),
    p_payload JSONB
)
RETURNS UUID
LANGUAGE sql
SECURITY DEFINER
AS $$
    INSERT INTO payment_webhook_events (
        provider, provider_event_id, event_type, provider_payment_id, payload
    ) VALUES (
        p_provider, p_provider_event_id, p_event_type, p_provider_payment_id, p_payload
    )
    RETURNING id;
$$;

CREATE OR REPLACE FUNCTION sp_mark_webhook_processed(
    p_provider VARCHAR(32),
    p_provider_event_id VARCHAR(128)
)
RETURNS VOID
LANGUAGE sql
SECURITY DEFINER
AS $$
    UPDATE payment_webhook_events
    SET processed_at = now()
    WHERE provider = p_provider AND provider_event_id = p_provider_event_id;
$$;

CREATE OR REPLACE FUNCTION sp_apply_payment_succeeded(
    p_provider_payment_id VARCHAR(64)
)
RETURNS TABLE (payment_id UUID, order_id UUID)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_payment_id UUID;
    v_order_id UUID;
    v_succeeded_status_id SMALLINT;
    v_paid_order_status_id SMALLINT;
BEGIN
    SELECT id INTO v_succeeded_status_id FROM payment_statuses WHERE code = 'succeeded';
    SELECT id INTO v_paid_order_status_id FROM order_statuses WHERE code = 'paid';

    SELECT p.id, p.order_id
    INTO v_payment_id, v_order_id
    FROM payments p
    WHERE p.provider = 'yookassa' AND p.provider_payment_id = p_provider_payment_id;

    IF v_payment_id IS NULL THEN
        RETURN;
    END IF;

    UPDATE payments
    SET status_id = v_succeeded_status_id, paid_at = now(), updated_at = now()
    WHERE id = v_payment_id;

    UPDATE orders
    SET status_id = v_paid_order_status_id, paid_at = now(), updated_at = now()
    WHERE id = v_order_id;

    payment_id := v_payment_id;
    order_id := v_order_id;
    RETURN NEXT;
END;
$$;

-- ---------------------------------------------------------------------------
-- MEMORIALS
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION sp_memorial_owner_id(p_memorial_id UUID)
RETURNS UUID
LANGUAGE sql
STABLE
AS $$
    SELECT owner_user_id
    FROM memorials
    WHERE id = p_memorial_id AND deleted_at IS NULL;
$$;

CREATE OR REPLACE FUNCTION sp_create_memorial(
    p_id UUID,
    p_owner_user_id UUID,
    p_public_slug VARCHAR(64),
    p_deceased_full_name VARCHAR(256),
    p_birth_date DATE,
    p_death_date DATE,
    p_father_full_name VARCHAR(256),
    p_mother_full_name VARCHAR(256),
    p_epitaph VARCHAR(500),
    p_package_type_id SMALLINT,
    p_max_photos INTEGER,
    p_max_video_seconds INTEGER
)
RETURNS UUID
LANGUAGE sql
SECURITY DEFINER
AS $$
    INSERT INTO memorials (
        id, owner_user_id, public_slug, deceased_full_name,
        birth_date, death_date, father_full_name, mother_full_name, epitaph,
        package_type_id, max_photos, max_video_seconds, is_published
    ) VALUES (
        p_id, p_owner_user_id, p_public_slug, p_deceased_full_name,
        p_birth_date, p_death_date, p_father_full_name, p_mother_full_name, p_epitaph,
        p_package_type_id, p_max_photos, p_max_video_seconds, FALSE
    )
    RETURNING id;
$$;

CREATE OR REPLACE FUNCTION sp_update_memorial(
    p_id UUID,
    p_actor_user_id UUID,
    p_is_admin BOOLEAN,
    p_set_full_name BOOLEAN,
    p_full_name VARCHAR(256),
    p_set_birth_date BOOLEAN,
    p_birth_date DATE,
    p_set_death_date BOOLEAN,
    p_death_date DATE,
    p_set_father_name BOOLEAN,
    p_father_name VARCHAR(256),
    p_set_mother_name BOOLEAN,
    p_mother_name VARCHAR(256),
    p_set_epitaph BOOLEAN,
    p_epitaph VARCHAR(500),
    p_set_grave_address BOOLEAN,
    p_grave_address VARCHAR(256),
    p_set_grave_lat BOOLEAN,
    p_grave_lat NUMERIC(10, 7),
    p_set_grave_lng BOOLEAN,
    p_grave_lng NUMERIC(10, 7),
    p_set_is_published BOOLEAN,
    p_is_published BOOLEAN
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_owner UUID;
BEGIN
    SELECT owner_user_id INTO v_owner
    FROM memorials
    WHERE id = p_id AND deleted_at IS NULL;

    IF v_owner IS NULL THEN
        RAISE EXCEPTION 'MEMORIAL_NOT_FOUND'
            USING ERRCODE = 'no_data_found';
    END IF;

    IF v_owner IS DISTINCT FROM p_actor_user_id AND NOT p_is_admin THEN
        RAISE EXCEPTION 'FORBIDDEN'
            USING ERRCODE = 'insufficient_privilege';
    END IF;

    UPDATE memorials m
    SET
        deceased_full_name = CASE WHEN p_set_full_name THEN p_full_name ELSE m.deceased_full_name END,
        birth_date = CASE WHEN p_set_birth_date THEN p_birth_date ELSE m.birth_date END,
        death_date = CASE WHEN p_set_death_date THEN p_death_date ELSE m.death_date END,
        father_full_name = CASE WHEN p_set_father_name THEN p_father_name ELSE m.father_full_name END,
        mother_full_name = CASE WHEN p_set_mother_name THEN p_mother_name ELSE m.mother_full_name END,
        epitaph = CASE WHEN p_set_epitaph THEN p_epitaph ELSE m.epitaph END,
        grave_location_label = CASE WHEN p_set_grave_address THEN p_grave_address ELSE m.grave_location_label END,
        grave_latitude = CASE WHEN p_set_grave_lat THEN p_grave_lat ELSE m.grave_latitude END,
        grave_longitude = CASE WHEN p_set_grave_lng THEN p_grave_lng ELSE m.grave_longitude END,
        is_published = CASE WHEN p_set_is_published THEN p_is_published ELSE m.is_published END,
        published_at = CASE
            WHEN p_set_is_published AND p_is_published THEN coalesce(m.published_at, now())
            ELSE m.published_at
        END,
        updated_at = now()
    WHERE m.id = p_id;

    RETURN TRUE;
END;
$$;

CREATE OR REPLACE FUNCTION sp_get_memorial(p_id UUID)
RETURNS TABLE (
    id UUID,
    public_slug VARCHAR(64),
    full_name VARCHAR(256),
    birth_date DATE,
    death_date DATE,
    father_name VARCHAR(256),
    mother_name VARCHAR(256),
    epitaph VARCHAR(500),
    grave_address VARCHAR(256),
    grave_lat NUMERIC(10, 7),
    grave_lng NUMERIC(10, 7),
    max_photos INTEGER,
    max_video_seconds INTEGER,
    is_published BOOLEAN,
    package_code VARCHAR(32),
    owner_user_id UUID
)
LANGUAGE sql
STABLE
AS $$
    SELECT
        m.id,
        m.public_slug,
        m.deceased_full_name,
        m.birth_date,
        m.death_date,
        m.father_full_name,
        m.mother_full_name,
        m.epitaph,
        m.grave_location_label,
        m.grave_latitude,
        m.grave_longitude,
        m.max_photos,
        m.max_video_seconds,
        m.is_published,
        pt.code,
        m.owner_user_id
    FROM memorials m
    JOIN package_types pt ON pt.id = m.package_type_id
    WHERE m.id = p_id AND m.deleted_at IS NULL;
$$;

CREATE OR REPLACE FUNCTION sp_list_memorial_ids_by_owner(p_user_id UUID)
RETURNS TABLE (id UUID)
LANGUAGE sql
STABLE
AS $$
    SELECT m.id
    FROM memorials m
    WHERE m.owner_user_id = p_user_id AND m.deleted_at IS NULL
    ORDER BY m.created_at DESC;
$$;

CREATE OR REPLACE FUNCTION sp_get_memorial_media(p_memorial_id UUID)
RETURNS TABLE (
    id UUID,
    storage_key VARCHAR(512),
    mime_type VARCHAR(128),
    size_bytes BIGINT,
    original_filename VARCHAR(256),
    duration_seconds INTEGER,
    sort_order INTEGER,
    media_type VARCHAR(32)
)
LANGUAGE sql
STABLE
AS $$
    SELECT
        mf.id,
        mf.storage_key,
        mf.mime_type,
        mf.size_bytes,
        mf.original_filename,
        mf.duration_seconds,
        mf.sort_order,
        mt.code
    FROM media_files mf
    JOIN media_types mt ON mt.id = mf.media_type_id
    WHERE mf.memorial_id = p_memorial_id AND mf.deleted_at IS NULL
    ORDER BY mf.sort_order, mf.created_at;
$$;

CREATE OR REPLACE FUNCTION sp_lookup_media_type_id(p_code VARCHAR(32))
RETURNS SMALLINT
LANGUAGE sql
STABLE
AS $$
    SELECT id FROM media_types WHERE code = p_code;
$$;

CREATE OR REPLACE FUNCTION sp_lookup_processing_status_id(p_code VARCHAR(32))
RETURNS SMALLINT
LANGUAGE sql
STABLE
AS $$
    SELECT id FROM media_processing_statuses WHERE code = p_code;
$$;

CREATE OR REPLACE FUNCTION sp_list_portrait_media(p_memorial_id UUID)
RETURNS TABLE (id UUID, storage_key VARCHAR(512))
LANGUAGE sql
STABLE
AS $$
    SELECT mf.id, mf.storage_key
    FROM media_files mf
    JOIN media_types mt ON mt.id = mf.media_type_id
    WHERE mf.memorial_id = p_memorial_id
      AND mt.code = 'portrait'
      AND mf.deleted_at IS NULL;
$$;

CREATE OR REPLACE FUNCTION sp_count_memorial_photos(p_memorial_id UUID)
RETURNS INTEGER
LANGUAGE sql
STABLE
AS $$
    SELECT count(*)::INTEGER
    FROM media_files mf
    JOIN media_types mt ON mt.id = mf.media_type_id
    WHERE mf.memorial_id = p_memorial_id
      AND mt.code = 'photo'
      AND mf.deleted_at IS NULL;
$$;

CREATE OR REPLACE FUNCTION sp_get_memorial_max_photos(p_memorial_id UUID)
RETURNS INTEGER
LANGUAGE sql
STABLE
AS $$
    SELECT max_photos FROM memorials WHERE id = p_memorial_id AND deleted_at IS NULL;
$$;

CREATE OR REPLACE FUNCTION sp_soft_delete_media(p_media_id UUID)
RETURNS VARCHAR(512)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_key VARCHAR(512);
BEGIN
    UPDATE media_files
    SET deleted_at = now(), updated_at = now()
    WHERE id = p_media_id AND deleted_at IS NULL
    RETURNING storage_key INTO v_key;

    RETURN v_key;
END;
$$;

CREATE OR REPLACE FUNCTION sp_get_media_for_delete(p_media_id UUID)
RETURNS TABLE (storage_key VARCHAR(512), owner_user_id UUID)
LANGUAGE sql
STABLE
AS $$
    SELECT mf.storage_key, m.owner_user_id
    FROM media_files mf
    JOIN memorials m ON m.id = mf.memorial_id
    WHERE mf.id = p_media_id AND mf.deleted_at IS NULL;
$$;

CREATE OR REPLACE FUNCTION sp_insert_media_file(
    p_id UUID,
    p_memorial_id UUID,
    p_media_type_id SMALLINT,
    p_processing_status_id SMALLINT,
    p_uploaded_by_user_id UUID,
    p_storage_bucket VARCHAR(128),
    p_storage_key VARCHAR(512),
    p_original_filename VARCHAR(256),
    p_mime_type VARCHAR(128),
    p_size_bytes BIGINT,
    p_duration_seconds INTEGER,
    p_sort_order INTEGER
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_photo_type_id SMALLINT;
    v_photo_count INTEGER;
    v_max_photos INTEGER;
BEGIN
    SELECT id INTO v_photo_type_id FROM media_types WHERE code = 'photo';

    IF p_media_type_id = v_photo_type_id THEN
        v_photo_count := sp_count_memorial_photos(p_memorial_id);
        v_max_photos := sp_get_memorial_max_photos(p_memorial_id);

        IF v_photo_count >= v_max_photos THEN
            RAISE EXCEPTION 'PHOTO_LIMIT_REACHED'
                USING ERRCODE = 'check_violation';
        END IF;
    END IF;

    INSERT INTO media_files (
        id, memorial_id, media_type_id, processing_status_id,
        uploaded_by_user_id, storage_bucket, storage_key,
        original_filename, mime_type, size_bytes, duration_seconds, sort_order
    ) VALUES (
        p_id, p_memorial_id, p_media_type_id, p_processing_status_id,
        p_uploaded_by_user_id, p_storage_bucket, p_storage_key,
        p_original_filename, p_mime_type, p_size_bytes, p_duration_seconds, p_sort_order
    );

    RETURN p_id;
END;
$$;
