# ================================
# Laravel Docker Skeleton - Makefile
# ================================

.PHONY: help install up down prod logs bash phpstan phpcbf phpunit migrate seed \
        health-check config-clear cache-clear clean test-dev test-prod security lint

help:
	@echo "🐳 Laravel Docker Skeleton - Available Commands"
	@echo ""
	@echo "Development:"
	@echo "  make up              - Start development environment"
	@echo "  make down            - Stop and remove containers"
	@echo "  make logs            - View logs (all services)"
	@echo "  make bash            - SSH into PHP container"
	@echo ""
	@echo "Production:"
	@echo "  make prod-up         - Start production environment"
	@echo "  make prod-down       - Stop production environment"
	@echo "  make prod-logs       - View production logs"
	@echo ""
	@echo "Database:"
	@echo "  make migrate         - Run migrations"
	@echo "  make seed            - Run seeders"
	@echo "  make migrate-fresh   - Reset and migrate database"
	@echo ""
	@echo "Testing:"
	@echo "  make test            - Run PHPUnit tests"
	@echo "  make phpstan         - Static analysis"
	@echo "  make phpcbf          - Code beautifier"
	@echo "  make lint            - All linting"
	@echo ""
	@echo "Utilities:"
	@echo "  make health-check    - Check application health"
	@echo "  make cache-clear     - Clear application cache"
	@echo "  make config-clear    - Clear configuration cache"
	@echo "  make clean           - Clean all artifacts"

# ================================
# DEVELOPMENT
# ================================

install:
	docker compose run --rm php composer install
	docker compose exec php php artisan key:generate
	docker compose exec php php artisan migrate

up:
	@echo "🚀 Starting development environment..."
	docker compose up -d
	@echo "✓ Development environment started"
	@echo "🌐 Access at http://localhost:8080"

down:
	@echo "🛑 Stopping development environment..."
	docker compose down -v

logs:
	docker compose logs -f

logs-php:
	docker compose logs -f php

logs-nginx:
	docker compose logs -f nginx

logs-db:
	docker compose logs -f postgres

bash:
	docker compose exec php bash

tinker:
	docker compose exec php php artisan tinker

# ================================
# PRODUCTION
# ================================

prod-up:
	@echo "🚀 Starting PRODUCTION environment..."
	docker compose -f docker-compose.prod.yml up -d
	@echo "✓ Production environment started"
	@sleep 5
	@echo "Checking health..."
	@curl -s http://localhost/health/live || echo "⚠️ Health check endpoint not ready"

prod-down:
	@echo "🛑 Stopping PRODUCTION environment..."
	docker compose -f docker-compose.prod.yml down

prod-logs:
	docker compose -f docker-compose.prod.yml logs -f

prod-bash:
	docker compose -f docker-compose.prod.yml exec php bash

# ================================
# DATABASE
# ================================

migrate:
	@echo "📦 Running migrations..."
	docker compose exec php php artisan migrate

migrate-fresh:
	@echo "🔄 Resetting and migrating database..."
	docker compose exec php php artisan migrate:fresh --seed

seed:
	@echo "🌱 Seeding database..."
	docker compose exec php php artisan db:seed

migrate-prod:
	@echo "📦 Running migrations (PRODUCTION)..."
	docker compose -f docker-compose.prod.yml exec php php artisan migrate --force

# ================================
# TESTING
# ================================

test:
	@echo "🧪 Running tests..."
	docker compose exec php vendor/bin/phpunit

test-coverage:
	@echo "📊 Running tests with coverage..."
	docker compose exec php vendor/bin/phpunit --coverage-html=coverage

phpstan:
	@echo "🔍 Running PHPStan (static analysis)..."
	docker compose exec php vendor/bin/phpstan analyse

phpcbf:
	@echo "✨ Running PHP Code Beautifier..."
	docker compose exec php vendor/bin/phpcbf

phpcs:
	@echo "📋 Running PHPCS (code style)..."
	docker compose exec php vendor/bin/phpcs

lint: phpstan phpcs test
	@echo "✓ All linting passed"

# ================================
# UTILITIES
# ================================

health-check:
	@echo "🏥 Health Status:"
	@echo ""
	@echo "Liveness:"
	@curl -s http://localhost:8080/health/live
	@echo ""
	@echo ""
	@echo "Readiness:"
	@curl -s http://localhost:8080/health/ready | jq '.'
	@echo ""
	@echo "Report:"
	@curl -s -H "X-Health-Token: dev-token" http://localhost:8080/health/report | jq '.'

cache-clear:
	@echo "🗑️  Clearing cache..."
	docker compose exec php php artisan cache:clear
	@echo "✓ Cache cleared"

config-clear:
	@echo "🗑️  Clearing config cache..."
	docker compose exec php php artisan config:clear
	@echo "✓ Config cache cleared"

optimize:
	@echo "⚡ Optimizing application..."
	docker compose exec php php artisan optimize
	@echo "✓ Application optimized"

clean:
	@echo "🧹 Cleaning artifacts..."
	docker compose exec php rm -rf bootstrap/cache/*
	docker compose exec php rm -rf storage/logs/*
	docker compose exec php rm -rf storage/framework/cache/*
	docker compose exec php rm -rf vendor
	docker compose exec php rm -rf node_modules
	@echo "✓ Artifacts cleaned"

# ================================
# BUILD
# ================================

build:
	@echo "🔨 Building images..."
	docker compose build --no-cache

build-prod:
	@echo "🔨 Building production images..."
	docker build -f docker/php/Dockerfile --build-arg ENV=production -t laravel:prod .
	docker build -f docker/nginx/Dockerfile --build-arg ENV=production -t laravel-nginx:prod .

# ================================
# DATABASE TOOLS
# ================================

db-connect:
	docker compose exec postgres psql -U laravel -d laravel

db-dump:
	@echo "📤 Dumping database..."
	docker compose exec postgres pg_dump -U laravel -d laravel > database_dump_$$(date +%Y%m%d_%H%M%S).sql

db-restore:
	@echo "📥 Restoring database from dump..."
	@if [ -z "$(FILE)" ]; then echo "Usage: make db-restore FILE=dump.sql"; else \
		docker compose exec -T postgres psql -U laravel -d laravel < $(FILE); \
	fi

# ================================
# ENVIRONMENT
# ================================

env-init:
	@echo "🔧 Initializing environment..."
	cp .env.docker.example .env.docker
	@echo "✓ .env.docker created"
	@echo "⚠️  Remember to set secure values for:"
	@echo "   - POSTGRES_PASSWORD"
	@echo "   - REDIS_PASSWORD"
	@echo "   - APP_KEY"

env-prod-init:
	@echo "🔧 Initializing production environment..."
	cp .env.docker.prod .env.docker.prod.local
	@echo "✓ .env.docker.prod.local created"
	@echo "⚠️  DO NOT VERSION .env.docker.prod.local!"
	@echo "⚠️  Set from CI/CD secrets in production"

# ================================
# QUICK COMMANDS
# ================================

dev: up migrate
	@echo "✓ Development environment ready"

refresh: down build up migrate
	@echo "✓ Environment refreshed"

restart:
	@echo "🔄 Restarting services..."
	docker compose restart
	@echo "✓ Services restarted"

status:
	@echo "📊 Container Status:"
	docker compose ps
	@echo ""
	docker compose ps -a

