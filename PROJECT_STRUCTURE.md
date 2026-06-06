# Структура проекта (деплой на хостинг)

```
qr-pamyat/
│
├── frontend/                    # React SPA → nginx / CDN
│   ├── public/                  # Статика (favicon, hero-изображения)
│   ├── src/
│   │   ├── components/          # UI-компоненты (Modal, UploadZone…)
│   │   ├── pages/               # Landing, Cabinet, Admin, Memorial
│   │   ├── store/               # Zustand
│   │   ├── lib/                 # utils, api client, validation
│   │   ├── hooks/
│   │   └── types/
│   ├── Dockerfile               # Сборка → nginx
│   └── package.json             # (добавится при инициализации Vite)
│
├── backend/                     # FastAPI API
│   ├── app/
│   │   ├── api/routes/          # auth, orders, memorials, uploads, admin
│   │   ├── core/                # config, security, database
│   │   ├── models/              # SQLAlchemy models (зеркало db/scripts)
│   │   ├── schemas/             # Pydantic request/response
│   │   ├── services/            # yookassa, s3, qr, email
│   │   ├── workers/             # celery: thumbs, notifications
│   │   └── main.py
│   ├── alembic/versions/        # Миграции после baseline
│   ├── requirements.txt
│   └── Dockerfile
│
├── db/
│   ├── dbeaver/GUIDE.md         # ← инструкция DBeaver (основной способ)
│   ├── scripts/
│   │   ├── 00_database.sql      # роль qr_app (шаг 1)
│   │   ├── 00_full_schema.sql   # ← вся схема для DBeaver Alt+X
│   │   ├── 01 … 13              # пошагово (опционально)
│   │   ├── 99_drop_all.sql
│   │   └── build_full_schema.ps1
│   ├── migrations/              # Alembic (позже)
│   └── README.md
│
├── deploy/
│   ├── nginx/qr-pamyat.conf      # Reverse proxy + SPA + /api + /r/
│   └── docker-compose.prod.yml   # API + Redis на VPS
│
├── docs/                        # ТЗ, роадмап, гайды
├── docker-compose.yml           # Локально: postgres, redis, minio
├── .env.example
├── .gitignore
└── README.md
```

## Что куда на хостинге

| Компонент | Где живёт |
|-----------|-----------|
| Frontend (HTML/JS/CSS) | nginx `root` или Yandex Object Storage + CDN |
| API FastAPI | Docker на VPS, порт 8000 за nginx |
| PostgreSQL | Managed PG (Yandex / Selectel) или VPS |
| Redis | Docker на VPS |
| Медиафайлы | Yandex Object Storage + CDN |
| SSL | Let's Encrypt (certbot) |

## Порты (прод)

- `443` — nginx (публичный)
- `8000` — API (только localhost)
- `5432` — PostgreSQL (только private network)
