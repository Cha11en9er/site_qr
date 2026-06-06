-- =============================================================================
-- 12_seed.sql
-- Справочные данные и тестовый админ (пароль задать через API — здесь placeholder hash).
-- =============================================================================

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
    ('grave_photo', 'Фото могилы')
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

