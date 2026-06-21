#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Deploy lab workloads onto the EKS + Cilium (OSS) cluster.
#
#   1. Online Boutique  – 11-service microservices demo (lights up Hubble UI)
#   2. Star Wars demo   – tiny app for L3/L4 + L7 CiliumNetworkPolicy practice
#   3. Tetragon demo    – TracingPolicy to observe runtime exec/network events
#
# Prereqs: kubectl pointed at the cluster, Cilium + Tetragon already installed.
#   aws eks update-kubeconfig --region ap-southeast-2 --name isovalent-syd
# ---------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CILIUM_REF="v1.15.6"   # keep in sync with terraform.tfvars cilium_version

echo "==> 1/3  Online Boutique (namespace: boutique)"
kubectl create namespace boutique --dry-run=client -o yaml | kubectl apply -f -
kubectl -n boutique apply -f \
  https://raw.githubusercontent.com/GoogleCloudPlatform/microservices-demo/v0.10.2/release/kubernetes-manifests.yaml

echo "==> 2/3  Star Wars demo (default namespace)"
kubectl apply -f \
  "https://raw.githubusercontent.com/cilium/cilium/${CILIUM_REF}/examples/minikube/http-sw-app.yaml"
echo "    applying L7 CiliumNetworkPolicy (deathstar)"
kubectl apply -f "${SCRIPT_DIR}/starwars-l7-policy.yaml"

echo "==> 3/3  Tetragon TracingPolicy (runtime visibility)"
kubectl apply -f "${SCRIPT_DIR}/tetragon-tracingpolicy.yaml"

cat <<'EOF'

Done. Useful next steps:

  # Watch services come up
  kubectl -n boutique get pods -w

  # Hubble UI (service map + L7 flows)
  cilium hubble ui

  # Star Wars L7 policy in action (allowed vs denied)
  XWING=$(kubectl get pod -l class=xwing -o jsonpath='{.items[0].metadata.name}')
  kubectl exec "$XWING" -- curl -s -XPOST deathstar.default.svc.cluster.local/v1/request-landing
  kubectl exec "$XWING" -- curl -s -XPUT  deathstar.default.svc.cluster.local/v1/exhaust-port   # should be denied

  # Tetragon runtime events
  kubectl -n kube-system exec -it ds/tetragon -c tetragon -- tetra getevents -o compact
EOF
