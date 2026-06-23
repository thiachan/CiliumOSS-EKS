resource "helm_release" "tetragon" {
  name       = "tetragon"
  repository = var.isovalent_helm_repo
  chart      = "tetragon"
  version    = var.tetragon_version
  namespace  = "kube-system"

  wait    = true
  timeout = 600

  set {
    name  = "tetragon.enableProcessCred"
    value = "true"
  }
  set {
    name  = "tetragon.enableProcessNs"
    value = "true"
  }
  set {
    name  = "tetragonOperator.podInfo.enabled"
    value = "true"
  }

  # Pull Enterprise images from quay.io/isovalent when a secret is provided.
  dynamic "set" {
    for_each = local.create_pull_secret ? [1] : []
    content {
      name  = "imagePullSecrets[0].name"
      value = var.isovalent_pull_secret_name
    }
  }

  depends_on = [
    helm_release.cilium,
    kubernetes_secret.isovalent_pull_secret,
  ]
}
