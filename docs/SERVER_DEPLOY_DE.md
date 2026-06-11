# Деплой на VPS (Германия) — HTTP по IP

Сервер: `vm830360`, IP `87.251.86.53`, папка `/opt/site_qr`.

**Результат:** сайт в браузере, запись в БД, загрузка фото, оплата ЮKassa (webhook через ngrok, пока нет HTTPS). Почта — заглушка.

> Python, PostgreSQL, venv и npm **на сервере ставить не нужно** — всё собирается внутри Docker при `docker compose build`.

Связанные документы: [PAYMENT_SETUP.md](PAYMENT_SETUP.md), [LOCAL_SETUP.md](LOCAL_SETUP.md) (локально — там venv + npm).

---

## Шаг 1. Проверки

Выполняйте по порядку. Если вывод совпадает с «Ожидается» — переходите к следующей проверке.

---

### 1.1 Docker

```bash
docker --version
```

**Ожидается:**

```text
Docker version 29.x.x ...
```

**Если ошибка** → [§2.1](#21-установить-docker)

---

### 1.2 Docker Compose

```bash
docker compose version
```

**Ожидается:**

```text
Docker Compose version v5.x.x
```

**Если ошибка** → [§2.2](#22-установить-docker-compose)

---

### 1.3 Git

```bash
git --version
```

**Ожидается:**

```text
git version 2.34.x
```

**Если ошибка** → [§2.3](#23-установить-git-и-curl)

---

### 1.4 Порт 80 свободен

```bash
ss -tlnp | grep ':80 '
```

**Ожидается:** пустой вывод (ничего не слушает 80).

**Если строка есть** — порт занят. В `.env` укажите другой `WEB_PORT` (например `8888`) и откройте его в ufw.

---

### 1.5 Порт 8080 — чужой проект

```bash
ss -tlnp | grep ':8080'
```

**Ожидается на vm830360:**

```text
docker-proxy ... :8080
```

Это **не наш** сайт. Для QR Память используем **порт 80**, не 8080.

---

### 1.6 Firewall — порт 80 открыт

```bash
ufw status | grep 80/tcp
```

**Ожидается:**

```text
80/tcp    ALLOW    Anywhere
```

**Если пусто** → [§2.4](#24-открыть-порт-80-в-ufw)

---

### 1.7 Исходящий HTTPS к ЮKassa

```bash
curl -sI --max-time 10 https://api.yookassa.ru/v3/payments | head -1
```

**Ожидается:**

```text
HTTP/2 401
```

401 без ключей — норма. Главное, что соединение есть.

---

### 1.8 Место на диске

```bash
df -h / | tail -1
```

**Ожидается:** свободно **> 5 ГБ** (у вас ~68 ГБ — OK).

---

### 1.9 Публичный IP

```bash
curl -4 -s ifconfig.me
```

**Ожидается:**

```text
87.251.86.53
```

Этот IP — в `CORS_ORIGINS` и `YOOKASSA_RETURN_URL` в `.env`.

---

## Шаг 2. Исправления

Только то, что не прошло в шаге 1. По одной команде.

---

### 2.1 Установить Docker

```bash
apt update
```

```bash
apt install -y docker.io
```

```bash
systemctl enable --now docker
```

---

### 2.2 Установить Docker Compose

```bash
apt install -y docker-compose-plugin
```

---

### 2.3 Установить Git и curl

```bash
apt install -y git curl ca-certificates
```

---

### 2.4 Открыть порт 80 в ufw

```bash
ufw allow 80/tcp
```

Проверка:

```bash
ufw status | grep 80/tcp
```

---

## Шаг 3. Код на сервере

---

### 3.1 Клонировать репозиторий

```bash
cd /opt
```

```bash
git clone https://github.com/Cha11en9er/site_qr.git site_qr
```

```bash
cd site_qr
```

> **Важно:** на GitHub должны быть файлы `deploy/docker-compose.staging.yml` и `deploy/Dockerfile.staging-web`. Если вы их ещё не пушили с Windows — сначала `git push`, либо [§3.2](#32-альтернатива-архив-с-windows).

---

### 3.2 Альтернатива: архив с Windows

На Windows (PowerShell):

```powershell
cd C:\repos\YouDo\site_qr
tar -czf site_qr.tar.gz --exclude=node_modules --exclude=.venv --exclude=frontend/dist .
scp site_qr.tar.gz root@87.251.86.53:/opt/
```

На сервере:

```bash
mkdir -p /opt/site_qr
```

```bash
tar -xzf /opt/site_qr.tar.gz -C /opt/site_qr
```

```bash
cd /opt/site_qr
```

---

### 3.3 Проверить, что deploy-файлы на месте

```bash
ls deploy/docker-compose.staging.yml
```

**Ожидается:**

```text
deploy/docker-compose.staging.yml
```

```bash
ls deploy/Dockerfile.staging-web
```

**Ожидается:**

```text
deploy/Dockerfile.staging-web
```

**Если `No such file`** — вернитесь к §3.2 или сделайте `git push` с Windows и `git pull` на сервере.

---

## Шаг 4. Файлы проекта

Файлы, которых **нет в git**: `.env` (секреты). Остальное — в репозитории.

---

### 4.1 Создать `.env`

```bash
cd /opt/site_qr
```

```bash
cp .env.example .env
```

---

### 4.2 Заполнить `.env`

```bash
nano .env
```

Минимум (подставьте свой пароль и ключи ЮKassa):

```env
POSTGRES_DB=qr_pamyat
POSTGRES_USER=qr_app
POSTGRES_PASSWORD=ЗАМЕНИТЕ_СЛОЖНЫЙ_ПАРОЛЬ

DATABASE_URL=postgresql+asyncpg://qr_app:ЗАМЕНИТЕ_СЛОЖНЫЙ_ПАРОЛЬ@postgres:5432/qr_pamyat

JWT_SECRET=ЗАМЕНИТЕ_СЛУЧАЙНАЯ_СТРОКА_32_СИМВОЛА_МИНИМУМ

CORS_ORIGINS=http://87.251.86.53

MEDIA_STORAGE_ROOT=/data/uploads
MEDIA_STORAGE_BUCKET=local

YOOKASSA_SHOP_ID=ваш_тестовый_shopId
YOOKASSA_SECRET_KEY=ваш_тестовый_secret
YOOKASSA_RETURN_URL=http://87.251.86.53/order/success

WEB_PORT=80
VITE_API_BASE_URL=/api/v1
```

Сохранить: `Ctrl+O`, Enter, `Ctrl+X`.

---

### 4.3 Права на `.env`

```bash
chmod 600 .env
```

---

### 4.4 Папка для загрузок

```bash
mkdir -p uploads
```

---

## Шаг 5. Зависимости и запуск

На сервере **не нужны** `python -m venv` и `npm install` вручную.

| Что | Где ставится |
|-----|--------------|
| `pip install` (backend) | внутри образа `api` при сборке |
| `npm install` + `npm run build` (frontend) | внутри образа `web` при сборке |
| PostgreSQL 16 | контейнер `postgres` |
| Схема БД | автоматически при первом старте postgres |

---

### 5.1 Собрать и запустить

```bash
cd /opt/site_qr
```

```bash
docker compose -f deploy/docker-compose.staging.yml up -d --build
```

Первый запуск занимает несколько минут (скачивание образов, сборка).

---

### 5.2 Проверить контейнеры

```bash
docker compose -f deploy/docker-compose.staging.yml ps
```

**Ожидается:** три сервиса `postgres`, `api`, `web` — статус `running`.

**Если `Exited`** — смотрите логи:

```bash
docker compose -f deploy/docker-compose.staging.yml logs api
```

```bash
docker compose -f deploy/docker-compose.staging.yml logs web
```

```bash
docker compose -f deploy/docker-compose.staging.yml logs postgres
```

---

### 5.3 Перезапуск после смены `.env`

```bash
docker compose -f deploy/docker-compose.staging.yml up -d --build
```

---

## Шаг 6. Тестирование

---

### 6.1 API жив

```bash
curl -s http://127.0.0.1/api/v1/health
```

**Ожидается:**

```json
{"status":"ok","service":"qr-pamyat-api"}
```

---

### 6.2 База подключена

```bash
curl -s http://127.0.0.1/api/v1/health/db
```

**Ожидается:**

```json
{"status":"ok","database":"connected","package_types_count":3}
```

---

### 6.3 Сайт с телефона / другого ПК

Откройте в браузере:

```text
http://87.251.86.53/
```

**Ожидается:** главная страница, кнопки, переходы по разделам.

---

### 6.4 Запись в БД — регистрация

1. На сайте: «Войти» → «Регистрация» → email + пароль → зарегистрироваться.
2. На сервере:

```bash
docker compose -f deploy/docker-compose.staging.yml exec postgres psql -U qr_app -d qr_pamyat -c "SELECT email FROM qr.users LIMIT 5;"
```

**Ожидается:** строка с вашим email.

---

### 6.5 Загрузка картинок

1. Войдите в личный кабинет → мемориал → загрузите фото.
2. На сервере:

```bash
ls -la /opt/site_qr/uploads/
```

**Ожидается:** появились файлы или подпапки `memorials/...`.

---

### 6.6 Оплата

**Часть A — редирект на ЮKassa (без ngrok):**

1. На сайте оформите заказ → «Оплатить».
2. **Ожидается:** переход на страницу ЮKassa (тестовая карта из [документации](https://yookassa.ru/developers/payment-acceptance/testing-and-going-live/testing)).

**Часть B — заказ становится `paid` (нужен webhook):**

ЮKassa не шлёт webhook на `http://IP` — только HTTPS. Временное решение:

```bash
ngrok http 80
```

В личном кабинете ЮKassa → HTTP-уведомления:

```text
https://ВАШ_ПОДДОМЕН.ngrok-free.app/api/webhooks/yookassa
```

После тестовой оплаты:

```bash
curl -s "http://127.0.0.1/api/v1/orders/ВАШ_ORDER_ID/status"
```

**Ожидается:** `"is_paid": true`.

Подробнее: [PAYMENT_SETUP.md](PAYMENT_SETUP.md).

---

### 6.7 Почта

Письма **не отправляются** — в backend нет SMTP. Текст на странице «Оплата прошла» про письмо — заглушка. Вход — по email/паролю из регистрации.

---

## Шаг 7. Обновление после изменений в коде

На Windows: `git push`.

На сервере:

```bash
cd /opt/site_qr
```

```bash
git pull
```

```bash
docker compose -f deploy/docker-compose.staging.yml up -d --build
```

---

## Москва (потом)

| Сейчас (Германия) | Потом (Москва) |
|-------------------|----------------|
| `http://87.251.86.53` | `https://ваш-домен.ru` |
| ngrok для webhook | webhook на домен, ngrok не нужен |
| `CORS_ORIGINS=http://IP` | `CORS_ORIGINS=https://домен.ru` |

---

## Частые проблемы

| Симптом | Решение |
|---------|---------|
| Сайт не открывается снаружи | §1.6 → `ufw allow 80/tcp` |
| `deploy/docker-compose.staging.yml` нет | §3.2 архив или `git push` + clone |
| `package_types_count` не 3 | `docker compose … logs postgres`, при необходимости `down -v` и снова `up --build` |
| CORS в браузере | В `.env` точно `CORS_ORIGINS=http://87.251.86.53` |
| `YOOKASSA_NOT_CONFIGURED` | Заполнить `YOOKASSA_SHOP_ID` и `YOOKASSA_SECRET_KEY` в `.env`, перезапуск §5.3 |
| Оплата прошла, заказ не `paid` | §6.6 часть B — ngrok для webhook |
| Фото не появляются в `uploads/` | `mkdir -p uploads`, перезапуск `api` |

---

## Чеклист vm830360

```text
□ 1.1–1.9 проверки пройдены
□ 2.4 ufw allow 80/tcp
□ 3.1 git clone в /opt/site_qr
□ 4.1–4.4 .env создан и заполнен
□ 5.1 docker compose up -d --build
□ 6.1–6.3 health + сайт в браузере
□ 6.4 регистрация видна в БД
□ 6.5 фото в uploads/
□ 6.6 оплата + ngrok webhook
```

Сайт: **http://87.251.86.53/**
