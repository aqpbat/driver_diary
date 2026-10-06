# Дневник смен водителя

Тестовое задание: сервер отдаёт поездки водителя и сводку за день, клиент показывает сводку и список поездок, переключает дни и добавляет поездки.

**Состояние:** готовы сервер (домен, хранилище на PostgreSQL, HTTP API, Docker-образ) и клиент на Flutter (Android, iOS, Web) — всё с тестами. API развёрнут на Railway: https://api-production-ab4d.up.railway.app (например, [`/api/v1/days`](https://api-production-ab4d.up.railway.app/api/v1/days)). Попробовать без установки чего-либо — раздел [«Посмотреть без установки»](#посмотреть-без-установки). Впереди — CI; план и чеклист — в [PLAN.md](PLAN.md).

## Как это выглядит

| День со сводкой | Пустой день | Новая поездка | Ошибки в форме |
|---|---|---|---|
| <img src="docs/screenshots/day-light.png" width="230" alt="День: сумма на руки, выручка, комиссия, разбивка на наличные и карту, список поездок"> | <img src="docs/screenshots/empty-light.png" width="230" alt="День без поездок"> | <img src="docs/screenshots/form-light.png" width="230" alt="Форма добавления поездки"> | <img src="docs/screenshots/form-invalid-light.png" width="230" alt="Форма с ошибками проверки у полей"> |
| <img src="docs/screenshots/day-dark.png" width="230" alt="День со сводкой, тёмная тема"> | <img src="docs/screenshots/empty-dark.png" width="230" alt="День без поездок, тёмная тема"> | <img src="docs/screenshots/form-dark.png" width="230" alt="Форма добавления поездки, тёмная тема"> | <img src="docs/screenshots/form-invalid-dark.png" width="230" alt="Форма с ошибками проверки, тёмная тема"> |

| Загрузка | Нет связи | Повтор отправки |
|---|---|---|
| <img src="docs/screenshots/loading-light.png" width="230" alt="Скелетон на время загрузки дня"> | <img src="docs/screenshots/error-light.png" width="230" alt="Ошибка сети с кнопкой «Повторить»"> | <img src="docs/screenshots/form-retry-light.png" width="230" alt="Форма после ошибки сети: повтор не создаст дубль"> |
| <img src="docs/screenshots/loading-dark.png" width="230" alt="Скелетон, тёмная тема"> | <img src="docs/screenshots/error-dark.png" width="230" alt="Ошибка сети, тёмная тема"> | <img src="docs/screenshots/form-retry-dark.png" width="230" alt="Повтор отправки, тёмная тема"> |

Тема выбирается по настройке системы. Скриншоты — настоящие экраны приложения с данными, которые сервер отдаёт за 5 октября из начального набора; они пересоздаются командой `flutter test --update-goldens tool/screenshots_test.dart` из каталога `mobile/`.

## Посмотреть без установки

Не нужны ни Flutter, ни Go, ни Docker: в репозитории лежит уже собранный веб-клиент, а сервер работает на Railway. Нужны только браузер и интернет.

1. Скачайте репозиторий: на странице GitHub кнопка **Code → Download ZIP**, затем распакуйте архив.
2. В папке `demo` запустите один файл:
   - **macOS** — двойной щелчок по `start.command`;
   - **Windows** — двойной щелчок по `start.bat`;
   - **Linux** — `sh demo/start.command` в терминале.
3. Откроется Chrome (или браузер по умолчанию) с приложением. Чтобы остановить, закройте окно со скриптом.

Если macOS не даёт открыть `start.command` («не удалось проверить разработчика»): щёлкните по файлу правой кнопкой → «Открыть», либо разрешите запуск в «Системные настройки → Конфиденциальность и безопасность». Запасной путь — перетащить файл в окно «Терминала», дописав перед ним `sh `, и нажать Enter.

