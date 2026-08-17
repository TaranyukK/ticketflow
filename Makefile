.PHONY: help up down setup migrate migrate-all run-rails run-booking run-waiting-room run-payment test lint

help:
	@echo "Доступные команды:"
	@echo "  make up               - Поднять инфраструктуру (PostgreSQL, Redis, Kafka)"
	@echo "  make down             - Остановить инфраструктуру"
	@echo "  make setup            - Установить зависимости (bundle install, go mod tidy)"
	@echo "  make migrate          - Миграции только для Rails"
	@echo "  make migrate-all      - Миграции для Rails и Go-сервисов"
	@echo "  make run-rails        - Запустить Rails сервер"
	@echo "  make run-booking      - Запустить Booking Service"
	@echo "  make run-waiting-room - Запустить Waiting Room Service"
	@echo "  make run-payment      - Запустить Payment Service"
	@echo "  make test             - Запустить тесты (RSpec + Go)"
	@echo "  make lint             - Запустить линтеры (Rubocop + golangci-lint)"

up:
	docker compose up -d

down:
	docker compose down

setup:
	cd web && bundle install
	cd services/booking && go mod tidy
	cd services/waiting-room && go mod tidy
	cd services/payment && go mod tidy

migrate:
	cd web && bin/rails db:create db:migrate

migrate-all: migrate
	@echo "Запуск миграций Go-сервисов (пример)..."
	@echo "Здесь будут команды golang-migrate для схем booking, waiting_room, payment"

run-rails:
	cd web && bin/rails server

run-booking:
	cd services/booking && go run cmd/main.go

run-waiting-room:
	cd services/waiting-room && go run cmd/main.go

run-payment:
	cd services/payment && go run cmd/main.go

test:
	cd web && bundle exec rspec
	cd services/booking && go test ./...
	cd services/waiting-room && go test ./...
	cd services/payment && go test ./...

lint:
	cd web && bundle exec rubocop
	cd services/booking && golangci-lint run
	cd services/waiting-room && golangci-lint run
	cd services/payment && golangci-lint run