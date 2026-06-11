# Доступ к базе данных из backend

Как приложение читает и пишет данные, и как это защищено от SQL-инъекций.

**Схема PostgreSQL:** все таблицы и функции приложения — в **`qr`**, не в `public`.  
В `public` остаются только расширения (`pgcrypto`, `citext`).

---

## Краткий ответ

| Слой | Механизм | Инъекции |
|------|----------|----------|
| **Схема** | `qr.*` — таблицы, `fn_*`, `sp_*` | `public` не используется для данных |
| **Запись (INSERT/UPDATE/DELETE)** | Только хранимые функции `qr.sp_*` | Параметры типизированы в PostgreSQL |
| **Чтение доменных данных** | Функции `sp_*` или ORM `select()` | ORM и `:named` параметры SQLAlchemy |
| **Справочники** | ORM `select()` на `qr.*` lookup-таблицы | ORM + `search_path=qr,public` |
| **Роль `qr_app`** | `SELECT` на `qr.*` + `EXECUTE` на функции | Прямой DML на таблицы **запрещён** |

---

## Архитектура

```
FastAPI route
    → service (orders.py / memorials.py / auth.py)
        → app/db/procedures.py  (call_sp, sp_one, sp_all, sp_scalar)
            → PostgreSQL qr.sp_*()  SECURITY DEFINER, search_path = qr, public
                → INSERT / UPDATE / DELETE
```

**Триггеры** (`fn_*` в `07_logic.sql`) срабатывают автоматически внутри процедур:
- один успешный платёж на заказ;
- лимиты фото/видео;
- синхронизация суммы заказа;
- привязка QR к мемориалу.

---

## Файлы SQL

| Файл | Назначение |
|------|------------|
| `db/scripts/01_init.sql` | Расширения + **CREATE SCHEMA qr** |
| `db/scripts/02_lookups.sql` | Справочники |
| `db/scripts/03_users_auth.sql` | Пользователи, токены, согласия |
| `db/scripts/04_commerce.sql` | Заказы, платежи, QR-коды |
| `db/scripts/05_content.sql` | Мемориалы, медиа, отзывы |
| `db/scripts/06_system.sql` | Аудит, идемпотентность |
| `db/scripts/07_logic.sql` | Триггеры `fn_*` и **процедуры `sp_*`** (все DML из backend) |
| `db/scripts/08_seed.sql` | Начальные данные |
| `db/scripts/09_grants.sql` | Права роли `qr_app` (после `07`) |
| `db/scripts/00_full_schema.sql` | Полная схема для DBeaver (01–09) |

Порядок сборки: `07_logic.sql` → `09_grants.sql` (сначала функции, потом `GRANT EXECUTE`).

Пересборка монолита:

```powershell
cd db/scripts
.\build_full_schema.ps1
```

---

## Права роли `qr_app`

Из `09_grants.sql` (схема **`qr`**):

- **Разрешено:** `USAGE` на схему `qr`, `SELECT` на таблицы, `EXECUTE` на функции.
- **Запрещено:** прямой `INSERT`, `UPDATE`, `DELETE` на таблицы.
- **`ALTER ROLE qr_app SET search_path TO qr, public`** — backend находит `sp_*` без префикса.

Функции `sp_*` объявлены как **`SECURITY DEFINER`** с **`SET search_path = qr, public`**.

---

## Список процедур `sp_*`

### Auth (`auth.py`)

| Функция | Назначение |
|---------|------------|
| `sp_user_email_exists` | Проверка email при регистрации |
| `sp_user_phone_exists` | Проверка телефона при регистрации / PATCH профиля |
| `sp_register_user` | INSERT в `users` + `fn_link_guest_orders_to_user` |
| `sp_update_user_profile` | PATCH ФИО, email, телефона в личном кабинете |
| `sp_update_last_login` | Обновление `last_login_at` |
| `sp_insert_refresh_token` | INSERT refresh-токена |
| `sp_revoke_refresh_token_by_hash` | Отзыв сессии |

Логин по-прежнему читает `users` через ORM (нужен `password_hash` для bcrypt в Python).

### Заказы и платежи (`orders.py`)

