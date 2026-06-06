# QR Память — QR-коды на памятники

Мемориальный сервис: покупка QR-плашки, личный кабинет, страница памяти усопшего.

## Структура проекта

Подробно: [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md)

```
├── frontend/          # React + Vite (статика на хостинг / CDN)
├── backend/           # FastAPI API
├── db/                # SQL-скрипты PostgreSQL + документация
├── deploy/            # nginx, docker-compose для продакшена
├── docs/              # ТЗ, роадмап, гайды
└── docker-compose.yml # Локальная разработка
```

## База данных (сейчас — через DBeaver)

1. Создайте БД `qr_pamyat` в DBeaver (GUI)
2. Выполните `db/scripts/00_database.sql` (роль)
3. Выполните `db/scripts/00_full_schema.sql` (таблицы) — **Alt+X**

Подробно: [db/dbeaver/GUIDE.md](db/dbeaver/GUIDE.md)

psql понадобится только при деплое на VPS (опционально: `deploy/apply_schema.ps1`).

## Документация

- **[Локальный запуск (git pull → venv → npm → БД)](docs/LOCAL_SETUP.md)** ← начни отсюда
- [Роадмап](docs/ROADMAP.md)
- [Гайд по разработке](docs/DEVELOPMENT_GUIDE.md)
- [ТЗ Frontend UI](docs/TZ_FRONTEND_UI.md)
- [Схема БД](db/README.md)
