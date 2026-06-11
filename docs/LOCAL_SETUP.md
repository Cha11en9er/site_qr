# Локальный запуск QR Память

Пошаговый гайд: клонировали репозиторий или сделали `git pull` — что установить и как запустить API + UI на своей машине.

---

## Что нужно заранее

| Инструмент | Версия | Зачем |
|------------|--------|-------|
| **Git** | любая актуальная | код проекта |
| **Python** | 3.12+ | backend FastAPI |
| **Node.js** | 20+ | frontend Vite |
| **npm** | идёт с Node | зависимости UI |
| **PostgreSQL** | 16 | база данных |
| **DBeaver** | опционально | удобно накатывать SQL (рекомендуется) |
| **ngrok** | опционально | туннель для webhooks (ЮKassa) и внешнего доступа к API |

Проверка в PowerShell:

```powershell
python --version
node --version
npm --version
```

---

## Быстрый чеклист после `git pull`

```text
1.  cp .env.example → .env          (один раз, потом править при необходимости)
2.  PostgreSQL: БД qr_pamyat + SQL-скрипты   (первый раз или после изменений схемы)
3.  backend:  python -m venv .venv  +  pip install -r requirements.txt
4.  frontend: npm install
5.  Терминал 1: uvicorn …           (API :8000)
6.  Терминал 2: npm run dev         (UI :5173)
7.  (опц.) ngrok http 8000          (webhooks / внешний доступ — см. §7)
```

---

## 1. Получить код

```powershell
cd C:\repos\YouDo\site_qr
git pull
```

Если репозиторий новый:

```powershell
git clone <url-репозитория> site_qr
cd site_qr
```

---

## 2. Файл `.env`

`.env` **не в git** — создаётся локально из шаблона.

```powershell
cd C:\repos\YouDo\site_qr
copy .env.example .env
```

Минимум для локальной работы (обычно уже так в `.env.example`):

```env
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DB=qr_pamyat
POSTGRES_USER=qr_app
POSTGRES_PASSWORD=qr_app

DATABASE_URL=postgresql+asyncpg://qr_app:qr_app@localhost:5432/qr_pamyat

JWT_SECRET=dev_local_jwt_secret_change_in_production_32chars
CORS_ORIGINS=http://localhost:5173,http://127.0.0.1:5173

VITE_API_BASE_URL=/api/v1
```

| Переменная | Смысл |
|------------|--------|
| `DATABASE_URL` | подключение backend → PostgreSQL |
| `JWT_SECRET` | подпись access-токенов (на проде — длинная случайная строка) |
| `VITE_API_BASE_URL=/api/v1` | фронт ходит на `/api/…`, Vite проксирует на `:8000` |
| `MEDIA_STORAGE_ROOT=uploads` | корень файлов на диске; **в БД** — только относительные пути (`memorials/{uuid}/photos/...`) |
| Папка `uploads/` | `C:\repos\YouDo\site_qr\uploads` (создаётся при первой загрузке; демо: `uploads/demos/`) |

> Если PostgreSQL на другом порту или пароль другой — меняйте и `POSTGRES_*`, и `DATABASE_URL`.

---

## 3. База данных PostgreSQL

### Вариант A — PostgreSQL уже установлен (DBeaver)

**Первый раз:**

| Шаг | Где в DBeaver | Файл |
|-----|---------------|------|
| 1 | Создать БД `qr_pamyat` (UTF8) | GUI: ПКМ → Create Database |
| 2 | Подключение к **`postgres`** | `db/scripts/00_database.sql` |
| 3 | Подключение к **`qr_pamyat`** | `db/scripts/00_full_schema.sql` (**Alt+X**) |
| 4 | Подключение к **`qr_pamyat`** | `db/scripts/13_portrait_media_type.sql` (тип «Главная фотография») |

Подробнее: [db/dbeaver/GUIDE.md](../db/dbeaver/GUIDE.md)

**После `git pull`**, если в коммитах менялись файлы в `db/scripts/`:

- dev: можно сбросить и накатить заново (`db/scripts/99_drop_all.sql` → снова `00_full_schema.sql`);
- или применить только новые миграции Alembic (когда появятся в `backend/alembic/`).

**Проверка:**

```sql
SELECT count(*) FROM package_types;   -- ожидается 3
SELECT count(*) FROM user_roles;      -- ожидается 2
```