| Функция | Назначение |
|---------|------------|
| `sp_create_checkout_order` | Атомарно: `orders` + `order_lines` + `order_deliveries` |
| `sp_record_payment` | INSERT в `payments` после ответа ЮKassa |
| `sp_get_order_status` | Статус заказа для success-страницы |
| `sp_webhook_event_exists` | Идемпотентность webhook |
| `sp_insert_webhook_event` | Сохранение сырого события |
| `sp_apply_payment_succeeded` | UPDATE `payments` + `orders` при успехе |
| `sp_mark_webhook_processed` | Отметка обработки webhook |

### Мемориалы и медиа (`memorials.py`)

| Функция | Назначение |
|---------|------------|
| `sp_create_memorial` | Создание мемориала |
| `sp_update_memorial` | PATCH с флагами `p_set_*` (без динамического SQL) |
| `sp_get_memorial` | Карточка мемориала |
| `sp_list_memorial_ids_by_owner` | Список в ЛК |
| `sp_get_memorial_media` | Файлы мемориала |
| `sp_memorial_owner_id` | Проверка владельца |
| `sp_insert_media_file` | Загрузка файла (+ лимит фото) |
| `sp_soft_delete_media` | Мягкое удаление |
| `sp_list_portrait_media` | Замена портрета |
| `sp_get_media_for_delete` | Удаление с проверкой прав |
| `sp_lookup_media_type_id` | Справочник типов медиа |
| `sp_lookup_processing_status_id` | Статус обработки |

---

## Backend: подключение

`backend/app/core/database.py` задаёт для каждой сессии:

```python
connect_args={"server_settings": {"search_path": "qr,public"}}
```

ORM-модели: `metadata = MetaData(schema="qr")` в `app/models/base.py`.

Переменная окружения: `POSTGRES_SCHEMA=qr` (по умолчанию `qr`).

---

## Backend: как вызывать процедуры

Модуль `backend/app/db/procedures.py`:

```python
from app.db.procedures import call_sp, sp_one

row = await sp_one(
    db,
    "SELECT * FROM sp_get_order_status(:order_id)",
    {"order_id": order_id},
)
```

**Правила для разработчиков:**

1. Не писать `INSERT`/`UPDATE`/`DELETE` в `text()` из Python.
2. Новая запись в БД → новая `sp_*` в `07_logic.sql` + `GRANT EXECUTE` через `09_grants.sql`.
3. Пользовательский ввод — только как `:параметр`, никогда в f-string SQL.
4. PATCH-поля — через явные флаги (`p_set_full_name`), как в `sp_update_memorial`.

---

## Защита от SQL-инъекций

### Было (до `sp_*`)

- Raw SQL уже использовал `:named` параметры — **инъекций не было**.
- Риск: новый код мог добавить f-string SQL (как в `update_memorial` с whitelist колонок).

### Стало

1. **Параметризованные функции** — PostgreSQL проверяет типы аргументов.
2. **Запрет прямого DML** для `qr_app` — даже при ошибке в коде приложение не сможет выполнить произвольный `UPDATE`.
3. **`SET search_path = qr, public`** в каждой `sp_*` — защита от подмены схемы при `SECURITY DEFINER`.
4. **Отдельная схема `qr`** — данные приложения изолированы от `public`.
4. **Триггеры** — бизнес-правила на уровне БД не обходятся через «сырой» SQL.

---

## Применение на существующей БД

Если схема уже развёрнута в `public` (старая версия):

1. Dev: `99_drop_all.sql` → `00_full_schema.sql`
2. Или миграция: перенос объектов в `qr` вручную (проще пересоздать на dev)

Если схема `qr` есть, но нет `sp_*`:

```sql
\i db/scripts/07_logic.sql
\i db/scripts/09_grants.sql
```

Или полный пересоздание (dev):

```powershell
# 99_drop_all.sql → 00_full_schema.sql
```

---

## Что остаётся через ORM

- Чтение справочников (`package_types`, `order_statuses`, …).
- Чтение `users` при логине (bcrypt в Python).
- Чтение `refresh_tokens` при logout (поиск по hash).
- Health check: `SELECT 1`.

Эти пути используют SQLAlchemy ORM / параметризованный SQL — безопасны. При необходимости их тоже можно обернуть в `sp_*`.

---

## Связанные документы

- [db/README.md](../db/README.md) — установка схемы
- [db/detal_logic_db.md](../db/detal_logic_db.md) — логика таблиц
- [docs/LOCAL_SETUP.md](LOCAL_SETUP.md) — локальный запуск
