# TicketFlow — Project Context

## Как использовать этот файл
При начале новой сессии вставляй следующий промт:
Привет. Продолжаем pet-проект TicketFlow. Правила:
- Не показывай готовое решение, пока я не попрошу.
- Направляй вопросами и подсказками.
- После каждого шага напоминай обновить CONTEXT.md.

Контекст:
[вставь сюда всё содержимое этого файла]

Продолжай с текущего этапа.

## О проекте
TicketFlow — высоконагруженный сервис бронирования билетов на мероприятия.
Гибридная архитектура: Rails (full-stack) + Go микросервисы.
Решает три проблемы: overbooking, zombie reservations, thundering herd.
Pet-проект для демонстрации перехода от Rails к Go и навыков Senior Engineer.
GitHub: https://github.com/TaranyukK/ticketflow

## Текущий этап
Приложения инициализированы (Rails 8.1 + 3 Go-сервиса на Go 1.26).
Makefile готов с целями: help, up, down, setup, migrate, migrate-all, run-*, test, lint.
Go модули: github.com/TaranyukK/ticketflow/services/{booking,waiting-room,payment}.
Следующий шаг — gRPC контракты (начинаем с Booking Service).

## Архитектура

### Компоненты
| Компонент | Стек | Ответственность |
|---|---|---|
| **TicketFlow Web** | Rails 8.1+ (full-stack, Hotwire, Slim, Solid *) | Фронтенд, CRUD мероприятий, пользователи, админка (Avo), отчёты |
| **Booking Service** | Go 1.26+ | Атомарное бронирование, overbooking protection, zombie cleanup воркер |
| **Waiting Room Service** | Go 1.26+ | Rate limiting, очередь, backpressure, WebSocket для статуса |
| **Payment Service** | Go 1.26+ | Асинхронная обработка платежей через Kafka, webhook-и от Stripe |

### Инфраструктура
- **PostgreSQL 16** (shared DB, separate schemas: `public`, `booking`, `waiting_room`, `payment`)
- **Redis 7.2** (rate limiting, waiting room — только для Go-сервисов)
- **Kafka 3.7** с KRaft mode (event bus между сервисами, без Zookeeper)
- **Kafka UI** для отладки событий

### Коммуникация
- Rails ↔ Go сервисы: **gRPC** (синхронные вызовы)
- Go сервисы ↔ Go сервисы: **Kafka** (асинхронные события)
- Rails ↔ Kafka: потребляет события от Go сервисов (например, `payment.completed`)

### Структура mono-repo
ticketflow/
├── README.md
├── CONTEXT.md
├── docker-compose.yml
├── Makefile
├── .env
├── .gitignore
├── web/ # Rails 8.1
│ ├── app/
│ ├── config/
│ ├── db/
│ ├── Gemfile
│ └── Dockerfile
├── services/
│ ├── booking/ # Go 1.26
│ │ ├── cmd/
│ │ ├── internal/{domain,service,repository,handler}/
│ │ ├── proto/
│ │ ├── go.mod
│ │ └── Dockerfile
│ ├── waiting-room/ # Go 1.26
│ │ ├── cmd/
│ │ ├── internal/{domain,service,repository,handler}/
│ │ ├── proto/
│ │ ├── go.mod
│ │ └── Dockerfile
│ └── payment/ # Go 1.26
│ ├── cmd/
│ ├── internal/{domain,service,repository,handler}/
│ ├── proto/
│ ├── go.mod
│ └── Dockerfile
├── proto/ # Общие gRPC контракты
├── migrations/ # Миграции БД (per schema)
└── infra/
├── postgres/
│ └── init.sql
├── kafka/
├── prometheus/
└── grafana/


## Rails стек
- Rails 8.1+ (full-stack, Hotwire/Turbo)
- Slim (шаблонизатор views)
- PostgreSQL (shared DB, schema `public`)
- Solid Queue / Solid Cache / Solid Cable (фоновые задачи, кэш, ActionCable в PG)
- Devise + JWT (аутентификация)
- Avo (админка)
- Ransack (поиск/фильтрация)
- Pagy (пагинация)
- RSpec + FactoryBot (тесты)

## Go стек
- Go 1.26+
- gRPC + Protocol Buffers
- PostgreSQL (per-service schemas)
- Redis (rate limiting, waiting room)
- Kafka (event bus)
- Prometheus (метрики)
- OpenTelemetry (трейсинг)

## Требования к локальной среде
- Ruby 3.2+
- Rails 8.1+
- Go 1.26+
- PostgreSQL client 16+
- Redis CLI 7+
- protoc 35+
- protoc-gen-go v1.36+
- protoc-gen-go-grpc 1.6+
- Docker 28+
- Docker Compose 2.34+
- Node.js 18+
- Yarn 1.22+
- Make 3.81+

## Ключевые архитектурные решения
**Overbooking**: атомарный `UPDATE events SET available_seats = available_seats - 1 WHERE id = $1 AND available_seats > 0 RETURNING id` (в Booking Service)
**Zombie bookings**: фоновый воркер с `FOR UPDATE SKIP LOCKED` (в Booking Service)
**Waiting room**: Redis List/Stream, backpressure перед Booking Service
**Graceful shutdown**: через context cancellation
**Event-driven**: Kafka для асинхронной обработки платежей и аудита
**Docker**: multi-stage build для Go сервисов, собственный Dockerfile для Rails
**Credentials**: через .env файл (в .gitignore)
**Volumes**: PostgreSQL, Redis, Kafka сохраняют данные между перезапусками
**Kafka KRaft mode**: без Zookeeper, современный стандарт
**Solid * в Rails 8**: Solid Queue/Cache/Cable вместо Redis+Sidekiq, всё в PostgreSQL
**Makefile**: с целью `help`, `.PHONY` для всех целей, `migrate-all` для Rails + Go

## Схема БД (PostgreSQL)

### Schema: public (Rails)
**events**
- id UUID PK
- title VARCHAR(255)
- total_seats INT
- available_seats INT
- sale_starts_at TIMESTAMPTZ
- status VARCHAR(50)
- created_at TIMESTAMPTZ
- updated_at TIMESTAMPTZ

**users**
- id UUID PK
- email VARCHAR(255) UNIQUE
- encrypted_password VARCHAR(255)
- created_at TIMESTAMPTZ
- updated_at TIMESTAMPTZ

### Schema: booking (Booking Service)
**bookings**
- id UUID PK
- event_id UUID FK -> public.events
- user_id UUID FK -> public.users
- status VARCHAR(50) (PENDING, CONFIRMED, EXPIRED, CANCELLED)
- expires_at TIMESTAMPTZ
- created_at TIMESTAMPTZ
- updated_at TIMESTAMPTZ

**Индексы**
- idx_bookings_event_status ON bookings(event_id, status)
- idx_bookings_expires ON bookings(expires_at) WHERE status = 'PENDING'

### Schema: payment (Payment Service)
**payments**
- id UUID PK
- booking_id UUID FK -> booking.bookings
- amount DECIMAL(10,2)
- status VARCHAR(50) (PENDING, COMPLETED, FAILED, REFUNDED)
- stripe_payment_intent_id VARCHAR(255)
- created_at TIMESTAMPTZ
- updated_at TIMESTAMPTZ

## README.md статус
✅ Описание проекта и ключевые технические вызовы
✅ Архитектура и компоненты
✅ Стек технологий с обоснованием (включая Slim и Solid *)
✅ Локальный запуск (через Makefile)
✅ API и сценарии использования
✅ Структура репозитория
✅ Roadmap (с отмеченными выполненными пунктами)
✅ Требования к локальной среде