### Вариант B — PostgreSQL через Docker

Из корня проекта (нужен Docker Desktop):

```powershell
cd C:\repos\YouDo\site_qr
docker compose up -d postgres
```

Контейнер поднимет Postgres на `localhost:5432`. Дальше в DBeaver:

1. `00_database.sql` (к **`postgres`**)
2. `00_full_schema.sql` (к **`qr_pamyat`**)

Пароль в `docker-compose.yml` по умолчанию может отличаться от `qr_app` — тогда подстройте `.env` под `POSTGRES_PASSWORD` из compose или используйте локальный Postgres с паролем `qr_app`.

---

## 4. Backend (Python + venv)

```powershell
cd C:\repos\YouDo\site_qr\backend

# venv — один раз (или после смены версии Python)
python -m venv .venv

# активация (каждый новый терминал — необязательно, если вызываете .venv\Scripts\... напрямую)
.\.venv\Scripts\Activate.ps1

# зависимости — после каждого git pull, если менялся requirements.txt
.\.venv\Scripts\pip install -r requirements.txt
```

Если PowerShell ругается на активацию:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

**Запуск API:**

```powershell
cd C:\repos\YouDo\site_qr\backend
.\.venv\Scripts\uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

Проверка:

- http://127.0.0.1:8000/docs — Swagger
- http://127.0.0.1:8000/api/v1/health — `{"status":"ok",…}`
- http://127.0.0.1:8000/api/v1/health/db — `database: connected`, `package_types_count: 3`

---

## 5. Frontend (npm)

```powershell
cd C:\repos\YouDo\site_qr\frontend

# после git pull — если менялся package.json
npm install

# dev-сервер
npm run dev
```

Открой в браузере: **http://127.0.0.1:5173**

| Действие | URL |
|----------|-----|
| Главная | http://127.0.0.1:5173 |
| Вход / регистрация | кнопка «Войти» в шапке |
| Личный кабинет | http://127.0.0.1:5173/cabinet |

> **Важно:** UI и API — **два процесса**. Если видишь `ERR_CONNECTION_REFUSED` на `:5173` — не запущен `npm run dev`. Если форма входа пишет про сеть — проверь uvicorn на `:8000`.

---

## 6. Два терминала — итог

**Терминал 1 — API**

```powershell
cd C:\repos\YouDo\site_qr\backend
.\.venv\Scripts\uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

**Терминал 2 — UI**

```powershell
cd C:\repos\YouDo\site_qr\frontend
npm run dev
```

---

## 7. Ngrok — внешний доступ и webhooks (опционально)

Нужен, когда внешний сервис должен достучаться до **локального API** — например, webhook **ЮKassa** на `:8000` (см. [DEVELOPMENT_GUIDE.md](DEVELOPMENT_GUIDE.md), §8).

### Установка (Windows)

**Вариант A — winget**

```powershell
winget install ngrok.ngrok
```

**Вариант B — вручную**

