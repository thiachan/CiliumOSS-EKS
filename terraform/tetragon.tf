resource "helm_release" "tetragon" {
  name       = "tetragon"
  repository = "https://helm.cilium.io"
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

  depends_on = [helm_release.cilium]
}
