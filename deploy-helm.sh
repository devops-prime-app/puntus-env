#!/bin/bash
# deploy-helm.sh — Deploy 10 Helm apps with deliberate failure modes
set -euo pipefail

NAMESPACE="demo-apps"
HELM_VALUES_DIR="$(dirname "$0")/helm-values"
APPS=(
  "app1-frontend"
  "app2-backend-api"
  "app3-worker-process"
  "app4-redis-cache"
  "app5-postgres-db"
  "app6-nginx-proxy"
  "app7-metrics-collector"
  "app8-log-aggregator"
  "app9-task-scheduler"
  "app10-message-queue"
)

CHARTS=(
  "app1-frontend=oci://registry-1.docker.io/bitnamicharts/nginx"
  "app2-backend-api=oci://registry-1.docker.io/bitnamicharts/nginx"
  "app3-worker-process=oci://registry-1.docker.io/bitnamicharts/nginx"
  "app4-redis-cache=oci://registry-1.docker.io/bitnamicharts/redis"
  "app5-postgres-db=oci://registry-1.docker.io/bitnamicharts/postgresql"
  "app6-nginx-proxy=oci://registry-1.docker.io/bitnamicharts/nginx"
  "app7-metrics-collector=oci://registry-1.docker.io/bitnamicharts/prometheus"
  "app8-log-aggregator=oci://registry-1.docker.io/bitnamicharts/fluent-bit"
  "app9-task-scheduler=oci://registry-1.docker.io/bitnamicharts/nginx"
  "app10-message-queue=oci://registry-1.docker.io/bitnamicharts/rabbitmq"
```

echo "============================================"
echo "Deploying 10 Demo Apps with Deliberate Issues"
echo "============================================"

# Create namespace
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

for APP in "${APPS[@]}"; do
  echo ""
  echo "--- Deploying ${APP} ---"
  VALUES_FILE="${HELM_VALUES_DIR}/${APP}.yaml"

  if [ ! -f "${VALUES_FILE}" ]; then
    echo "WARNING: Values file not found: ${VALUES_FILE}, skipping"
    continue
  fi

  # Find chart for this app
  CHART=""
  for entry in "${CHARTS[@]}"; do
    KEY="${entry%%=*}"
    if [ "${KEY}" = "${APP}" ]; then
      CHART="${entry#*=}"
      break
    fi
  done

  if [ -z "${CHART}" ]; then
    echo "WARNING: No chart mapping for ${APP}, skipping"
    continue
  fi

  # Install/upgrade with --atomic=false so we don't block on failures
  # This is intentional — we want broken apps to stay broken for demo
  helm upgrade --install "${APP}" "${CHART}" \
    --namespace "${NAMESPACE}" \
    --values "${VALUES_FILE}" \
    --wait \
    --timeout 2m \
    --atomic=false 2>&1 || echo "  [EXPECTED FAILURE] ${APP} deployment encountered issues"
done

echo ""
echo "============================================"
echo "Deployment Complete — Status Summary:"
echo "============================================"
kubectl get pods -n "${NAMESPACE}" -o wide
echo ""
echo "Deliberate Issues Summary (expect failures):"
echo "  app1-frontend:     Memory limit < request → OOMKill"
echo "  app2-backend-api:  Non-existent image tag → ImagePullBackOff"
echo "  app3-worker:       Missing config file → CrashLoopBackOff"
echo "  app4-redis:        Non-existent PVC → Pending"
echo "  app5-postgres:     Invalid storage class → Pending"
echo "  app6-nginx-proxy:  Readiness probe wrong port → Not Ready"
echo "  app7-metrics:      Liveness probe too aggressive → Restart loop"
echo "  app8-log-agg:      Impossible memory req → Unschedulable"
echo "  app9-scheduler:    Readiness file never created → Not Ready"
echo "  app10-mq:          Service port mismatch → AMQP unreachable"
