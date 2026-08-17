# TicketFlow

Высоконагруженный сервис бронирования билетов на мероприятия. Гибридная архитектура: **Rails** (full-stack) как фронтенд и агрегатор, **Go микросервисы** для обработки транзакций и бронирований.

Проект решает три классические проблемы highload-систем бронирования:

1. **Overbooking** — избегаем избыточного бронирования, когда несколько пользователей одновременно пытаются купить последний билет.
2. **Zombie Reservations** — предотвращаем "мёртвые" бронирования, когда пользователь зарезервировал место, но не оплатил его, блокируя инвентарь.
3. **Thundering Herd** — защищаем систему от лавинообразного трафика в момент открытия продаж популярного мероприятия.

## Архитектура

Система разделена на три Go-микросервиса и Rails-приложение, объединённые в mono-repo:

| Компонент | Стек | Ответственность |
|---|---|---|
| **TicketFlow Web** | Rails 8.1+ (full-stack, Hotwire, Slim, Solid *) | Фронтенд, CRUD мероприятий, пользователи, админка (Avo), отчёты |
| **Waiting Room Service** | Go 1.26+ | Rate limiting, очередь, backpressure, WebSocket для статуса |
| **Booking Service** | Go 1.26+ | Атомарное бронирование, overbooking protection, zombie cleanup |
| **Payment Service** | Go 1.26+ | Асинхронная обработка платежей через Kafka, webhook-и от Stripe |

**Потоки данных:**
- Rails ↔ Go сервисы: **gRPC** (синхронные вызовы)
- Go ↔ Go: **Kafka** (асинхронные события)
- Rails ← Kafka: потребляет события от Go сервисов (например, `payment.completed`)

**База данных:** PostgreSQL 16, shared DB с отдельными схемами (`public` для Rails, `booking`, `waiting_room`, `payment` для Go-сервисов).

## Стек технологий

### Rails

| Технология | Назначение | Почему выбрана |
|---|---|---|
| Rails 8.1+ | Основной фреймворк | Быстрая разработка, современные дефолты |
| Hotwire/Turbo | Интерактивность | Современный UX без React, server-driven rendering |
| Slim | Шаблонизатор views | Чище ERB, быстрее Haml, отлично работает с Hotwire |
| PostgreSQL | Персистентность (schema `public`) | Надёжность, транзакции, JSONB |
| Solid Queue / Cache / Cable | Фоновые задачи, кэш, WebSockets | Rails 8 дефолт: всё в PostgreSQL, меньше зависимостей |
| Devise + JWT | Аутентификация | Стандарт индустрии, гибкость |
| Avo | Админка | Современная, на Hotwire, быстро настраивается |
| Ransack | Поиск/фильтрация | Декларативные фильтры без написания SQL |
| Pagy | Пагинация | Быстрее kaminari, меньше нагрузки на БД |
| RSpec + FactoryBot | Тесты | Стандарт Ruby-экосистемы |

### Go

| Технология | Назначение | Почему выбрана |
|---|---|---|
| Go 1.26+ | Микросервисы | Конкурентность (goroutines), низкая латентность |
| gRPC + Protobuf | Rails ↔ Go коммуникация | Строгая типизация контрактов, бинарный протокол, быстрее REST |
| PostgreSQL | Персистентность (per-service schemas) | Row-level locking, `FOR UPDATE SKIP LOCKED` |
| Redis | Rate limiting, waiting room | Атомарные операции, TTL, streams (только для Go-сервисов) |
| Kafka | Event bus | Backpressure, replay, аудит, decoupling сервисов |
| Prometheus | Метрики | Стандарт observability, интеграция с Grafana |
| OpenTelemetry | Трейсинг | End-to-end tracing через Rails + Go + Kafka |

### Инфраструктура

| Технология | Назначение |
|---|---|
| PostgreSQL 16 | Основная БД (shared DB, separate schemas) |
| Redis 7.2 | Rate limiting, waiting room (только для Go-сервисов) |
| Kafka 3.7 (KRaft) | Event bus без Zookeeper |
| Docker Compose | Локальная разработка |
| Makefile | Автоматизация (up, down, migrate, test, help) |
| golang-migrate | Миграции БД per schema |
| Kafka UI | Отладка событий |
| Prometheus + Grafana | Мониторинг |

