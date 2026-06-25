#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Deploy lab workloads onto the EKS + Cilium Enterprise cluster.
#
#   1. Online Boutique  – 11-service microservices demo (lights up Hubble UI)
#   2. Star Wars demo   – tiny app for L3/L4 + L7 CiliumNetworkPolicy practice
#   3. Tetragon demo    – TracingPolicy to observe runtime exec/network events
#
# Optional Enterprise demo policies (NOT applied by default — opt in with
# ENTERPRISE_DEMOS=true, or apply them by hand from the next-steps below):
#   - lab/dns-egress-policy.yaml        mediabot + FQDN egress (allow github only)
#   - lab/tetragon-enforce-shadow.yaml  SIGKILL reads of /etc/shadow (default ns)
#
# Prereqs: kubectl pointed at the cluster, Cilium + Tetragon already installed.
#   aws eks update-kubeconfig --region ap-southeast-2 --name isovalent-syd
#
# Usage:
#   ./deploy.sh                        # base apps + observe-only policies
#   ENTERPRISE_DEMOS=true ./deploy.sh  # also apply the FQDN + enforcement demos
# ---------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CILIUM_REF="v1.15.6"   # Star Wars demo manifest ref (app only; CNI-version independent)
ENTERPRISE_DEMOS="${ENTERPRISE_DEMOS:-false}"   # opt-in: FQDN egress + Tetragon enforcement

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

if [ "${ENTERPRISE_DEMOS}" = "true" ]; then
  echo "==> Optional  Enterprise demos (ENTERPRISE_DEMOS=true)"
  echo "    applying FQDN egress demo (mediabot -> api.github.com only)"
  kubectl apply -f "${SCRIPT_DIR}/dns-egress-policy.yaml"
  echo "    applying Tetragon ENFORCEMENT policy (SIGKILL reads of /etc/shadow in default ns)"
  kubectl apply -f "${SCRIPT_DIR}/tetragon-enforce-shadow.yaml"
else
  echo "==> Optional  Enterprise demos NOT applied (set ENTERPRISE_DEMOS=true to include them)"
fi

cat <<'EOF'

Done. Useful next steps:

  # Watch services come up
  kubectl -n boutique get pods -w

  # Hubble UI (service map + L7 flows)
  cilium hubble ui

  # Star Wars L7 policy in action (allowed vs L7-denied vs L3/L4-dropped)
  # Empire tiefighter is allowed to land, but denied the exhaust-port API at L7:
  kubectl exec tiefighter -- curl -s -XPOST deathstar.default.svc.cluster.local/v1/request-landing   # Ship landed
  kubectl exec tiefighter -- curl -s -XPUT  deathstar.default.svc.cluster.local/v1/exhaust-port      # Access denied (L7)
  # Rebel xwing is dropped at L3/L4 (connection times out):
  kubectl exec xwing -- curl -s -m5 -XPOST deathstar.default.svc.cluster.local/v1/request-landing    # dropped

  # Tetragon runtime events
  kubectl -n kube-system exec -it ds/tetragon -c tetragon -- tetra getevents -o compact

  # --- Optional Enterprise demos (apply when you want them) ---
  # FQDN egress: mediabot may reach only api.github.com
  kubectl apply -f lab/dns-egress-policy.yaml
  kubectl exec mediabot -- curl -sI -m8 https://api.github.com | head -1   # 200 (allowed)
  kubectl exec mediabot -- curl -sI -m8 https://www.cisco.com  | head -1   # times out (denied)

  # Tetragon ENFORCEMENT: SIGKILL any read of /etc/shadow in the default namespace
  kubectl apply -f lab/tetragon-enforce-shadow.yaml
  kubectl exec tiefighter -- cat /etc/shadow ; echo "exit=$?"             # exit=137 (killed)

  # Full customer demo script: lab/DEMO_RUNBOOK.md
EOF
