-- =============================================================================
-- 08_seed.sql
-- Справочные данные и тестовый админ (пароль задать через API — здесь placeholder hash).
-- =============================================================================

SET search_path TO qr, public;

-- Роли
INSERT INTO user_roles (code, name) VALUES
    ('buyer', 'Покупатель'),
    ('admin', 'Администратор')
ON CONFLICT (code) DO NOTHING;

-- Пакеты
INSERT INTO package_types (code, name, price_rub, max_photos, max_video_seconds, sort_order) VALUES
    ('standard', 'Стандарт', 2990.00, 40,  0,    1),
    ('premium',  'Премиум',  5990.00, 80,  1200, 2),   -- 20 мин
    ('maximum',  'Максимум', 11990.00, 200, 3600, 3)    -- 60 мин
ON CONFLICT (code) DO NOTHING;

-- Статусы заказа
INSERT INTO order_statuses (code, name, is_terminal) VALUES
    ('draft',           'Черновик',              FALSE),
    ('pending_payment', 'Ожидает оплаты',        FALSE),
    ('paid',            'Оплачен',               FALSE),
    ('fulfilled',       'Выполнен',              TRUE),
    ('cancelled',       'Отменён',               TRUE),
    ('refunded',        'Возврат',               TRUE)
ON CONFLICT (code) DO NOTHING;

-- Статусы платежа
INSERT INTO payment_statuses (code, name, is_terminal) VALUES
    ('pending',   'Создан',        FALSE),
    ('waiting',   'Ожидает оплаты', FALSE),
    ('succeeded', 'Успешно',       TRUE),
    ('cancelled', 'Отменён',       TRUE),
    ('failed',    'Ошибка',        TRUE)
ON CONFLICT (code) DO NOTHING;

-- Статусы QR
INSERT INTO qr_code_statuses (code, name) VALUES
    ('generated',  'Сгенерирован'),
    ('assigned',   'Привязан к мемориалу'),
    ('active',     'Активен'),
    ('suspended',  'Приостановлен'),
    ('revoked',    'Отозван')
ON CONFLICT (code) DO NOTHING;

-- Доставка
INSERT INTO fulfillment_statuses (code, name) VALUES
    ('pending',    'Ожидает отправки'),
    ('processing', 'В обработке'),
    ('shipped',    'Отправлен'),
    ('delivered',  'Доставлен'),
    ('failed',     'Не доставлен')
ON CONFLICT (code) DO NOTHING;

-- Медиа
INSERT INTO media_types (code, name) VALUES
    ('photo',       'Фото усопшего'),
    ('video',       'Видео усопшего'),
    ('grave_photo', 'Фото могилы'),
    ('portrait',    'Главная фотография')
ON CONFLICT (code) DO NOTHING;

INSERT INTO media_processing_statuses (code, name) VALUES
    ('pending',    'Ожидает обработки'),
    ('processing', 'Обрабатывается'),
    ('ready',      'Готово'),
    ('failed',     'Ошибка')
ON CONFLICT (code) DO NOTHING;

-- Модерация отзывов
INSERT INTO review_moderation_statuses (code, name) VALUES
    ('pending',  'На модерации'),
    ('approved', 'Одобрен'),
    ('rejected', 'Отклонён')
ON CONFLICT (code) DO NOTHING;

-- Типы уведомлений
INSERT INTO notification_types (code, name) VALUES
    ('payment_receipt',   'Чек об оплате'),
    ('qr_registry',       'Реестр QR-кодов'),
    ('delivery_info',     'Сроки доставки плашки'),
    ('sticker_guide',     'Инструкция по приклеиванию'),
    ('cabinet_guide',     'Инструкция входа в ЛК'),
    ('password_reset',    'Сброс пароля')
ON CONFLICT (code) DO NOTHING;

-- Тестовые пользователи (только dev/staging).
-- Пароль задаётся через API при первом запуске backend.
-- Ниже — placeholder hash; замените на реальный bcrypt от passlib.
--
-- Python: from passlib.hash import bcrypt; bcrypt.hash("1234")
--
-- INSERT вручную после генерации hash:
--
-- INSERT INTO users (role_id, email, phone, password_hash, full_name, email_verified)
-- SELECT r.id, 'admin@qr-pamyat.ru', '+79000000001', '<BCRYPT_HASH>', 'Администратор', TRUE
-- FROM user_roles r WHERE r.code = 'admin'
--   AND NOT EXISTS (SELECT 1 FROM users WHERE email = 'admin@qr-pamyat.ru' AND deleted_at IS NULL);
--
-- INSERT INTO users (role_id, email, phone, password_hash, full_name, email_verified)
-- SELECT r.id, 'test@qr-memory.ru', '+79001234567', '<BCRYPT_HASH>', 'Тестовый Покупатель', TRUE
-- FROM user_roles r WHERE r.code = 'buyer'
--   AND NOT EXISTS (SELECT 1 FROM users WHERE email = 'test@qr-memory.ru' AND deleted_at IS NULL);

