# Гайд по разработке: QR-коды на памятники (РФ)

Практическое руководство по стеку, оплате, хранению файлов, синхронизации QR и оптимизации.  
Ориентир: российский рынок, официальные платёжные схемы, Yandex Cloud.

---

## 1. Рекомендуемый стек

### Frontend
| Технология | Зачем |
|------------|-------|
| **React 18 + Vite + TypeScript** | Быстрая сборка, типизация |
| **Tailwind CSS + shadcn/ui** | Спокойный UI без долгой вёрстки |
| **React Router v6** | ЛК, админка, публичные страницы |
| **Zustand** | Auth, корзина, UI-состояние |
| **TanStack Query** | Кэш API, retry, optimistic updates |
| **React Hook Form + Zod** | Формы покупки и мемориала |
| **Leaflet / Yandex Maps API** | Геолокация могилы |

### Backend (монолит → микросервисы)
| Технология | Зачем |
|------------|-------|
| **FastAPI** | Async, OpenAPI из коробки, быстрая разработка |
| **SQLModel / SQLAlchemy 2** | ORM + Pydantic-модели |
| **PostgreSQL 16** | Надёжность, JSONB для метаданных, полнотекст |
| **Alembic** | Миграции |
| **Redis** | Сессии, очереди, rate limit |
| **Celery / ARQ** | Фон: thumbs, email, транскодинг |
| **boto3** | Yandex Object Storage (S3 API) |

### Инфра (локально → прод)
```
Локально:  docker-compose (postgres, redis, minio, api, frontend)
Прод:      VPS / Yandex Compute + Managed PostgreSQL + Object Storage + CDN
```

**Почему не менять стек:** React + FastAPI + PostgreSQL — стандарт для подобных проектов (см. кейсы Remember Well, Legacy Honored, Nova Memorial). S3-совместимое хранилище используют все мемориальные платформы с медиа.

---

## 2. Архитектура данных (ядро)

```
┌─────────────┐     ┌──────────────┐     ┌─────────────────┐
│   React     │────▶│   FastAPI    │────▶│   PostgreSQL    │
│   (Vite)    │     │   (монолит)  │     │                 │
└──────┬──────┘     └──────┬───────┘     └─────────────────┘
       │                   │
       │ presigned URL     │ webhook
       ▼                   ▼
┌─────────────┐     ┌──────────────┐
│ Yandex S3   │     │   ЮKassa     │
│ + CDN       │     │   (оплата)   │
└─────────────┘     └──────────────┘
```

### Ключевые таблицы

```sql
users           -- email, phone, password_hash, role
memorials       -- deceased info, package_type, owner_id, slug
media_files     -- memorial_id, s3_key, type, duration_sec, thumb_key
orders          -- user_id, amount, status, payment_id (yookassa)
order_items     -- order_id, package, qty, unit_price
qr_codes        -- code_slug, order_id, memorial_id, status, scan_count
reviews         -- memorial_id, author, text, moderation_status
payments        -- yookassa_id, status, receipt_url, paid_at
```

---

## 3. Оплата в РФ — что выбрать

### Рекомендация для старта: **ЮKassa** (yookassa.ru)

**Почему:**
- Официальный агрегатор (НКО «ЮМани»), на рынке с 2013
- Одна интеграция → много способов оплаты
- Встроенные **чеки по 54-ФЗ** («Чеки от ЮKassa») — не нужно покупать отдельную кассу
- Хорошая документация API на русском
- Тестовый магазин для разработки

### Какие способы оплаты получите

| Способ | Что это | Комиссия (ориентир) |
|--------|---------|---------------------|
| **Банковские карты** | МИР, Visa, Mastercard | ~2,5–3,9% |
| **СБП** | QR или выбор банка в приложении | ~0,4–0,7% (ниже всего) |
| **SberPay** | Оплата через приложение Сбера | в составе карт |
| **ЮMoney** | Кошелёк | отдельная ставка |

**Совет:** на форме оплаты **выделите СБП** — ниже комиссия, привычно для РФ, высокая конверсия на мобильных.

### Альтернативы

| Провайдер | Когда брать |
|-----------|-------------|
| **Robokassa** | Самозанятый без ИП/расчётного счёта; проще старт, но выше комиссия (~4,5%) |
| **CloudPayments** | Нужны рекуррентные подписки (у вас разовая покупка — не приоритет) |
| **Тинькофф / Сбер эквайринг напрямую** | Крупный оборот, ниже %, но дольше подключение и жёстче требования |
| **СБП напрямую через банк** | Только СБП, без карт; имеет смысл как доп. канал, не вместо агрегатора |

