# cloud-platform-lab

> **Portfolio project** — End-to-end GKE platform engineering lab demonstrating production-grade Kubernetes, observability, security scanning, and IaC practices for an ESG Cloud Architect role.

---

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        GitHub Actions CI                        │
│  git push → WIF auth → docker build → Trivy scan → AR push    │
│                       → Terraform plan                          │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│              GKE Autopilot (us-east1)                           │
│                                                                 │
│  ┌─────────────────┐    ┌──────────────────────────────────┐   │
│  │   Flask App     │    │     Observability Stack          │   │
│  │  /healthz       │    │  ┌──────────┐  ┌─────────────┐  │   │
│  │  /load (HPA)    │◄───┤  │Prometheus│  │   Grafana   │  │   │
│  │  /metrics ──────┼────┤  │+ Alertmgr│  │  Dashboard  │  │   │
│  └─────────────────┘    │  └──────────┘  └─────────────┘  │   │
│         │               │  ┌──────────┐  ┌─────────────┐  │   │
│  ┌──────▼──────┐        │  │   Loki   │  │  Promtail   │  │   │
│  │     HPA     │        │  │  (logs)  │◄─│ (DaemonSet) │  │   │
│  │ min:2 max:5 │        │  └──────────┘  └─────────────┘  │   │
│  └─────────────┘        └──────────────────────────────────┘   │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Prometheus Operator CRDs                                │  │
│  │  ServiceMonitor → auto-scrape /metrics                   │  │
│  │  PrometheusRule → 3 alert rules (restart/HPA/error-rate) │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│            Terraform — Enterprise Landing Zone                  │
│  modules/network  modules/gke  modules/iam                      │
│  envs/dev  envs/prod  (remote state on GCS)                     │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| **Container Orchestration** | GKE Autopilot |
| **Application** | Python / Flask / Gunicorn |
| **Container Registry** | GCP Artifact Registry |
| **IaC** | Terraform (modular enterprise layout) |
| **Package Management** | Helm (templated chart with dev/prod values) |
| **Metrics** | Prometheus + Prometheus Operator |
| **Logs** | Loki + Promtail |
| **Visualization** | Grafana (custom dashboard) |
| **Alerting** | Alertmanager via PrometheusRule CRD |
| **Security Scanning** | Trivy (integrated in CI, shift-left) |
| **CI/CD** | GitHub Actions + Workload Identity Federation |

---

## 📁 Repository Structure

```
cloud-platform-lab/
├── app.py                          # Flask app with /healthz, /load, /metrics
├── Dockerfile                      # Multi-stage build, Gunicorn
├── requirements.txt
│
├── k8s/
│   ├── deployment.yaml             # Deployment with liveness/readiness probes
│   ├── service.yaml                # ClusterIP + GKE NEG annotation
│   ├── ingress.yaml                # GCE Ingress (Container-native LB)
│   ├── hpa.yaml                    # HPA: min 2, max 5, CPU target 50%
│   ├── sidecar-demo.yaml           # Init Container + Sidecar pattern demo
│   ├── service-monitor.yaml        # Prometheus Operator CRD: auto-scrape
│   ├── prometheus-rules.yaml       # 3 alert rules via PrometheusRule CRD
│   ├── loki-values.yaml            # Loki + Promtail Helm values
│   ├── grafana-dashboards/
│   │   └── flask-app.json          # Custom dashboard: p50/p95/p99 latency
│   └── flask-app-chart/            # Helm chart (properly templated)
│       ├── Chart.yaml
│       ├── values.yaml             # Dev defaults
│       ├── values-prod.yaml        # Prod overrides
│       └── templates/
│           ├── deployment.yaml     # Uses {{ .Values.xxx }}
│           ├── service.yaml
│           ├── ingress.yaml
│           └── hpa.yaml            # Controlled by autoscaling.enabled
│
├── enterprise_tf/                  # Modular Terraform landing zone
│   ├── modules/
│   │   ├── network/                # VPC, subnets, firewall rules
│   │   ├── gke/                    # GKE cluster module
│   │   └── iam/                    # Service accounts, IAM bindings
│   └── envs/
│       ├── dev/                    # Dev environment tfvars
│       └── prod/                   # Prod environment tfvars
│
└── .github/
    └── workflows/
        └── terraform.yml           # CI: WIF auth → Trivy scan → TF plan
```

---

## 🔑 Key Engineering Decisions

### 1. GKE Autopilot vs Standard
Chose **Autopilot** for this lab: billing by Pod `requests` (not node uptime), no Node management overhead, and hardened security defaults. Trade-off: cannot customise Node-level settings (e.g., GPU nodes, custom kernel flags) — would use Standard for those requirements.

### 2. Prometheus Operator Pattern (CRD-driven)
Instead of manually editing `prometheus.yaml`, all scrape config and alert rules are managed via **CRDs** (`ServiceMonitor`, `PrometheusRule`). The Operator reconciliation loop hot-reloads changes without restarting Prometheus. This enables self-service monitoring — each team applies their own `ServiceMonitor` without a centralised config file bottleneck.

### 3. Keyless CI Authentication (WIF)
GitHub Actions authenticates to GCP via **Workload Identity Federation** (OIDC token exchange), eliminating long-lived Service Account keys. The exchanged access token is valid for 1 hour only — no credentials stored in GitHub Secrets.