-- ---------------------------------------------------------------------------
-- Примеры страниц памяти (Пушкин, Куприн, Менделеев) — опубликованы для лендинга.
-- Медиа: uploads/examples/{slug}/portrait.jpg (в git, на проде копируется вместе с проектом).
-- ---------------------------------------------------------------------------

INSERT INTO users (id, role_id, email, password_hash, full_name, email_verified, is_active)
SELECT
    'f0000000-0000-4000-8000-000000000001'::uuid,
    r.id,
    'demo@qr-pamyat.ru',
    '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5GyYzpLa/.0m',
    'Демо-аккаунт',
    TRUE,
    TRUE
FROM user_roles r
WHERE r.code = 'admin'
  AND NOT EXISTS (
      SELECT 1 FROM users u
      WHERE u.id = 'f0000000-0000-4000-8000-000000000001'::uuid
  );

INSERT INTO memorials (
    id, owner_user_id, public_slug, deceased_full_name,
    birth_date, death_date, father_full_name, mother_full_name, epitaph,
    package_type_id, max_photos, max_video_seconds,
    grave_latitude, grave_longitude, grave_location_label,
    is_published, published_at
)
SELECT
    v.id, 'f0000000-0000-4000-8000-000000000001'::uuid, v.slug, v.full_name,
    v.birth_date::date, v.death_date::date, v.father_name, v.mother_name, v.epitaph,
    p.id, p.max_photos, p.max_video_seconds,
    v.grave_lat, v.grave_lng, v.grave_label,
    TRUE, now()
FROM (VALUES
    (
        'f0000001-0000-4000-8000-000000000001'::uuid, 'pushkin', 'Пушкин Александр Сергеевич',
        '1799-06-06', '1837-01-29',
        'Сергей Львович Пушкин', 'Надежда Осиповна Пушкина',
        'И память сердца говорит Мне больше, чем дня печать…',
        57.0221, 28.9208, 'Святогорский монастырь, Пушкинские Горы, Псковская область'
    ),
    (
        'f0000002-0000-4000-8000-000000000002'::uuid, 'kuprin', 'Куприн Александр Иванович',
        '1870-09-07', '1938-08-25',
        'Иван Иванович Куприн', 'Любовь Алексеевна Куприна',
        'Писатель должен жить в своих книгах.',
        59.9042, 30.3894, 'Волково православное кладбище, Санкт-Петербург'
    ),
    (
        'f0000003-0000-4000-8000-000000000003'::uuid, 'mendeleev', 'Менделеев Дмитрий Иванович',
        '1834-02-08', '1907-02-02',
        'Иван Павлович Менделеев', 'Мария Дмитриевна Менделеева',
        'Наука и жизнь — неразделимы.',
        59.9060, 30.3900, 'Волково кладбище, Санкт-Петербург'
    )
) AS v(id, slug, full_name, birth_date, death_date, father_name, mother_name, epitaph, grave_lat, grave_lng, grave_label)
CROSS JOIN package_types p
WHERE p.code = 'premium'
  AND NOT EXISTS (SELECT 1 FROM memorials m WHERE m.id = v.id);

INSERT INTO media_files (
    id, memorial_id, media_type_id, processing_status_id,
    uploaded_by_user_id, storage_bucket, storage_key,
    original_filename, mime_type, size_bytes, sort_order
)
SELECT
    v.media_id, v.memorial_id, mt.id, ms.id,
    'f0000000-0000-4000-8000-000000000001'::uuid,
    'local', v.storage_key, v.filename, 'image/jpeg', v.size_bytes, 0
FROM (VALUES
    ('f1000001-0000-4000-8000-000000000001'::uuid, 'f0000001-0000-4000-8000-000000000001'::uuid,
     'examples/pushkin/portrait.jpg', 'portrait.jpg', 2301806),
    ('f1000002-0000-4000-8000-000000000002'::uuid, 'f0000002-0000-4000-8000-000000000002'::uuid,
     'examples/kuprin/portrait.jpg', 'portrait.jpg', 2295162),
    ('f1000003-0000-4000-8000-000000000003'::uuid, 'f0000003-0000-4000-8000-000000000003'::uuid,
     'examples/mendeleev/portrait.jpg', 'portrait.jpg', 151897)
) AS v(media_id, memorial_id, storage_key, filename, size_bytes)
JOIN media_types mt ON mt.code = 'portrait'
JOIN media_processing_statuses ms ON ms.code = 'ready'
WHERE NOT EXISTS (SELECT 1 FROM media_files mf WHERE mf.id = v.media_id);