### Что нужно для подключения ЮKassa (боевой режим)

1. **ИП или ООО** (для физлица без статуса — Robokassa)
2. Расчётный счёт
3. Сайт с HTTPS, офертой, политикой конфиденциальности
4. Описание товара/услуги для банка-эквайера
5. Подключить «Чеки от ЮKassa» (54-ФЗ)
6. В личном кабинете: `shopId` + `secretKey`

### Схема оплаты (как у всех нормальных магазинов)

```
1. Пользователь заполняет форму покупки
2. Backend: POST /v3/payments (ЮKassa)
   - amount, receipt (54-ФЗ), confirmation: redirect
   - metadata: { order_id }
3. Frontend: redirect на confirmation_url (страница ЮKassa)
4. Пользователь платит (карта / СБП / SberPay)
5. ЮKassa → webhook POST /api/webhooks/yookassa
   - событие payment.succeeded
6. Backend (идемпотентно):
   - order.status = paid
   - сгенерировать QR-коды
   - отправить email
7. Пользователь → return_url на сайт (страница «Спасибо»)
```

**Важно:**
- Никогда не доверяйте только `return_url` — пользователь может закрыть вкладку. Истина — **webhook**.
- Используйте заголовок `Idempotence-Key` (UUID) при создании платежа.
- Храните `yookassa_payment_id` в таблице `payments`.

### Пример тела платежа (упрощённо)

```json
{
  "amount": { "value": "5990.00", "currency": "RUB" },
  "confirmation": {
    "type": "redirect",
    "return_url": "https://qr-pamyat.ru/order/success?order_id=..."
  },
  "capture": true,
  "description": "QR-код воспоминания, пакет Премиум",
  "metadata": { "order_id": "uuid-here" },
  "receipt": {
    "customer": { "email": "buyer@mail.ru", "phone": "+79001234567" },
    "items": [{
      "description": "QR-код воспоминания, Премиум, 1 шт.",
      "quantity": "1.00",
      "amount": { "value": "5990.00", "currency": "RUB" },
      "vat_code": 1,
      "payment_mode": "full_payment",
      "payment_subject": "service"
    }]
  }
}
```

Документация: https://yookassa.ru/developers

---

## 4. Синхронизация QR-кодов

Главная ошибка новичков — **кодировать в QR прямую ссылку на мемориал**. Если URL сменится или мемориал перенесётся — придётся перевыпускать физические плашки.

### Правильная схема: короткий редирект

```
Физический QR  →  https://qr-pamyat.ru/r/Ab3xK9
                         │
                         ▼
              Backend lookup qr_codes.code_slug
                         │
            ┌────────────┼────────────┐
            ▼            ▼            ▼
      not_activated   active     disabled
      (страница       redirect   (404 / сообщение)
       «войдите
        в ЛК»)         → /m/ivanov-1945
```

### Жизненный цикл QR-кода

| Статус | Описание |
|--------|----------|
| `generated` | Создан после оплаты, ещё не привязан к мемориалу |
| `assigned` | Покупатель создал мемориал в ЛК |
| `active` | Публичная страница доступна |
| `suspended` | Модерация / неоплата продления (если будет подписка) |

### Что хранить в БД

```sql
qr_codes (
  id              UUID PRIMARY KEY,
  code_slug       VARCHAR(12) UNIQUE,  -- то, что в URL /r/{slug}
  order_id        UUID,
  memorial_id     UUID NULL,          -- NULL пока не активирован
  sequence_num    INT,                -- 1, 2, 3... для реестра в письме
  status          ENUM,
  scan_count      INT DEFAULT 0,
  last_scanned_at TIMESTAMPTZ,
  created_at      TIMESTAMPTZ
)
```

### Генерация

- **В QR-коде (картинка):** URL `https://qr-pamyat.ru/r/{code_slug}` — библиотека `qrcode` на Python или `qrcode.react` на фронте для превью.
- **Электронная отправка:** PNG/PDF с QR + текст «Код №3 из 5».
- **Физическая плашка:** тот же `code_slug` — производитель печатает QR с тем же URL.

### Синхронизация «электронный ↔ физический»

Они **не разные коды** — один `code_slug` на одну плашку. Разница только в доставке:
- Электронно: PDF/PNG на email сразу после оплаты
- Физически: плашка по адресу доставки (логистика — отдельный процесс в админке: `fulfillment_status`)

