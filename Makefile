.PHONY: up down setup migrate run-rails run-booking run-waiting-room run-payment test lint

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