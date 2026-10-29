# ai-grid-o11y-spoke

![Version: 0.3.0](https://img.shields.io/badge/Version-0.3.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)

Spoke-side AI Grid observability resources

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| collector.namespace | string | `"redhat-ods-monitoring"` | Namespace containing the data-science-collector. Must match `operator.<type>.monitoringNamespace` when used through the parent chart. |
| collector.port | int | `8890` | Prometheus exporter port, shared by the scrape target, NetworkPolicy and parent-injected exporter. |
| collector.scrapeConfig.enabled | bool | `true` | Render ScrapeConfig. Set false for query-only installs or after migrating collection to ACM management; requires the open-cluster-management-observability namespace. |
| datasource.apiVersion | string | `"perses.dev/v1alpha2"` |  |
| datasource.instanceSelector | object | `{}` | Label selector for the intended spoke Perses instance. |
| datasource.name | string | `"grid-tenant-hub-metrics"` |  |
| enabled | bool | `false` | Include the spoke chart through the parent. Also required for standalone metrics queries. |
| fullnameOverride | string | `""` |  |
| metricsAuthPolicy.audience | string | `""` | Intended MaaS audience. |
| metricsAuthPolicy.authentication | object | `{}` | Gateway session or JWT authentication rules for Authorino. |
| metricsAuthPolicy.authorization | object | `{}` | Optional additional authorization rules; viewer membership is always required. |
| metricsAuthPolicy.issuer | string | `""` | Trusted shared OIDC issuer URL. |
| metricsAuthPolicy.scopeExpression | string | `""` | CEL expression selecting the verified organization_id/QGUID. |
| metricsQuery.clientTLSSecretName | string | `""` | Secret with tls.crt and tls.key for the spoke client certificate. |
| metricsQuery.dnsResolver | string | `"dns-default.openshift-dns.svc"` | OpenShift DNS resolver used to track hub Route address changes. |
| metricsQuery.enabled | bool | `false` | Enable the tenant metrics datasource, Gateway route, policy, proxy, and hub relay. |
| metricsQuery.gatewayNamespaceSelector | object | `{"matchLabels":{"kubernetes.io/metadata.name":"openshift-ingress"}}` | Gateway namespace and pod selectors for the proxy ingress policy. |
| metricsQuery.gatewayPodSelector.matchLabels."gateway.networking.k8s.io/gateway-name" | string | `"maas-default-gateway"` |  |
| metricsQuery.hubHostname | string | `""` | Hub mTLS Route hostname; the relay uses HTTPS with certificate verification. |
| metricsQuery.image.digest | string | `"sha256:d1eb117322c0374e286f73d6f67912c1171c605eb34cd5dd33005375747c77a5"` |  |
| metricsQuery.image.pullPolicy | string | `"IfNotPresent"` |  |
| metricsQuery.image.repository | string | `"registry.access.redhat.com/ubi9/nginx-124"` | Spoke NGINX mTLS relay image repository. |
| metricsQuery.imagePullSecrets | list | `[]` | Optional pull secrets for the relay and proxy images. |
| metricsQuery.listenPort | int | `8080` | Loopback port for the NGINX mTLS relay sidecar. |
| metricsQuery.proxy.enableLabelAPIs | bool | `true` | Enable tenant-filtered label name and value discovery. |
| metricsQuery.proxy.image.digest | string | `"sha256:4053948b40f66dc5f8d2baaeb62463aec85079b55add1151a658f1005cc604f4"` | Image digest; align with the target RHOAI payload before rollout. |
| metricsQuery.proxy.image.pullPolicy | string | `"IfNotPresent"` |  |
| metricsQuery.proxy.image.repository | string | `"registry.redhat.io/openshift4/ose-prom-label-proxy-rhel9"` | Pinned OpenShift prom-label-proxy image repository. |
| metricsQuery.proxy.label | string | `"organization_id"` | Tenant label stored in hub Thanos. |
| metricsQuery.proxy.listenPort | int | `8081` | Gateway-facing proxy port. Must differ from metricsQuery.listenPort. |
| metricsQuery.proxy.resources.limits.cpu | string | `"100m"` |  |
| metricsQuery.proxy.resources.limits.memory | string | `"128Mi"` |  |
| metricsQuery.proxy.resources.requests.cpu | string | `"10m"` |  |
| metricsQuery.proxy.resources.requests.memory | string | `"64Mi"` |  |
| metricsQuery.resources.limits.cpu | string | `"100m"` |  |
| metricsQuery.resources.limits.memory | string | `"128Mi"` |  |
| metricsQuery.resources.requests.cpu | string | `"10m"` |  |
| metricsQuery.resources.requests.memory | string | `"64Mi"` |  |
| metricsQuery.serverCASecretName | string | `""` | Secret with ca.crt for the hub server CA. |
| metricsRoute.hostname | string | `""` | Public Gateway hostname, used to derive the datasource's HTTPS /metrics URL. |
| metricsRoute.name | string | `"grid-tenant-metrics"` |  |
| metricsRoute.namespace | string | `""` | Namespace for the HTTPRoute and AuthPolicy; empty uses the Perses project. |
| metricsRoute.parentRefs | list | `[{"name":"maas-default-gateway","namespace":"openshift-ingress","sectionName":"https"}]` | Target the default MaaS Gateway HTTPS listener; override for a different Gateway. |
| metricsRoute.pathPrefix | string | `"/metrics"` |  |
| nameOverride | string | `""` |  |
| tenantAdminNamespace.create | bool | `false` | Create and own the namespace with this Helm release. |
| tenantAdminNamespace.name | string | `"ai-grid-o11y-tenant-admin"` | Perses project and datasource namespace for tenant metrics queries. |