### Аналитика сканов

На `GET /r/{slug}`:
1. Найти код в БД
2. `scan_count++`, `last_scanned_at = now()`
3. Опционально: IP, User-Agent (без персональных данных — GDPR/152-ФЗ)
4. Redirect 302

---

## 5. Хранение фото и видео (Yandex Object Storage)

### Почему Object Storage, а не диск сервера

- Памятники = сотни фото + длинные видео на пользователя
- Прямая загрузка на API → сервер станет узким местом
- S3 API — стандарт, локально тестируете на **MinIO**

### Структура бакета

```
qr-pamyat-media/
  memorials/{memorial_id}/
    photos/
      {file_uuid}_original.webp
      {file_uuid}_thumb_400.webp
    videos/
      {file_uuid}_original.mp4
      {file_uuid}_poster.jpg
    grave/
      {file_uuid}_grave.jpg
```

### Поток загрузки (presigned URL)

```
1. Клиент: POST /api/uploads/presign
   { memorial_id, filename, content_type, size_bytes }

2. API проверяет:
   - авторизация
   - лимит пакета (фото/минуты)
   - MIME и размер

3. API возвращает:
   { upload_url, file_key, expires_in: 300 }

4. Клиент: PUT напрямую в storage.yandexcloud.net
   (тело файла НЕ идёт через ваш сервер)

5. Клиент: POST /api/uploads/confirm
   { file_key, memorial_id, type: "photo" }

6. API: запись в media_files, постановка задачи на thumbnail
```

### Yandex Cloud настройка

1. Создать бакет в Object Storage (регион `ru-central1`)
2. Бакет **приватный** (не public-read)
3. Сервисный аккаунт с ролью `storage.editor`
4. Статические ключи → в `.env` API
5. CDN → источник: бакет → домен `cdn.qr-pamyat.ru`

```python
# boto3 для Yandex Object Storage
import boto3
from botocore.client import Config

s3 = boto3.client(
    "s3",
    endpoint_url="https://storage.yandexcloud.net",
    aws_access_key_id=settings.YC_ACCESS_KEY,
    aws_secret_access_key=settings.YC_SECRET_KEY,
    config=Config(signature_version="s3v4"),
)

def presign_upload(key: str, content_type: str) -> str:
    return s3.generate_presigned_url(
        "put_object",
        Params={"Bucket": settings.BUCKET, "Key": key, "ContentType": content_type},
        ExpiresIn=300,
    )
```

### Батчевая раздача (ваш вопрос)

**Загрузка:** батч presigned URLs — `POST /api/uploads/presign-batch` (до 20 файлов за раз).

**Отдача:** не батчить байты — отдавайте CDN URL списком:
```json
GET /api/memorials/{id}/media
→ [{ "id", "thumb_url", "full_url", "type", "duration_sec" }]
```
`full_url` — presigned GET на 15 минут или публичный CDN для одобренного контента.

---

## 6. Оптимизация загрузки и рендеринга

### На клиенте (делать сразу в UI-фазе)

| Приём | Детали |
|-------|--------|
| **Компрессия фото** | `browser-image-compression`: max 1920px, WebP, 1–2 MB |
| **Превью до загрузки** | `URL.createObjectURL` → мгновенный thumbnail |
| **Параллельность** | Не более 3–4 одновременных upload (семафор) |
| **Lazy load галереи** | `loading="lazy"`, Intersection Observer |
| **Виртуализация** | `@tanstack/react-virtual` при 100+ фото |
| **Видео metadata** | `<video preload="metadata">` для длительности до upload |
| **Отмена upload** | AbortController |

### На сервере (фаза 2+)

| Приём | Детали |
|-------|--------|
| **Thumbnail worker** | 400px WebP при confirm upload |
| **Multipart upload** | Видео > 100 MB — S3 multipart через presigned parts |
| **CDN cache** | `Cache-Control: public, max-age=31536000` для immutable ключей |
| **Транскодинг** | FFmpeg → HLS 720p/480p (фаза 5, не MVP) |

### Лимиты пакетов — двойная проверка

```typescript
// Фронт: мгновенный UX
const canAddPhoto = photos.length < PACKAGE_LIMITS[pkg].photos;

// Бэк: источник истины
if memorial.photo_count >= package_limit:
    raise HTTP 409
```

