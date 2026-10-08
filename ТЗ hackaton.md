Обязательный шаблон README.md  
Название кейса  
Описание проблемы  
Цель работы  
Состав команды (роли, опыт и навыки участников)  
Архитектура / схема (картинка или diagrams-as-code)  
Использованные инструменты (Terraform 1.5, GitHub Actions/GitLab CI, k3s v1.28 и т.д.)  
Как запустить: git clone … ; make up (один скрипт поднимает всё)  
Мониторинг и наблюдаемость; Безопасность; Использование LLM; Troubleshooting;  Лицензия (по необходимости)

8\. Кейс

Кейс . «Облачный DevOps-конвейер: от репозитория до production-Kubernetes за 3 команды»  
Описание (подробное)  
Команде предлагается построить сквозной путь доставки типового микросервисного приложения (демо REST API на Python/Go) в кластер Kubernetes, воспроизводя стек облачной платформы МТС (Openstack \+ Kubernetes на opensource). Необходимо:  
1\. Инфраструктура как код: Terraform/Ansible — развернуть ВМ/инстанс (локальный VirtualBox/KVM или облако), поднять кластер k3s/minikube (или Managed K8s), настроить сеть (netplan, cloud-init).  
2\. CI: автоматическая сборка Docker-образа, unit-тесты, линт, сканирование образа (Trivy), публикация в registry — по push.  
3\. CD: деплой в Kubernetes через Helm/Kustomize, стратегия blue-green или canary через ingress/nginx, автоматический откат при неудачном релизе.  
4\. Безопасность: секреты вне репозитория (SOPS / Sealed Secrets / HashiCorp Vault), описан процесс ротации.  
5\. Наблюдаемость (совместно с SRE): Prometheus \+ Grafana, минимум 1 дашборд и 1 алерт на здоровье сервиса.  
6\. LLM (опционально, приветствуется): генерация манифестов/конфигов или документации с фиксацией промтов и экономии времени.  
Ожидаемый результат: git-репозиторий с полным решением, где «git clone … && make up» (или terraform apply / helm install) поднимает всё не более чем за 3 команды; README по шаблону п. 7; видео-демо ≤ 5 минут (развёртывание и демонстрация работы).

Сложность  
Средний. Рекомендуемый стек: Git, GitLab CI/GitHub Actions, Docker, Kubernetes (k3s/Managed), Helm/Kustomize, Terraform/Ansible, Trivy, SOPS/Sealed Secrets/Vault, Prometheus/Grafana; Linux Ubuntu/Debian/Astra Linux; Python (Go) для demo-сервиса.  
