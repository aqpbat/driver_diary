# Дневник смен водителя

Тестовое задание: сервер отдаёт поездки водителя и сводку за день, клиент показывает сводку и список поездок, переключает дни и добавляет поездки.

**Состояние:** готовы сервер (домен, хранилище на PostgreSQL, HTTP API, Docker-образ) и клиент на Flutter (Android, iOS, Web) — всё с тестами. API развёрнут на Railway: https://api-production-ab4d.up.railway.app (например, [`/api/v1/days`](https://api-production-ab4d.up.railway.app/api/v1/days)). Впереди — демо-сборка клиента и CI; план и чеклист — в [PLAN.md](PLAN.md).

## Запуск сервера

Всё в Docker (нужен только Docker):

```sh
docker compose up --build     # PostgreSQL + API на http://localhost:8080
docker compose down -v        # остановить и сбросить базу к начальным данным
```

Добавленные поездки лежат в томе `pgdata` и переживают `docker compose restart` и пересборку образа. Начальные данные загружаются только в пустую базу.

Без контейнера для API — нужны Go 1.26 и Docker (для PostgreSQL):

```sh
docker compose up -d db
cd api
DATABASE_URL='postgres://diary:diary@localhost:5432/diary?sslmode=disable' go run ./cmd/server
```

Сервер слушает `http://localhost:8080`. При старте он ждёт базу, применяет миграции и, если таблица пуста, загружает начальные данные.

| Переменная | По умолчанию | Назначение |
|---|---|---|
| `DATABASE_URL` | — (обязательна) | адрес PostgreSQL |
| `PORT` | `8080` | порт |
| `APP_TZ` | `Asia/Almaty` | часовой пояс водителя: по нему определяется день поездки |
| `TRIPS_FILE` | `data/trips.json` | начальные данные для пустой базы |
| `CORS_ALLOWED_ORIGINS` | пусто (CORS выключен) | разрешённые источники через запятую или `*` |

## Запуск клиента

Нужен Flutter 3.47.5. Клиент ходит в API по адресу из `API_BASE_URL` (по умолчанию `http://localhost:8080`), поэтому сначала поднимите сервер: `docker compose up --build`.

```sh
cd mobile
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080      # браузер
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080                 # эмулятор Android
flutter run --dart-define=API_BASE_URL=http://localhost:8080                # симулятор iOS
flutter run --dart-define=API_BASE_URL=https://api-production-ab4d.up.railway.app   # сервер на Railway
```

| Параметр `--dart-define` | По умолчанию | Смысл |
|---|---|---|
| `API_BASE_URL` | `http://localhost:8080` | адрес API |
| `DRIVER_UTC_OFFSET` | `+05:00` | смещение часов водителя; должно совпадать с `APP_TZ` сервера. С ним форма отправляет время поездки, по нему считается «сегодня» — часы устройства не используются |

В VS Code то же самое доступно из панели «Run and Debug»: готовые конфигурации запуска лежат в [.vscode/launch.json](.vscode/launch.json) — клиент в Chrome, на эмуляторе Android и симуляторе iOS с локальным API, клиент с сервером на Railway (локальный сервер не нужен) и сам сервер под отладчиком Go.

Открытый HTTP разрешён только для разработки: на Android — в debug-манифесте, на iOS — только к локальной сети (`NSAllowsLocalNetworking`).

Экран компонентов дизайн-системы открывается долгим нажатием на заголовок с датой — только в debug-сборке.

Клиент устроен по Clean Architecture с делением по фичам и `flutter_bloc`, без Material: правила — в [PLAN.md](PLAN.md), раздел 3.1; их соблюдение проверяет `mobile/test/architecture_test.dart`.

## Тесты

```sh
docker compose up -d db
cd api
TEST_DATABASE_URL='postgres://diary:diary@localhost:5432/diary?sslmode=disable' go test -race ./...
go vet ./... && gofmt -l .
```

Тесты хранилища и защиты от дублей идут на настоящем PostgreSQL, каждый — в своей временной схеме, рабочие данные не затрагиваются. Без `TEST_DATABASE_URL` они пропускаются (в CI — падают), остаются только тесты домена.

Клиент:

```sh
cd mobile
flutter analyze
flutter test
```

Тестам клиента сервер не нужен: сеть подменяется на уровне HTTP-клиента, Bloc проверяются с подставными use case'ами.

## Контракт API

