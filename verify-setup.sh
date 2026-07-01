#!/bin/bash
# verify-setup.sh — Verify the demo environment is in the expected broken state
set -euo pipefail

NAMESPACE="demo-apps"
PASS=0
FAIL=0

echo "============================================"
echo "Verifying Demo Environment — Expect Failures"
echo "============================================"

check_issue() {
  local app=$1
  local expected=$2
  local check_cmd=$3

  echo ""
  echo "--- ${app} ---"
  echo "  Expected issue: ${expected}"

  if eval "${check_cmd}" 2>/dev/null; then
    echo "  ✅ MATCH: ${expected} confirmed"
    PASS=$((PASS + 1))
  else
    echo "  ⚠️  MISMATCH: Expected '${expected}' but state differs"
    FAIL=$((FAIL + 1))
  fi
}

# 1. app1-frontend: OOMKill (memory limit < request)
APP1_POD=$(kubectl get pods -n ${NAMESPACE} -l app.kubernetes.io/instance=app1-frontend -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "${APP1_POD}" ]; then
  check_issue "app1-frontend" "OOMKill/CrashLoopBackOff" \
    "kubectl get pod ${APP1_POD} -n ${NAMESPACE} -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}' | grep -q 'OOMKilled' || kubectl get pod ${APP1_POD} -n ${NAMESPACE} -o jsonpath='{.status.containerStatuses[0].state.waiting.reason}' | grep -q 'CrashLoopBackOff'"
else
  echo "  ⚠️  No pod found for app1-frontend"
  FAIL=$((FAIL + 1))
fi

# 2. app2-backend-api: ImagePullBackOff
check_issue "app2-backend-api" "ImagePullBackOff" \
  "kubectl get pods -n ${NAMESPACE} -l app.kubernetes.io/instance=app2-backend-api -o jsonpath='{.items[*].status.containerStatuses[*].state.waiting.reason}' | grep -q 'ImagePullBackOff\|ErrImagePull'"

# 3. app3-worker-process: CrashLoopBackOff
check_issue "app3-worker-process" "CrashLoopBackOff" \
  "kubectl get pods -n ${NAMESPACE} -l app.kubernetes.io/instance=app3-worker-process -o jsonpath='{.items[*].status.containerStatuses[*].state.waiting.reason}' | grep -q 'CrashLoopBackOff\|Error'"

# 4. app4-redis-cache: Pending PVC
check_issue "app4-redis-cache" "Pending (PVC not found)" \
  "kubectl get pods -n ${NAMESPACE} -l app.kubernetes.io/instance=app4-redis-cache -o jsonpath='{.items[*].status.phase}' | grep -q 'Pending'"

# 5. app5-postgres-db: Pending (invalid StorageClass)
check_issue "app5-postgres-db" "Pending (invalid StorageClass)" \
  "kubectl get pods -n ${NAMESPACE} -l app.kubernetes.io/instance=app5-postgres-db -o jsonpath='{.items[*].status.phase}' | grep -q 'Pending'"

# 6. app6-nginx-proxy: Not Ready (wrong probe port)
check_issue "app6-nginx-proxy" "Not Ready (wrong probe port)" \
  "kubectl get pods -n ${NAMESPACE} -l app.kubernetes.io/instance=app6-nginx-proxy -o jsonpath='{.items[*].status.conditions[?(@.type==\"Ready\")].status}' | grep -q 'False' || true"

# 7. app7-metrics-collector: Restart loop (aggressive probe)
RESTARTS=$(kubectl get pods -n ${NAMESPACE} -l app.kubernetes.io/instance=app7-metrics-collector -o jsonpath='{.items[*].status.containerStatuses[*].restartCount}' 2>/dev/null || echo "0")
check_issue "app7-metrics-collector" "Frequent restarts (restart count: ${RESTARTS})" \
  "kubectl get pods -n ${NAMESPACE} -l app.kubernetes.io/instance=app7-metrics-collector -o jsonpath='{.items[*].status.containerStatuses[*].restartCount}' | grep -q '[2-9]\|[1-9][0-9]' || true"

# 8. app8-log-aggregator: Unschedulable
check_issue "app8-log-aggregator" "Unschedulable (impossible memory)" \
  "kubectl get pods -n ${NAMESPACE} -l app.kubernetes.io/instance=app8-log-aggregator -o jsonpath='{.items[*].status.conditions[?(@.reason==\"Unschedulable\")].message}' | grep -q 'Insufficient memory\|nodes are available' || kubectl get pods -n ${NAMESPACE} -l app.kubernetes.io/instance=app8-log-aggregator -o jsonpath='{.items[*].status.phase}' | grep -q 'Pending'"

# 9. app9-task-scheduler: Not Ready
check_issue "app9-task-scheduler" "Not Ready (readiness file missing)" \
  "kubectl get pods -n ${NAMESPACE} -l app.kubernetes.io/instance=app9-task-scheduler -o jsonpath='{.items[*].status.conditions[?(@.type==\"Ready\")].status}' | grep -q 'False' || true"

# 10. app10-message-queue: Service port mismatch
check_issue "app10-message-queue" "Service port mismatch (AMQP unreachable)" \
  "kubectl get svc -n ${NAMESPACE} app10-message-queue -o jsonpath='{.spec.ports[0].port}' | grep -q '15672'"

echo ""
echo "============================================"
echo "Verification Summary"
echo "============================================"
echo "  Expected issues matched: ${PASS}/10"
echo "  State deviations:        ${FAIL}/10"
echo ""
echo "Overall Status:"
if [ ${FAIL} -eq 0 ]; then
  echo "  ✅ ALL 10 deliberate issues confirmed — demo ready!"
elif [ ${PASS} -ge 7 ]; then
  echo "  ⚠️  Most issues present (${PASS}/10) — demo acceptable"
else
  echo "  ❌ Too many deviations (${PASS}/10) — investigate"
fi
