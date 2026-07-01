# Puntus-Env — Failure-Injected GKE Demo Environment

A fully automated CI/CD pipeline that provisions a GKE cluster, deploys 10 applications with **deliberate failure modes**, and sets up a realistic broken Kubernetes demo for buyer presentations, chaos engineering training, and troubleshooting drills.

## Architecture

```
┌─────────────────┐     ┌──────────────┐     ┌─────────────────────────────────┐
│  GitHub Actions  │────▶│  Terraform   │────▶│  GKE Cluster (us-central1)      │
│  (deploy/destroy)│     │  (GKE infra) │     │                                 │
└─────────────────┘     └──────────────┘     │  ┌─────────────────────────────┐ │
                                             │  │ ArgoCD   │ Jenkins          │ │
                                             │  │ Prometheus│ Grafana         │ │
                                             │  │ Ingress-NGINX              │ │
                                             │  └─────────────────────────────┘ │
                                             │                                   │
                                             │  10 Broken Apps:                  │
                                             │  ┌──────────────────────────────┐ │
                                             │  │ 1. OOMKill (memory)          │ │
                                             │  │ 2. ImagePullBackOff          │ │
                                             │  │ 3. CrashLoopBackOff          │ │
                                             │  │ 4. PVC Missing (Pending)     │ │
                                             │  │ 5. Invalid StorageClass      │ │
                                             │  │ 6. Wrong Probe Port          │ │
                                             │  │ 7. Aggressive Liveness Probe │ │
                                             │  │ 8. Impossible Memory Request │ │
                                             │  │ 9. Readiness File Missing    │ │
                                             │  │ 10. Service Port Mismatch    │ │
                                             │  └──────────────────────────────┘ │
                                             └───────────────────────────────────┘
```

## Prerequisites

- **GCP Project** with Kubernetes Engine API enabled
- **GitHub Repository** with these secrets configured:
  - `GCP_PROJECT_ID` — GCP project ID (e.g., `devops-prime-499411`)
  - `GCP_SA_KEY` — Service account key JSON with roles:
    - `roles/container.admin` (GKE management)
    - `roles/compute.admin` (node pools, disks)
    - `roles/iam.serviceAccountUser` (node SA binding)

## Quick Start

```bash
# Clone the repository
git clone https://github.com/devops-prime-app/puntus-env.git
cd puntus-env

# Copy and customize variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your GCP project ID and region

# Deploy (via GitHub Actions or locally)
# Option 1: Manual
terraform init && terraform apply -auto-approve
./deploy-helm.sh
./verify-setup.sh

# Option 2: GitHub Actions
# Go to Actions → Deploy Demo Environment → Run workflow
```

## Files

| File | Purpose |
|------|---------|
| `provider.tf` | Terraform GCP provider config |
| `variables.tf` | Input variables |
| `main.tf` | GKE cluster + node pool definition |
| `outputs.tf` | Terraform outputs |
| `terraform.tfvars.example` | Sample variable values |
| `deploy-helm.sh` | Deploys all 10 apps via Helm |
| `verify-setup.sh` | Checks each app has expected failure |
| `helm-values/app1-app10.yaml` | Deliberately broken Helm values |
| `.github/workflows/deploy.yml` | CI/CD deploy pipeline |
| `.github/workflows/destroy.yml` | CI/CD destroy pipeline |

## Deliberate Issues Catalog

| App | Issue | Symptom | Debug Signal |
|-----|-------|---------|--------------|
| app1-frontend | memory limit < request | OOMKilled → CrashLoopBackOff | `kubectl describe pod` shows OOMKilled |
| app2-backend-api | non-existent image tag | ImagePullBackOff | `kubectl describe pod` shows ErrImagePull |
| app3-worker | missing config file | CrashLoopBackOff | `kubectl logs` shows "FATAL: Config file not found" |
| app4-redis | non-existent PVC | Pending | `kubectl get pvc` shows missing |
| app5-postgres | invalid storage class | Pending | `kubectl describe pvc` shows SC not found |
| app6-nginx-proxy | readiness probe wrong port | Not Ready | Probe hits port 9999, nginx on 80 |
| app7-metrics | aggressive liveness probe | Restart loop | Probe triggers before Prometheus starts |
| app8-log-agg | impossible memory request | Unschedulable | 1024Gi request exceeds node capacity |
| app9-scheduler | readiness file never created | Not Ready | `test -f /tmp/scheduler-ready` always false |
| app10-mq | service port mismatch | AMQP unreachable | Service on 15672, AMQP clients need 5672 |

## GitHub Actions Secrets

```bash
# Required secrets (Workload Identity Federation — NO service account key needed):
GCP_PROJECT_ID=project-13f5069c-9cac-4db9-8d9
GCP_WIF_PROVIDER=projects/613979960436/locations/global/workloadIdentityPools/github-actions-pool/providers/github
GCP_WIF_SA=puntus-env-deployer@project-13f5069c-9cac-4db9-8d9.iam.gserviceaccount.com
```

## Destroy

```bash
# Destroy everything
terraform destroy -auto-approve

# Or via GitHub Actions:
# Actions → Destroy Demo Environment → type "DESTROY" → Run
```

## License

Proprietary — Demo purposes only.