1. Скачайте с [ngrok.com/download](https://ngrok.com/download)
2. Распакуйте `ngrok.exe` в папку из `PATH` или запускайте по полному пути

Проверка:

```powershell
ngrok version
```

Если `ngrok` не находится даже в **новом** терминале (часто в **Cursor/VS Code** — IDE не подхватывает обновлённый `PATH`):

1. **Перезапустите Cursor целиком** (закрыть приложение → открыть снова), не только вкладку терминала.
2. Или обновите `PATH` в текущей сессии:

```powershell
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
ngrok version
```

3. Или запуск по полному пути / из `%USERPROFILE%\.local\bin` (если копировали туда):

```powershell
& "$env:USERPROFILE\.local\bin\ngrok.exe" version
# альтернатива — путь winget:
& "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\Ngrok.Ngrok_Microsoft.Winget.Source_8wekyb3d8bbwe\ngrok.exe" version
```

### Активация (один раз)

1. Зарегистрируйтесь на [dashboard.ngrok.com](https://dashboard.ngrok.com/signup)
2. В разделе **Your Authtoken** скопируйте токен
3. Привяжите токен к машине:

```powershell
ngrok config add-authtoken <ВАШ_AUTHTOKEN>
```

Токен сохранится в `%USERPROFILE%\.ngrok2\ngrok.yml` (или `%LOCALAPPDATA%\ngrok\ngrok.yml` — зависит от версии).

### Обновление (если `authentication failed` / версия слишком старая)

Минимальная версия агента на ngrok.com периодически растёт. Обновите:

```powershell
ngrok update
ngrok version   # ожидается 3.20+
```

### Запуск туннеля

Сначала должен работать **backend на `:8000`** (см. §4). В **отдельном терминале**:

```powershell
ngrok http 8000
```

В выводе появится публичный URL, например:

```text
Forwarding   https://a1b2c3d4.ngrok-free.app -> http://localhost:8000
```

Проверка снаружи:

- `https://<ваш-поддомен>.ngrok-free.app/api/v1/health` — тот же ответ, что на `http://127.0.0.1:8000/api/v1/health`

### Webhook ЮKassa (когда подключите оплату)

| Поле в ЛК ЮKassa | Значение |
|------------------|----------|
| URL webhook | `https://<ваш-поддомен>.ngrok-free.app/api/webhooks/yookassa` |

> URL ngrok **меняется** на бесплатном плане при каждом перезапуске — после рестарта `ngrok http 8000` обновите адрес в ЛК ЮKassa.

### Три терминала — итог (API + UI + ngrok)

```text
Терминал 1: uvicorn … --port 8000
Терминал 2: npm run dev
Терминал 3: ngrok http 8000
```

### Частые проблемы ngrok

| Симптом | Решение |
|---------|---------|
| `ngrok` не распознано / `CommandNotFoundException` | Установите: `winget install ngrok.ngrok`. Затем **перезапустите Cursor** (не только терминал) или обновите `$env:Path` в сессии; запасной вариант — `~\.local\bin\ngrok.exe` |
| `ERR_NGROK_4018` / invalid authtoken | Повторите `ngrok config add-authtoken …` с токеном из dashboard |
| `agent version is too old` / `ERR_NGROK_121` | `ngrok update`, затем снова `ngrok http 8000` |
| `502 Bad Gateway` на ngrok-URL | Не запущен uvicorn на `:8000` |
| Страница-предупреждение ngrok в браузере | На бесплатном плане — норма; для webhook-серверов (ЮKassa) обычно не мешает |

---

## 8. После каждого `git pull` — что обновлять

| Изменилось в репо | Действие |
|-------------------|----------|
| `backend/requirements.txt` | `pip install -r requirements.txt` |
| `frontend/package.json` | `npm install` |
| `db/scripts/*.sql` | пересоздать/накатить схему (см. §3) |
| `.env.example` | сравнить с своим `.env`, добавить новые ключи вручную |
| только код backend/frontend | перезапустить uvicorn / `npm run dev` (с `--reload` API сам подхватит) |

`.env` **не перезаписывается** при pull — его ведёшь только ты локально.

---

## 9. Частые проблемы

### `ERR_CONNECTION_REFUSED` на http://127.0.0.1:5173

Не запущен frontend:

```powershell
cd frontend
npm run dev
```

### Ошибка входа / «не удалось выполнить запрос»

Не запущен backend или неверный `DATABASE_URL`:

```powershell
cd backend
.\.venv\Scripts\uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

Открой http://127.0.0.1:8000/api/v1/health/db — должно быть `"status":"ok"`.

### `password authentication failed for user "qr_app"`

1. Выполнен ли `db/scripts/00_database.sql`?
2. Совпадают ли пароль в `.env` и роль в PostgreSQL (по умолчанию `qr_app` / `qr_app`)?

### `relation "users" does not exist`

Не накатана схема — выполни `db/scripts/00_full_schema.sql` на БД `qr_pamyat`.

### Телефон при регистрации не принимается

Формат: `+79001234567` (или `89001234567` — нормализуется на сервере).

---

## 10. Полезные ссылки

| Документ | Содержание |
|----------|------------|
| [db/README.md](../db/README.md) | схема БД, файлы SQL |
| [db/detal_logic_db.md](../db/detal_logic_db.md) | логика таблиц |
| [db/dbeaver/GUIDE.md](../db/dbeaver/GUIDE.md) | DBeaver пошагово |
| [docs/DEVELOPMENT_GUIDE.md](DEVELOPMENT_GUIDE.md) | стек, архитектура, прод |

---

## 11. Сборка production-статики (опционально)

```powershell
cd frontend
npm run build
# результат в frontend/dist/
```

Docker-образ frontend: см. `frontend/Dockerfile`.
