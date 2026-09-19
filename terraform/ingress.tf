
resource "helm_release" "ingress_nginx" {
  name                  = "ingress-nginx"
  repository            = "https://kubernetes.github.io/ingress-nginx"
  chart                 = "ingress-nginx"
  namespace             = "ingress-nginx"
  create_namespace      =  true

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
        type = "string"
    }
  ]
}