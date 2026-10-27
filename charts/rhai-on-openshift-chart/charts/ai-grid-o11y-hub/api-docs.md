# ai-grid-o11y-hub

![Version: 0.3.0](https://img.shields.io/badge/Version-0.3.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)

Hub-side AI Grid observability resources

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| fullnameOverride | string | `""` |  |
| mtlsIngress.clientCASecretName | string | `""` | Secret with ca.crt for the dedicated spoke client CA. |
| mtlsIngress.dnsResolver | string | `"dns-default.openshift-dns.svc"` | OpenShift DNS resolver used to track Thanos Service address changes. |
| mtlsIngress.enabled | bool | `false` | Expose approved read endpoints of ACM Thanos through a TLS passthrough Route requiring a spoke client certificate. |
| mtlsIngress.hostname | string | `""` | Public hub Route hostname. Required when enabled. |
| mtlsIngress.image.digest | string | `"sha256:d1eb117322c0374e286f73d6f67912c1171c605eb34cd5dd33005375747c77a5"` |  |
| mtlsIngress.image.pullPolicy | string | `"IfNotPresent"` |  |
| mtlsIngress.image.repository | string | `"registry.access.redhat.com/ubi9/nginx-124"` |  |
| mtlsIngress.listenPort | int | `8443` |  |
| mtlsIngress.resources.limits.cpu | string | `"100m"` |  |
| mtlsIngress.resources.limits.memory | string | `"128Mi"` |  |
| mtlsIngress.resources.requests.cpu | string | `"10m"` |  |
| mtlsIngress.resources.requests.memory | string | `"64Mi"` |  |
| mtlsIngress.routerNamespaceSelector | object | `{"matchLabels":{"network.openshift.io/policy-group":"ingress"}}` | OpenShift router namespace selector for the ingress NetworkPolicy. |
| mtlsIngress.routerPodSelector | object | `{"matchLabels":{"ingresscontroller.operator.openshift.io/deployment-ingresscontroller":"default"}}` | OpenShift default router pod selector. Override for a custom ingress controller. |
| mtlsIngress.serverTLSSecretName | string | `""` | Secret with tls.crt and tls.key for the Route hostname. |
| mtlsIngress.thanosHostname | string | `"observability-thanos-query.open-cluster-management-observability.svc.cluster.local"` | ACM Thanos Query Service hostname reached from the hub ingress. |
| mtlsIngress.thanosPort | int | `9090` | ACM Thanos Query Service port. |
| nameOverride | string | `""` |  |