## Ключевые архитектурные решения

**Overbooking protection** (Booking Service):

```sql
UPDATE events SET available_seats = available_seats - 1
WHERE id = $1 AND available_seats > 0
RETURNING id
```

Атомарное обновление на уровне СУБД без распределённых блокировок.

**Zombie cleanup** (Booking Service):
Фоновый воркер использует `FOR UPDATE SKIP LOCKED` для безопасного удаления просроченных бронирований без блокировки активных транзакций.

**Waiting room** (Waiting Room Service):
Redis Streams + backpressure перед Booking Service. Пропускает в PostgreSQL только контролируемый поток запросов.

**Event-driven архитектура:**
Kafka для асинхронной обработки платежей, аудита и синхронизации между сервисами.

## Требования к локальной среде

| Инструмент | Версия |
|---|---|
| Ruby | 3.2+ |
| Rails | 8.1+ |
| Go | 1.26+ |
| PostgreSQL client | 16+ |
| Redis CLI | 7+ |
| protoc | 35+ |
| protoc-gen-go | v1.36+ |
| protoc-gen-go-grpc | 1.6+ |
| Docker | 28+ |
| Docker Compose | 2.34+ |
| Node.js | 18+ |
| Yarn | 1.22+ |
| Make | 3.81+ |

## Локальный запуск

```bash
git clone https://github.com/TaranyukK/ticketflow.git
cd ticketflow

# Список доступных команд
make help

# Поднять всю инфраструктуру
make up

# Установить зависимости
make setup

# Инициализировать БД
make migrate

# Запустить Rails
make run-rails

# Запустить Go-сервисы (в отдельных терминалах)
make run-booking
make run-waiting-room
make run-payment
```

Открыть:
- Rails: http://localhost:3000
- Kafka UI: http://localhost:8080
- Grafana: http://localhost:3001

## API и сценарии использования

### Сценарий 1: Продажа популярного концерта

1. Админ создаёт мероприятие через Rails-админку (Avo)
2. В момент открытия продаж 10,000 пользователей заходят на сайт
3. **Waiting Room Service** ставит их в очередь, пропускает по 100 RPS в Booking Service
4. **Booking Service** атомарно резервирует места, публикует `booking.created` в Kafka
5. **Payment Service** потребляет событие, инициирует платёж через Stripe
6. После успешной оплаты публикует `payment.completed`
7. **Rails** потребляет событие и обновляет статус для пользователя через WebSocket

### Сценарий 2: Zombie cleanup

1. Пользователь зарезервировал билет, но закрыл вкладку
2. Через 10 минут `expires_at` истекает
3. Фоновый воркер Booking Service находит просроченные записи через `FOR UPDATE SKIP LOCKED`
4. Статус меняется на `EXPIRED`, `available_seats` инкрементируется

## Структура репозитория

```
ticketflow/
├── README.md
├── CONTEXT.md
├── docker-compose.yml
├── Makefile
├── .env
├── .gitignore
├── web/                          # Rails 8.1
├── services/
│   ├── booking/                  # Go 1.26
│   ├── waiting-room/             # Go 1.26
│   └── payment/                  # Go 1.26
├── proto/                        # Общие gRPC контракты
├── migrations/                   # Миграции БД per schema
└── infra/
    ├── postgres/
    │   └── init.sql
    ├── kafka/
    ├── prometheus/
    └── grafana/
```

## Roadmap

- [x] Docker Compose с полной инфраструктурой
- [x] Инициализация Rails приложения
- [x] Инициализация Go-сервисов
- [x] Makefile с help и автоматизацией
- [ ] gRPC контракты между Rails и Go
- [ ] Миграции БД для Go-сервисов (golang-migrate)
- [ ] Kafka топики и consumers
- [ ] Prometheus + Grafana дашборды
- [ ] OpenTelemetry tracing
- [ ] Load testing (k6)
- [ ] CI/CD pipeline (GitHub Actions)