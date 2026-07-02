#!/bin/bash
# deploy-infra.sh — Deploy ArgoCD, Jenkins, Prometheus/Grafana, Ingress-NGINX
set -euo pipefail

echo "============================================"
echo "Deploying Infrastructure Services"
echo "============================================"

# 1. Ingress-NGINX
echo "" && echo "--- Ingress-NGINX ---"
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>/dev/null || true
helm repo update 2>/dev/null
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.service.type=LoadBalancer \
  --wait --timeout 5m
INGRESS_IP=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Ingress-NGINX IP: ${INGRESS_IP}"

# 2. ArgoCD
echo "" && echo "--- ArgoCD ---"
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd --create-namespace \
  --set server.service.type=ClusterIP \
  --wait --timeout 5m
ARGOCD_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d)
echo "ArgoCD: admin / ${ARGOCD_PASS}"

# 3. Jenkins
echo "" && echo "--- Jenkins ---"
helm repo add jenkins https://charts.jenkins.io 2>/dev/null || true
helm repo update jenkins 2>/dev/null
helm upgrade --install jenkins jenkins/jenkins \
  --namespace jenkins --create-namespace \
  --set controller.serviceType=ClusterIP \
  --wait --timeout 10m
JENKINS_PASS=$(kubectl get secret --namespace jenkins jenkins -o jsonpath="{.data.jenkins-admin-password}" 2>/dev/null | base64 -d)
echo "Jenkins: admin / ${JENKINS_PASS}"

# 4. Prometheus + Grafana
echo "" && echo "--- Prometheus + Grafana ---"
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set grafana.service.type=ClusterIP \
  --set prometheus.service.type=ClusterIP \
  --set grafana.adminPassword=DevOpsPrime2024! \
  --wait --timeout 10m
echo "Grafana: admin / DevOpsPrime2024!"

# Create Ingress routes
echo "" && echo "--- Creating Ingress Routes ---"
INGRESS_IP=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

kubectl apply -f - << EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd
  namespace: argocd
spec:
  ingressClassName: nginx
  rules:
  - host: argocd.demo.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              number: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: jenkins
  namespace: jenkins
spec:
  ingressClassName: nginx
  rules:
  - host: jenkins.demo.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: jenkins
            port:
              number: 8080
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana
  namespace: monitoring
spec:
  ingressClassName: nginx
  rules:
  - host: grafana.demo.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: monitoring-grafana
            port:
              number: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: prometheus
  namespace: monitoring
spec:
  ingressClassName: nginx
  rules:
  - host: prometheus.demo.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: monitoring-kube-prometheus-prometheus
            port:
              number: 9090
EOF

echo ""
echo "============================================"
echo "Infrastructure Deployed!"
echo "============================================"
echo ""
echo "Access via Ingress-NGINX: http://${INGRESS_IP}"
echo "Add to /etc/hosts:"
echo "${INGRESS_IP} argocd.demo.local jenkins.demo.local grafana.demo.local prometheus.demo.local"
echo ""
echo "Credentials:"
echo "  ArgoCD:     http://argocd.demo.local     admin / ${ARGOCD_PASS}"
echo "  Jenkins:    http://jenkins.demo.local    admin / ${JENKINS_PASS}"
echo "  Grafana:    http://grafana.demo.local    admin / DevOpsPrime2024!"
echo "  Prometheus: http://prometheus.demo.local  (no auth)"