### 4. Shift-Left Security with Trivy
Trivy scans the container image **after build, before push** to Artifact Registry. Pipeline fails on `CRITICAL` or `HIGH` severity fixable CVEs. `--ignore-unfixed` reduces noise from vulnerabilities with no available patch.

### 5. Helm Templating with Environment Separation
`values.yaml` = dev defaults. `values-prod.yaml` = prod overrides (higher replicas, CPU, git SHA tag). Deployed with `-f values.yaml -f values-prod.yaml` (later file wins). Templates use `{{ .Values.xxx }}` throughout — no hardcoded values.

---

## 🚀 Quick Start

### Prerequisites
```bash
# Install tools
brew install google-cloud-sdk kubectl helm terraform
```

### 1. GKE Cluster
```bash
# Create Autopilot cluster
gcloud container clusters create-auto cloud-platform-cluster \
  --region us-east1 \
  --project <YOUR_PROJECT_ID>

# Get credentials
gcloud container clusters get-credentials cloud-platform-cluster \
  --region us-east1
```

### 2. Build & Push Flask App
```bash
# Build and push to Artifact Registry
docker build -t <REGION>-docker.pkg.dev/<PROJECT>/<REPO>/cloud-platform-lab:latest .
docker push <REGION>-docker.pkg.dev/<PROJECT>/<REPO>/cloud-platform-lab:latest

# OR let CI do it (push to main triggers GitHub Actions)
```

### 3. Deploy Flask App
```bash
# Option A: Raw manifests
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/ingress.yaml
kubectl apply -f k8s/hpa.yaml

# Option B: Helm chart (recommended)
helm upgrade --install flask-app ./k8s/flask-app-chart \
  -f k8s/flask-app-chart/values.yaml
```

### 4. Deploy Observability Stack
```bash
# Prometheus + Grafana + Alertmanager
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set grafana.adminPassword=admin \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false

# Loki + Promtail
helm repo add grafana https://grafana.github.io/helm-charts
helm upgrade --install loki grafana/loki-stack \
  --namespace monitoring \
  -f k8s/loki-values.yaml

# Apply CRDs
kubectl apply -f k8s/service-monitor.yaml
kubectl apply -f k8s/prometheus-rules.yaml
```

### 5. Access Dashboards
```bash
# Grafana (admin/admin)
kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80
# → http://localhost:3000

# Prometheus
kubectl port-forward svc/prometheus-kube-prometheus-prometheus -n monitoring 9090:9090
# → http://localhost:9090/targets  (verify flask-app is UP)
```

---

## 📊 Observability Details

### Custom Prometheus Metrics (Flask App)
| Metric | Type | Description |
|---|---|---|
| `flask_request_count_total` | Counter | Request count by endpoint & status code |
| `flask_request_latency_seconds` | Histogram | Latency distribution (p50/p95/p99) |
| `flask_active_requests` | Gauge | In-flight request count |
| `flask_load_requests_total` | Counter | CPU load generation requests |

### Alert Rules
| Alert | Condition | Severity |
|---|---|---|
| `PodFrequentRestart` | > 3 restarts in 5 min | warning |
| `HPAMaxReplicasReached` | Current replicas = max for 5 min | warning |
| `HighErrorRate` | 5xx rate > 5% for 2 min | critical |

### LogQL Queries (Loki)
```logql
# All flask-app logs
{app="flask-app", namespace="default"}

# Error logs only
{app="flask-app"} |= "ERROR"

# Error rate over time
rate({app="flask-app"} |= "ERROR" [5m])
```

---

## 🔒 Security

- **No long-lived credentials** — WIF OIDC token exchange in CI
- **Trivy image scanning** — CRITICAL/HIGH CVE blocks pipeline
- **Pod Security Context** — `runAsNonRoot`, `readOnlyRootFilesystem`, capabilities dropped
- **GKE Workload Identity** — Pods use GCP SA without mounting key files
- **NEG (Network Endpoint Group)** — Container-native load balancing, traffic reaches Pod directly

---

## 🌱 Sustainability Context

This lab is part of an **ESG Cloud Architect** portfolio. Related sustainability practices:
- GKE Autopilot eliminates idle node compute waste — you pay only for Pod `requests`
- Region selection (`us-east1`) considered against GCP Carbon Footprint data
- HPA ensures efficient resource utilisation — no over-provisioned idle replicas
- See [GCP Carbon Footprint](https://console.cloud.google.com/carbon) for emissions data

---

## 📋 Lab Progress

- [x] Day 1: GKE Autopilot cluster + Flask app + Artifact Registry
- [x] Day 2: K8s manifests (Deployment / Service / Ingress) + GKE best practices
- [x] Day 3: HPA (CPU-based scaling) + 5-scenario fault injection & debugging
- [x] Day 4: Helm chart (properly templated) + dev/prod environment separation
- [x] Day 5: Init Container + Sidecar pattern demo
- [x] Day 6: kube-prometheus-stack + Loki + Grafana K8s dashboards
- [x] Day 7: Custom /metrics endpoint + ServiceMonitor + PrometheusRule + Trivy CI
- [ ] Day 8: Cloud Carbon Footprint dashboard + CCF methodology
- [ ] Day 9: Green Software Foundation SCI spec + Vault concepts
- [ ] Day 10: Architecture diagram + README finalisation
