# DevOps-Prime Demo Environment — Full Pipeline Documentation

## Overview

A fully automated CI/CD pipeline on Google Kubernetes Engine (GKE) with **10 deliberately broken applications**, monitored by Prometheus/Grafana, deployed via ArgoCD, built by Jenkins.

```
GitHub → Jenkins → ArgoCD → GKE → Prometheus → Grafana → Troubleshoot
```

## Infrastructure

| Component | Purpose | Endpoint |
|-----------|---------|----------|
| **GKE Cluster** | Kubernetes runtime | `demo-gke-cluster` · `us-central1-a` · 1 node |
| **Jenkins** | CI/CD pipeline server | `http://34.72.64.85:30081` |
| **ArgoCD** | GitOps deployment manager | `http://34.72.64.85:30080` |
| **Prometheus** | Metrics collection & alerting | `http://34.72.64.85:30909` |
| **Grafana** | Dashboards & visualization | `http://34.72.64.85:30300` |

## Live Credentials

| Service | URL | Username | Password |
|---------|-----|----------|----------|
| **ArgoCD** | `http://34.72.64.85:30080` | `admin` | `7RH2fBLbpsAVr785` |
| **Jenkins** | `http://34.72.64.85:30081` | `admin` | `vBaRtAAxQsp4ht2eeQWpGR` |
| **Grafana** | `http://34.72.64.85:30300` | `admin` | `DevOpsPrime2024!` |
| **Prometheus** | `http://34.72.64.85:30909` | *(no auth)* | — |

## Kubernetes API (for devops-prime.com connector)

| Field | Value |
|-------|-------|
| **API Server** | `https://34.132.161.0` |
| **Auth Type** | Bearer Token |
| **Kubeconfig** | `/Users/obinnaibekwe/Downloads/puntus-env/kubeconfig-demo.yaml` |
| **SA Namespace** | `kube-system` |
| **SA Name** | `devops-prime-connector` |

## The 10 Broken Applications (Live Status)

| # | App | Status | Failure Mode | Debug Signal |
|---|-----|--------|--------------|--------------|
| 1 | `app1-frontend` | **OOMKilled** | Python memory exhaustion | `kubectl describe` shows OOMKilled |
| 2 | `app2-backend-api` | **ImagePullBackOff** | `python:3.12-nonexistent-tag-xyz` | `kubectl describe` shows ErrImagePull |
| 3 | `app3-worker-process` | **CrashLoopBackOff** | Container exits code 1 | `kubectl logs` shows "FATAL: Missing config" |
| 4 | `app4-redis-cache` | **Pending** | PVC `redis-pvc-does-not-exist` | PVC not found |
| 5 | `app5-postgres-db` | **Pending** | StorageClass `non-existent-fast-ssd` | SC not found |
| 6 | `app6-nginx-proxy` | **Running 0/1** | Readiness probe port 9999 (nginx on 80) | Wrong probe port |
| 7 | `app7-metrics-collector` | Running 1/1 | Liveness probe 1s delay (too aggressive) | Prometheus slow start |
| 8 | `app8-log-aggregator` | **Pending** | 1024Gi memory request | Unschedulable |
| 9 | `app9-task-scheduler` | **Running 0/1** | `test -f /tmp/scheduler-ready` fails | Exec probe always fails |
| 10 | `app10-message-queue` | Running 1/1 | Service port 15672, AMQP needs 5672 | Port mismatch |

## Full Demo Flow

### Step 1: Code Push → GitHub
Push to `devops-prime-app/puntus-env.git` triggers the pipeline.

### Step 2: Jenkins Pipeline
**Pipeline**: `demo-devops-prime-pipeline`
- Code Checkout → Build & Test → Security Scan → Deploy via ArgoCD → Health Check
- Pipeline **fails intentionally** at Health Check (detects all 10 issues)

### Step 3: ArgoCD GitOps
- 10 apps as ArgoCD Applications
- Shows `OutOfSync`, `Progressing`, `Degraded` statuses

### Step 4: Prometheus Monitoring
- PodMonitor scrapes `demo-apps` every 30s
- Tracks restarts, memory, pod phases

### Step 5: Grafana Visualization
- Dashboard: "Demo Apps Health Dashboard" (UID: `devops-prime-demo`)
- Panels: Pod restarts, memory usage, status table

### Step 6: Troubleshooting
1. Grafana → See unhealthy apps
2. Prometheus → Query alerts
3. ArgoCD → See deployment drift
4. Jenkins → Re-run pipeline
5. kubectl → Debug pods

## Port-Forward Alternative

```bash
export KUBECONFIG=/Users/obinnaibekwe/Downloads/puntus-env/kubeconfig-demo.yaml
kubectl port-forward -n argocd svc/argocd-server 8080:80 &
kubectl port-forward -n jenkins svc/jenkins 8081:8080 &
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80 &
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090 &
```

## Token Refresh (every 24h)

```bash
gcloud container clusters get-credentials demo-gke-cluster --zone=us-central1-a --project=project-13f5069c-9cac-4db9-8d9
kubectl create token devops-prime-connector -n kube-system --duration=86400s
```
