# Attempt to setup k8s dashboard from helmchart

Does not work with chart v7.0.3, github.com/kubernetes/dashboard v3.0.0-alpha0. Namespace missing from rendered manifest, e.g. "Namespace for kubernetes-dashboard networking.k8s.io/v1, Kind=Ingress is missing."