Что делает файл: поднимает на вашем компьютере маленький веб-сервер, который отдаёт папку `demo/web` по адресу `http://localhost:8765`, и открывает этот адрес. Наружу он недоступен, ничего не устанавливает и не меняет. На macOS и Linux используется встроенный Python 3 или Ruby, на Windows — встроенный PowerShell.

Данные общие: поездка, добавленная в демо, сохраняется в базе на Railway, и её увидят все, кто откроет демо после вас.

## Быстрый старт для разработчика

Сервер и база поднимаются локально в Docker, клиент запускается в отладке на симуляторе.

Понадобятся: Docker, Flutter 3.47.5, Xcode с симулятором iOS (или Android Studio с эмулятором) и VS Code с расширением Flutter.

1. Склонируйте репозиторий и поднимите сервер с базой:

   ```sh
   git clone https://github.com/aqpbat/driver_diary.git
   cd driver_diary
   docker compose up --build -d
   ```

2. Убедитесь, что сервер отвечает. Порты заданы в [docker-compose.yml](docker-compose.yml), их же показывает `docker compose ps`:

   | Сервис | Адрес на вашей машине | Зачем |
   |---|---|---|
   | `api` | `http://localhost:8080` | сюда ходит клиент |
   | `db` | `127.0.0.1:5432`, база, пользователь и пароль — `diary` | посмотреть данные, запустить тесты хранилища |

   ```sh
   curl http://localhost:8080/healthz          # {"status":"ok"}
   curl http://localhost:8080/api/v1/days      # четыре дня из начальных данных
   ```

3. Запустите симулятор и подтяните зависимости клиента:

   ```sh
   open -a Simulator
   cd mobile && flutter pub get
   ```

4. Откройте корень репозитория в VS Code, в панели «Run and Debug» выберите конфигурацию и нажмите F5. Адрес сервера в каждую конфигурацию уже вписан:

   | Где запускаете | Конфигурация в VS Code | Адрес сервера для клиента |
   |---|---|---|
   | симулятор iOS | `iOS (sim) -> local API` | `http://localhost:8080` |
   | эмулятор Android | `Android (emu) -> local API` | `http://10.0.2.2:8080` — так эмулятор видит вашу машину |
   | Chrome | `Chrome -> local API` | `http://localhost:8080` |

   То же из терминала — `flutter run --dart-define=API_BASE_URL=<адрес из таблицы>` в каталоге `mobile/`.

5. Закончив, остановите сервер: `docker compose down`. С ключом `-v` база вернётся к начальным данным.

Подробности — в разделах ниже.

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

В VS Code то же самое доступно из панели «Run and Debug»: готовые конфигурации запуска лежат в [.vscode/launch.json](.vscode/launch.json). Кроме трёх из быстрого старта там есть `Chrome -> Railway` и `Chosen -> Railway` (клиент с развёрнутым сервером, локальный не нужен; вторая — для выбранного устройства, в том числе настоящего телефона) и `API: сервер (Go)` — сервер под отладчиком.

Открытый HTTP разрешён только для разработки: на Android — в debug-манифесте, на iOS — только к локальной сети (`NSAllowsLocalNetworking`).

Экран компонентов дизайн-системы открывается долгим нажатием на заголовок с датой — только в debug-сборке.

Клиент устроен по Clean Architecture с делением по фичам и `flutter_bloc`, без Material: правила — в [PLAN.md](PLAN.md), раздел 3.1; их соблюдение проверяет `mobile/test/architecture_test.dart`.

### Демо-сборка

`demo/web/` — результат `flutter build web` с адресом сервера на Railway, без каталога `canvaskit` (движок отрисовки страница берёт с CDN Google). После изменений в клиенте сборку нужно обновить и закоммитить:

```sh
sh demo/build.sh                                        # сервер на Railway
API_BASE_URL=http://localhost:8080 sh demo/build.sh     # другой сервер
```

Сервер должен разрешать CORS для `http://localhost:8765`–`8769` — с этих адресов открывается демо.

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