Видео: суммируйте `duration_sec` всех файлов, не только количество.

---

## 7. Похожие проекты — что взять

| Проект | Урок |
|--------|------|
| [Remember Well](https://www.thinkbuiltsol.com/qr-code-memorial-case-study-remember-well/) | QR → redirect → профиль; аналитика сканов |
| [Legacy Honored](https://avancerasolution.com/case-studies/legacy-honored/) | E-commerce + физическая плашка + React/Node |
| [Nova Memorial](https://anfinity.bg/case-studies/nova-memorial-digital-memorial-book) | Онбординг, магазин плашек, QR-сканер |
| [Forever Connected](https://foreverconnected.store) | Простой UX: создать страницу за 5 минут |

**Общий паттерн:** покупка → личный кабинет → наполнение → QR связывает физический мир с URL.

---

## 8. Локальная разработка

### docker-compose.yml (минимум)

```yaml
services:
  postgres:
    image: postgres:16
    environment:
      POSTGRES_DB: qr_pamyat
      POSTGRES_USER: app
      POSTGRES_PASSWORD: secret
    ports: ["5432:5432"]

  redis:
    image: redis:7-alpine
    ports: ["6379:6379"]

  minio:
    image: minio/minio
    command: server /data --console-address ":9001"
    ports: ["9000:9000", "9001:9001"]
    environment:
      MINIO_ROOT_USER: minio
      MINIO_ROOT_PASSWORD: minio123

  api:
    build: ./backend
    env_file: .env
    ports: ["8000:8000"]
    depends_on: [postgres, redis, minio]
```

### Переменные `.env` (пример)

```env
DATABASE_URL=postgresql+asyncpg://app:secret@localhost:5432/qr_pamyat
S3_ENDPOINT=http://localhost:9000
S3_BUCKET=qr-pamyat-media
S3_ACCESS_KEY=minio
S3_SECRET_KEY=minio123
YOOKASSA_SHOP_ID=test_shop_id
YOOKASSA_SECRET_KEY=test_secret
JWT_SECRET=change-me-in-production
```

### Тест оплаты без боевого магазина

1. ЮKassa → тестовый магазин → тестовые карты из документации
2. Webhook: `ngrok http 8000` → URL в ЛК ЮKassa
3. СБП в тесте: эмулируется на их стороне

---

## 9. Безопасность и 152-ФЗ

- Пароли: **bcrypt** / **argon2**, не MD5
- Дефолтный пароль `1234` — только для демо; в проде генерировать случайный и слать на email
- Персональные данные усопших — хранить в РФ (Yandex Cloud / Selectel)
- Политика конфиденциальности + согласие на обработку ПДн
- Админ-действия — audit log
- Rate limit: login 5/мин, presign 30/мин

---

## 10. Структура репозитория (целевая)

```
/
├── frontend/          # React + Vite
├── backend/           # FastAPI монолит
│   ├── app/
│   │   ├── api/       # routers
│   │   ├── models/
│   │   ├── services/  # yookassa, s3, qr, email
│   │   └── workers/   # celery tasks
│   └── alembic/
├── docs/              # ТЗ, роадмап, гайды
├── docker-compose.yml
└── .env.example
```

---

## 11. Частые ошибки (избегайте)

1. Загрузка файлов через FastAPI `UploadFile` в проде — убьёт RAM и bandwidth
2. QR с прямым URL мемориала — нельзя менять без перевыпуска плашки
3. Доверие `return_url` без webhook — потерянные заказы
4. Public S3 bucket — утечка всех фото
5. Микросервисы в день 1 — месяцы инфраструктуры вместо продукта
6. Нет 54-ФЗ — штрафы для ИП/ООО

---

## Полезные ссылки

- [ЮKassa API](https://yookassa.ru/developers)
- [СБП через ЮKassa](https://yookassa.ru/developers/payment-acceptance/integration-scenarios/manual-integration/other/sbp)
- [Чеки 54-ФЗ ЮKassa](https://yookassa.ru/developers/payment-acceptance/receipts/54fz/yoomoney/basics)
- [Yandex Object Storage S3 API](https://yandex.cloud/ru/docs/storage/s3/)
- [FastAPI Full Stack Template](https://github.com/fastapi/full-stack-fastapi-template)
- [Загрузка в S3 presigned (статья)](https://statuser.cloud/blog/kak-realizovat-zagruzku-i-hranenie-faylov-v-s3-sovmestimyh-hranilishchah)
