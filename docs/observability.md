# Наблюдаемость и мониторинг (Observability & SRE)

## Архитектура мониторинга
Стек базируется на `kube-prometheus-stack` с автоматическим провижинингом ресурсов:
1. **Prometheus Operator & Scrape:** Приложение отдает RED-метрики на `/metrics`. Скрейпинг настраивается через `PodMonitor`.
2. **Фоновая синтетическая нагрузка:** Деплоймент `loadgen` генерирует непрерывный поток запросов ~10 RPS, обеспечивая наполнение гистограмм и счетчиков Prometheus даже при отсутствии внешних пользователей.
3. **Автоматический импорт дашборда:** Файл `files/dashboard.json` упакован в ConfigMap с аннотацией `grafana_dashboard: "1"`, что активирует sidecar Grafana для мгновенной загрузки дашборда без необходимости авторизации или ручного импорта.

---

## Панели RED Dashboard (`demo-api-slo`)
1. **Rate:** `sum(rate(http_requests_total[1m])) by (status)` — RPS с разбивкой по HTTP кодам (200, 401, 500).
2. **Errors:** `sum(rate(http_requests_total{status=~"5.."}[1m])) / sum(rate(http_requests_total[1m]))` — соотношение 5xx ошибок.
3. **Duration:** Квантили задержки `p50`, `p95`, `p99` по гистограмме `http_request_duration_seconds`.
4. **Traffic Split:** График распределения запросов между Stable и Canary подами.
5. **Replicas Health:** Количество здоровых реплик сервиса.

---

## Настроенные алерты PrometheusRule
- `DemoApiDown`: критический алерт при отсутствии живых подов в течение 1 минуты.
- `DemoApiHighErrorRate`: критический алерт при доле 5xx ошибок более 5% в течение 1 минуты.
- `DemoApiHighLatencyP95`: предупреждающий алерт при p95 задержке свыше 500 мс.
- `DemoApiRolloutDegraded`: алерт о сбое в канареечном треке, активирующий автооткат.
