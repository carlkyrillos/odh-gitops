# AI Grid observability hub

This chart packages hub-side AI Grid observability resources. The broader
feature spans multi-cluster metrics, tenant-scoped queries, and centralized
usage logs. Install the chart on the ACM hub and configure the resources for
the capabilities in use.

## Tenant metrics queries

Set `mtlsIngress.enabled: true` after creating the certificate Secrets. The
spoke chart owns the tenant label proxy; the hub chart no longer deploys one.

The query path is spoke Gateway and AuthPolicy, spoke `prom-label-proxy`, spoke
NGINX mTLS relay, hub NGINX mTLS ingress, then ACM Thanos Query. The hub
ingress verifies the spoke client certificate and forwards only GET requests
for `/-/healthy`, `/api/v1/query`, `/api/v1/query_range`,
`/api/v1/query_exemplars`, `/api/v1/series`, `/api/v1/labels`, and
`/api/v1/label/<name>/values`. It drops caller headers
and request bodies before forwarding. The hub does not apply a tenant label
matcher; that happens in the spoke proxy.

An accepted client certificate can issue unfiltered queries against these
Thanos read endpoints if it connects directly to the hub Route. Use a
dedicated client CA, issue certificates only to trusted spoke relays, and
protect their private keys. The Route is TLS passthrough, and the ingress
NetworkPolicy admits only the selected OpenShift router pods. No direct Route
to the Thanos Service is created by this chart.

Create these Secrets in the hub Helm release namespace before enabling ingress:

- `mtlsIngress.serverTLSSecretName`: `tls.crt` and `tls.key` for the exact
  `mtlsIngress.hostname`;
- `mtlsIngress.clientCASecretName`: `ca.crt` for the spoke client certificates.

Each spoke needs the matching client certificate and the hub server CA. Set
`mtlsIngress.thanosHostname` and `mtlsIngress.thanosPort` to the ACM Thanos
Query Service. The default Service is
`observability-thanos-query.open-cluster-management-observability.svc.cluster.local:9090`.
The ingress uses `mtlsIngress.dnsResolver` to follow Service address changes.

When upgrading existing releases, upgrade the spoke chart before the hub
chart. The new spoke relay drops `X-Scope-OrgID`, so the old hub proxy rejects
queries until the hub ingress is upgraded; plan for that temporary query
outage. Upgrading the hub first would let the old spoke relay reach unfiltered
Thanos through the new ingress. Verify that the spoke proxy filters two distinct
organization IDs and that direct hub access without an accepted client
certificate fails. This chart does not provide per-certificate revocation. If
a spoke client certificate is compromised, rotate the dedicated client CA,
issue new certificates to all trusted spokes, replace the hub client-CA Secret
and every spoke client-certificate Secret, and restart the ingress and relay
Deployments. Until the old CA is removed from the hub and the ingress
restarts, that certificate remains trusted.

The default router selectors match the OpenShift default ingress controller
in `openshift-ingress`. Set `mtlsIngress.routerNamespaceSelector` and
`mtlsIngress.routerPodSelector` for a different ingress controller. The
caller's verified organization ID must match the `organization_id` metric
label in Thanos; set the spoke chart's `metricsQuery.proxy.label` accordingly.
Until producer metrics with that label reach hub Thanos, tenant queries can
succeed but return no series.
