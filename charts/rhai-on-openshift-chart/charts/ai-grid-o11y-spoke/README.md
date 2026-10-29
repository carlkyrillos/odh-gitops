# AI Grid observability spoke

This chart packages spoke-side AI Grid observability resources. The broader
feature covers metrics collection, tenant-scoped query access, and usage-log
delivery. Install it on each spoke as those capabilities are added. The
parent chart's `ai-grid-o11y-spoke.enabled` value controls inclusion of this
subchart; capability-specific values control the resources it renders.

The spoke chart always renders the collector ingress NetworkPolicy. Its
`ScrapeConfig` remains enabled by default so an upgrade retains existing
chart-managed collection. It requires the
`open-cluster-management-observability` namespace and the ScrapeConfig CRD.
Set `collector.scrapeConfig.enabled: false` for query-only installs without
that namespace, or when ACM manages collection separately.

To migrate an existing release to ACM-managed collection, configure and verify
the replacement on the hub before setting `collector.scrapeConfig.enabled:
false`. ACM MCO manages its ScrapeConfig in the hub's
`open-cluster-management-observability` namespace and distributes collection
configuration to selected managed clusters through an add-on Placement.
Disabling the chart's ScrapeConfig removes it from the release. The query path
does not require that resource to render or start; tenant metric data requires
the separate collection and label attribution setup.

## Tenant metrics queries

For a standalone install, set both `enabled: true` and
`metricsQuery.enabled: true` to deploy the query path described below. When
installing through the parent chart, set `ai-grid-o11y-spoke.enabled: true`
and `ai-grid-o11y-spoke.metricsQuery.enabled: true`.

Query access is independent of spoke metrics collection. For a standalone
query-only release, use the following toggles together with the required
hostnames, authentication, datasource selector, and certificate Secret names:

```yaml
enabled: true
collector:
  scrapeConfig:
    enabled: false
metricsQuery:
  enabled: true
```

The query path consists of a project-scoped `PersesDatasource` in
`ai-grid-o11y-tenant-admin`, a GET-only `/metrics` `HTTPRoute` and route
`AuthPolicy`, and one query Service/Deployment/NetworkPolicy. The query pod
runs `prom-label-proxy` in front of a loopback NGINX mTLS relay. The route
and query Service share a namespace, so no `ReferenceGrant` is needed. The
proxy adds an `organization_id` matcher before NGINX sends the query to the
hub. The relay verifies the hub TLS certificate and presents a client
certificate to the hub's protected Route. The hub mTLS ingress forwards
approved read endpoints to ACM Thanos Query. The chart derives the
datasource URL as `https://<metricsRoute.hostname>/metrics`.

Create these Secrets in the route namespace before enabling queries:

- `metricsQuery.clientTLSSecretName`: `tls.crt` and `tls.key` for a client
  certificate signed by the CA trusted at the hub;
- `metricsQuery.serverCASecretName`: `ca.crt` for the hub Route server.

Set `metricsQuery.hubHostname` to the exact hub Route host and
`metricsRoute.hostname` to the spoke Gateway host. The relay connects to the
hub with HTTPS and verifies that hostname. The default NetworkPolicy permits
only pods of `maas-default-gateway` in `openshift-ingress` to reach the proxy.
Adjust the namespace and pod selectors if the Gateway runs elsewhere.

Set `metricsQuery.proxy.label` to the label stored in hub Thanos. The proxy and
relay listen on different ports in the same pod.
`metricsQuery.proxy.listenPort` is exposed through the query Service;
`metricsQuery.listenPort` is loopback-only. The pinned proxy image does not
configure an upstream mTLS client certificate,
so the NGINX relay remains necessary.

The relay caches the hub Route DNS answer for 30 seconds and re-resolves it
on later requests. `metricsQuery.dnsResolver` defaults to
`dns-default.openshift-dns.svc`; override it if the spoke uses a different
resolver. The relay drops all caller headers and sets the hub `Host` header.
The tenant scope is enforced by `prom-label-proxy` before the request reaches
the relay; browser session cookies and `X-Scope-OrgID` do not cross the
spoke-to-hub boundary. The hub trusts the client certificate, so a holder of
that certificate can query the permitted Thanos read endpoints without the
spoke filter. Keep the client key available only to the relay.

The proxy permits only the data-free `/-/healthy` path without a tenant
matcher. Label discovery uses filtered `/api/v1/labels` and
`/api/v1/label/<name>/values` requests; the Thanos backend must support
`match[]` on those APIs. `/api/v1/metadata` remains unavailable because an
unfiltered metadata response could disclose other tenants' metric names and
descriptions.

When the MaaS Gateway listener selects namespaces by
`maas.opendatahub.io/gateway-access=true`, the route namespace needs that
label. With `tenantAdminNamespace.create: true`, this chart adds it to the
tenant-admin namespace. When another component owns the namespace, configure
the label there. If `metricsRoute.namespace` points elsewhere, that namespace
must be admitted by the Gateway and contain the chart's query resources.

The route's AuthPolicy validates the shared OIDC identity and requires the
organization-qualified `ai-grid-dashboard-viewer` group. Supply the live
authentication rule, issuer, audience, and a CEL `scopeExpression` that
extracts the selected organization's QGUID from verified `auth.identity`.
The chart builds the viewer-group check from that expression and the approved
OIDC `<organization-id>/<group>` format. Optional `authorization` rules can
add restrictions; they cannot remove the viewer check. The policy checks the
verified issuer and audience, rejects caller-supplied `X-Scope-OrgID`, and
injects the trusted value. Neither `admins` alone nor a static tenant ID
grants viewer access. The GET-only check appears in both the HTTPRoute and
AuthPolicy.

The Perses project is a separate authorization boundary. The running Perses
instance must grant only viewer users access to the project datasource;
Kubernetes RoleBindings do not authorize OIDC users inside Perses. Integrate
Perses authentication and project access, then verify viewer-only access
separately from datasource reconciliation. Serve Perses and `/metrics` from
the same browser origin, or configure and verify browser CORS and credentials.
The GET-only `HTTPRoute` does not match browser `OPTIONS` preflights. A
cross-origin `directUrl` request with an `Authorization` header needs separate
preflight handling before the browser will send its GET request. A successful
bearer-token GET proves the API path, not browser datasource access.

Use the shared OIDC issuer and organization claim in `metricsAuthPolicy` so the
Gateway derives the tenant header from verified identity.
