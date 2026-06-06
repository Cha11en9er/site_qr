# DBeaver — пошаговая инструкция

Основной способ работы с БД на этапе разработки. **psql не нужен** до деплоя на сервер.

---

## 1. Подключение к PostgreSQL

1. DBeaver → **Database** → **New Database Connection** → **PostgreSQL**
2. Заполните:
   - Host: `localhost` (или IP сервера)
   - Port: `5432`
   - Database: `postgres` (для первого шага)
   - Username: `postgres`
   - Password: ваш пароль
3. **Test Connection** → **Finish**

---

## 2. Создать базу `qr_pamyat`

1. В **Database Navigator** раскройте подключение → **Databases**
2. ПКМ → **Create** → **Database**
3. Name: `qr_pamyat`, Encoding: `UTF8` → **OK**

---

## 3. Создать роль `qr_app`

1. Откройте файл `db/scripts/00_database.sql` в DBeaver  
   (File → Open File, или перетащите из проводника)
2. Убедитесь, что вверху активно подключение к **`postgres`**
3. Измените пароль в строке `PASSWORD 'CHANGE_ME...'`
4. Выделите блок `DO $$ ... $$` и `GRANT` → **Alt+Enter**

---

## 4. Создать таблицы

1. Создайте **второе подключение** (или смените Database на `qr_pamyat`):
   - Database: `qr_pamyat`
   - User: `postgres` (или `qr_app`)
2. Откройте **`db/scripts/00_full_schema.sql`**
3. **Alt+X** — Execute SQL Script (выполнит весь файл)
4. В панели **Log** не должно быть ошибок

### Альтернатива — по файлам

Если удобнее по шагам, выполняйте по порядку (каждый — Alt+X):

```
01_extensions.sql
02_lookups.sql
03_users_auth.sql
04_orders.sql
05_payments.sql
06_qr_codes.sql
07_memorials.sql
08_media.sql
09_reviews.sql
10_system.sql
11_functions_triggers.sql
12_seed.sql
13_grants.sql
```

---

## 5. Проверка

Подключены к `qr_pamyat` → **SQL Editor** → вставьте и выполните:

```sql
SELECT count(*) AS packages FROM package_types;    -- ожидается 3
SELECT count(*) AS tables FROM information_schema.tables
WHERE table_schema = 'public';                     -- ожидается ~25
```

В **Database Navigator** → qr_pamyat → Schemas → public → Tables — список таблиц.

---

## 6. Сброс (только dev)

Файл `db/scripts/99_drop_all.sql` → подключение к `qr_pamyat` → **Alt+X**.

---

## Горячие клавиши DBeaver

| Действие | Клавиши |
|----------|---------|
| Выполнить выделенный фрагмент | **Alt+Enter** |
| Выполнить весь скрипт | **Alt+X** |
| Форматировать SQL | **Ctrl+Shift+F** |

---

## Импорт файлов из проекта

**Способ 1:** File → Open File → выбрать `.sql` из `db/scripts/`

**Способ 2:** Скопировать содержимое файла в SQL Editor

**Способ 3:** В проекте DBeaver добавить папку `db/scripts` как bookmark

---

## psql — только при деплое (опционально)

На VPS, если нет GUI, тот же результат:

```bash
psql -U postgres -d qr_pamyat -f db/scripts/00_full_schema.sql
```

Скрипт `deploy/apply_schema.ps1` — обёртка для Windows-сервера.
