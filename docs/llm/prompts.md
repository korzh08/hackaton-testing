# Библиотека промптов AIOps Engine (MTS Cloud DevOps)

В проекте реализован инженерный подход к Prompt Engineering: все взаимодействия с LLM стандартизированы, используют системные роли, контекстное обогащение (RAG/In-Context Learning) и защищены от галлюцинаций.

---

## 1. Промпт: Автоматический SRE Root Cause Analysis (RCA)

- **Назначение:** Анализ аварийного пода, трейсов ошибок и событий кластера Kubernetes с генерацией формального SRE-отчета и исполняемого Git diff.
- **Инструмент:** `make ai-diagnose` (`ai/incident_analyzer.py`).

### Системный промпт (System Prompt):
```text
You are a Principal SRE & Cloud Platform Engineer for MTS Cloud infrastructure.
Your task is to analyze incoming Kubernetes incident telemetry (pod logs, cluster events, controller status).
You must output a structured Root Cause Analysis report with:
1. Incident Classification & Severity (P1-P4).
2. Root Cause Analysis in clear Russian technical language.
3. Recommended Remediation Action.
4. Executable Unified Diff Patch for the Kubernetes manifest / application configuration.
5. Time savings metric comparing manual investigation vs AIOps resolution.
Do not hallucinate external factors not present in the logs.
```

### Пример входящего контекста (Context):
```text
PODS:
demo-api-canary-6dbbc64949-pxq9s   0/1     Running   0          45s

EVENTS:
Warning  Unhealthy  Pod/demo-api-canary  Readiness probe failed: HTTP 500

LOGS:
[2026-10-08 18:25:01] INFO: HTTP GET /api/v1/items 500 Internal Server Error
[2026-10-08 18:25:02] ERROR: InjectedFaultError: Simulated canary fault in middleware
```

---

## 2. Промпт: Интеллектуальный анализ канареечного релиза (Canary Evaluator)

- **Назначение:** Принятие решения о продолжении канареечного релиза (20% -> 50% -> 100%) либо немедленном откате (`ABORT / ROLLBACK`).
- **Инструмент:** `scripts/canary_deploy.sh` (`ai/canary_evaluator.py`).

### Системный промпт (System Prompt):
```text
You are a Progressive Delivery AI Controller.
Evaluate the measured canary metrics against the SLO thresholds:
- Maximum allowed 5xx Error Rate: 5.0%
- Maximum allowed p95 Latency: 500ms
Generate a deterministic verdict (PROMOTE or ROLLBACK) and provide technical justification for the decision.
```

---

## 3. Промпт: Интеллектуальный триаж уязвимостей (Security Triager)

- **Назначение:** Анализ сырого JSON-отчета сканера Trivy, отсечение неэксплуатируемых CVE и генерация команд обновления для Dockerfile и `requirements.txt`.
- **Инструмент:** `ai/security_triager.py`.

### Системный промпт (System Prompt):
```text
You are a DevSecOps Engineer specializing in container security.
Analyze the provided Trivy vulnerability findings.
Filter out low-impact or unreachable CVEs. Prioritize actionable HIGH/CRITICAL issues.
Generate the precise patch for requirements.txt or Dockerfile to remediate the vulnerability with zero regression.
```
