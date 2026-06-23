# ============================================================================
# Phase 2 (opt-in) — Hubble Timescape
#
# Gives you a single pane that correlates Hubble *network flows* with Tetragon
# *runtime/process events* over a long retention window (the thing OSS Hubble
# cannot do). Uses PUSH mode: Cilium streams flows straight to the Timescape
# ingester's gRPC push API, which writes them to ClickHouse — no object storage
# or exporter required. Provisions:
#   - the clickhouse-operator + a chart-managed ClickHouse cluster (the store)
#   - the hubble-timescape chart (ingester gRPC push API + server + UI)
#
# Everything here is gated on var.enable_timescape (default false), so when it
# is off this file contributes ZERO changes to the plan.
#
# Values verified against hubble-timescape chart 1.18.8.
# ============================================================================

locals {
  ts_count = var.enable_timescape ? 1 : 0

  # Per-component image pull secrets (the chart has no global key).
  ts_pull_secrets = local.create_pull_secret ? [{ name = var.isovalent_pull_secret_name }] : []
}

# --- Namespace + pull secret -------------------------------------------------
resource "kubernetes_namespace" "timescape" {
  count = local.ts_count
  metadata {
    name = var.timescape_namespace
  }
}

resource "kubernetes_secret" "timescape_pull_secret" {
  count = local.ts_count == 1 && local.create_pull_secret ? 1 : 0

  metadata {
    name      = var.isovalent_pull_secret_name
    namespace = kubernetes_namespace.timescape[0].metadata[0].name
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = var.isovalent_pull_secret_json
  }
}

# --- ClickHouse (Timescape's database) --------------------------------------
resource "helm_release" "clickhouse_operator" {
  count      = local.ts_count
  name       = "clickhouse-operator"
  repository = var.isovalent_helm_repo
  chart      = "clickhouse-operator"
  version    = var.clickhouse_operator_version
  namespace  = kubernetes_namespace.timescape[0].metadata[0].name

  wait    = true
  timeout = 600

  dynamic "set" {
    for_each = local.create_pull_secret ? [1] : []
    content {
      name  = "imagePullSecrets[0].name"
      value = var.isovalent_pull_secret_name
    }
  }

  depends_on = [helm_release.cilium]
}

# --- Hubble Timescape (ingester + server) -----------------------------------
resource "helm_release" "hubble_timescape" {
  count      = local.ts_count
  name       = "hubble-timescape"
  repository = var.isovalent_helm_repo
  chart      = "hubble-timescape"
  version    = var.timescape_version
  namespace  = kubernetes_namespace.timescape[0].metadata[0].name

  wait    = false
  timeout = 600

  values = [yamlencode({
    # ClickHouse: let the chart deploy its own cluster via clickhouse-operator.
    # The DSN host auto-resolves to "clickhouse-hubble-timescape" in-cluster.
    clickhouse = {
      cluster = {
        enabled = true
        image   = { pullSecrets = local.ts_pull_secrets }
      }
    }

    # Per-component Enterprise images (quay.io/isovalent) need the pull secret.
    certgen  = { image = { pullSecrets = local.ts_pull_secrets } }
    migrate  = { image = { pullSecrets = local.ts_pull_secrets } }
    trimmer  = { image = { pullSecrets = local.ts_pull_secrets } }
    analyzer = { image = { pullSecrets = local.ts_pull_secrets } }
    server   = { image = { pullSecrets = local.ts_pull_secrets } }
    ui       = { image = { pullSecrets = local.ts_pull_secrets } }

    # Push mode: no bucket configured, so the ingester runs push-only and
    # accepts flows streamed from Cilium over its gRPC push API (port 4260).
    ingester = {
      image = { pullSecrets = local.ts_pull_secrets }
      server = {
        grpc = { enabled = true }
        tls  = { enabled = false }
      }
    }
  })]

  depends_on = [
    helm_release.clickhouse_operator,
  ]
}
