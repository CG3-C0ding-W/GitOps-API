
resource "helm_release" "ingress_nginx" {
  name                  = "ingess-nginx"
  repository            = "https://kubernetes.github.io/ingess-nginx"
  chart                 = "ingess-nginx"
  namespace             = "ingress-nginx"
  create_namespace      = true

  set = [
    {
        name = "controller.hostPort.enabled"
        value = "true"
    },
    {
        name = "controller.service.type"
        value = "NodePort"
    },
    {
        name = "controller.nodeSelector.ingress-ready"
        value = "true"
    }
  ]
}