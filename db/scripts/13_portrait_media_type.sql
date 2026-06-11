-- Главная фотография (портрет) — отдельный тип медиа
INSERT INTO media_types (code, name) VALUES
    ('portrait', 'Главная фотография')
ON CONFLICT (code) DO NOTHING;