Базовый путь `/api/v1`. Все ответы — JSON. Время — RFC 3339 со смещением, в ответах всегда в часовом поясе `APP_TZ` (по умолчанию `Asia/Almaty`, UTC+5). Деньги — целые тенге.

| Метод | Путь | Ответ |
|---|---|---|
| `GET` | `/healthz` | `200 {"status":"ok"}`; база недоступна — `503` |
| `GET` | `/api/v1/days` | `200` — дни, в которых есть поездки, по возрастанию даты |
| `GET` | `/api/v1/days/{date}` | `200` — сводка и поездки за день; день без поездок — `200` с нулями и пустым списком; кривая дата — `400` |
| `POST` | `/api/v1/trips` | `201` — создана; `200` — такая же уже есть (повтор); `409` — `id` занят другой поездкой; `422` — не прошла проверку (в том числе неверный тип или лишнее поле); `400` — не JSON; `413` — тело больше 64 КБ |

### Поездка

```json
{
  "id": "t-1001",
  "start": "2026-10-01T08:10:00+05:00",
  "end": "2026-10-01T08:42:00+05:00",
  "amount": 2400,
  "payment": "card",
  "commission": 360
}
```

Правила:

- `id` — обязателен, непустой, до 64 символов; его создаёт клиент, и он же служит ключом идемпотентности;
- `start`, `end` — RFC 3339 со смещением; `end` позже `start`;
- `amount > 0`; `0 ≤ commission ≤ amount`; оба — целые;
- `payment` — `cash` или `card`;
- неизвестные поля в теле — ошибка; тело не больше 64 КБ.

Поездка относится к дню, на который приходится её **начало** в `APP_TZ`: поездка 23:55–00:20 остаётся в дне начала, а присланная как `20:30Z` попадает на следующий день (01:30 по Алматы).

«Та же поездка» при повторной отправке — совпадают `id`, моменты начала и конца (сравниваются моменты, а не строки: `08:10+05:00` и `03:10Z` — одно и то же), сумма, оплата и комиссия.

### Список дней

```sh
curl http://localhost:8080/api/v1/days
```

```json
{"days": [{"date": "2026-10-01", "trips_count": 6}, {"date": "2026-10-02", "trips_count": 6}]}
```

### День

```sh
curl http://localhost:8080/api/v1/days/2026-10-04
```

```json
{
  "date": "2026-10-04",
  "summary": {
    "trips_count": 4,
    "revenue": 8800,
    "commission": 1320,
    "net": 7480,
    "by_payment": {
      "cash": {"trips_count": 4, "revenue": 8800, "commission": 1320, "net": 7480},
      "card": {"trips_count": 0, "revenue": 0, "commission": 0, "net": 0}
    }
  },
  "trips": [
    {"id": "t-4001", "start": "2026-10-04T09:00:00+05:00", "end": "2026-10-04T09:25:00+05:00", "amount": 1400, "payment": "cash", "commission": 210}
  ]
}
```

`net` («на руки») = `revenue − commission`. Оба ключа `cash` и `card` присутствуют всегда. Поездки отсортированы по началу.

### Добавление поездки

```sh
curl -i -X POST http://localhost:8080/api/v1/trips \
  -H 'Content-Type: application/json' \
  -d '{"id":"7c1e0f5a-3b52-4a55-9d0e-2f6f3f0a9b11","start":"2026-10-04T20:00:00+05:00","end":"2026-10-04T20:30:00+05:00","amount":2000,"payment":"card","commission":300}'
```

Первый вызов — `201`, повтор той же командой — `200` (ничего не записывается), тот же `id` с другой суммой — `409`. В ответе `201` и `200` — сохранённая поездка.

### Ошибки

Единый формат для всех ошибок; `fields` есть только у ошибок проверки (`422`) и перечисляет все проблемные поля сразу:

```json
{"error": {"code": "validation_failed", "message": "trip is invalid", "fields": {"end": "must be after start", "amount": "must be greater than 0"}}}
```

Коды ошибок: `validation_failed` (422), `id_conflict` (409), `invalid_json` (400), `invalid_date` (400), `body_too_large` (413), `not_found` (404), `method_not_allowed` (405), `database_unavailable` (503), `internal` (500).

## Начальные данные

[api/data/trips.json](api/data/trips.json) — 22 поездки за 1, 2, 4 и 5 октября 2026 (3 октября намеренно пусто). Они загружаются в базу один раз, когда таблица `trips` пуста; добавленные через API поездки хранятся в PostgreSQL и переживают перезапуск. Вернуться к начальным данным — `docker compose down -v`.
