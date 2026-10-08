.PHONY: all up down status test lint release-good release-bad ai-diagnose ai-canary ai-sec-triage secret-rotate secret-rotate-finish clean help

SHELL := /bin/bash
ROOT_DIR := $(shell pwd)
export PATH := $(ROOT_DIR)/bin:$(PATH)
export PYTHONPATH := $(ROOT_DIR)/ai:$(ROOT_DIR):$(PYTHONPATH)

all: up

## 🚀 Основные команды развертывания (Правило 3 команд)
up: ## Развернуть весь конвейер, секреты, чарты и мониторинг
	@./scripts/up.sh

down: ## Удалить развернутое окружение
	@./scripts/down.sh

status: ## Показать статус подов, сервисов и секретов
	@echo "=== Kubernetes Pods ==="
	@kubectl -n demo get pods -o wide 2>/dev/null || echo "Cluster offline / simulated"
	@echo ""
	@echo "=== Encrypted Secrets ==="
	@ls -la secrets/

## 🧪 Тестирование и качество кода
test: ## Запуск unit-тестов с проверкой покрытия (pytest >= 80%)
	@if [ -d ".venv" ]; then \
		PYTHONPATH=. .venv/bin/pytest app/tests/test_main.py --cov=app --cov-report=term-missing -v; \
	else \
		PYTHONPATH=. pytest app/tests/test_main.py --cov=app --cov-report=term-missing -v; \
	fi

lint: ## Линтинг кода (ruff) и валидация Helm-чарта
	@if [ -d ".venv" ]; then \
		.venv/bin/ruff check app/; \
	else \
		ruff check app/; \
	fi
	@bin/helm lint deploy/helm/demo-api

## 🚦 Canary-релизы и демонстрация автоотката
release-good: ## Запуск успешного канареечного релиза (20% -> 50% -> 100%)
	@./scripts/canary_deploy.sh good

release-bad: ## Запуск сбойного релиза -> Автооткат -> Запуск AIOps RCA
	@./scripts/canary_deploy.sh bad

## 🤖 AIOps & LLM Copilot (Ключевое преимущество)
ai-diagnose: ## Запуск AI SRE Incident Analyzer (RCA + diff-патч сбоя)
	@PYTHONPATH=ai python3 ai/incident_analyzer.py

ai-canary: ## Интеллектуальный анализ аномалий Canary-трафика
	@PYTHONPATH=ai python3 ai/canary_evaluator.py 0.04 420.0

ai-sec-triage: ## Интеллектуальный триаж уязвимостей Trivy и авто-патч
	@PYTHONPATH=ai python3 ai/security_triager.py

## 🔐 Управление секретами и zero-downtime ротация
secret-rotate: ## Фаза 1 ротации токена: режим dual-token (старый и новый токен валидны)
	@./scripts/rotate_secrets.sh

secret-rotate-finish: ## Фаза 2 ротации токена: отзыв старого токена
	@./scripts/rotate_secrets_finish.sh

clean: ## Очистка временных файлов
	@rm -rf .pytest_cache .coverage .state/rendered-manifests.yaml

help: ## Показать справку по всем командам
	@echo "=========================================================================="
	@echo "🛠️  MTS Cloud DevOps Platform — Доступные команды:"
	@echo "=========================================================================="
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'
