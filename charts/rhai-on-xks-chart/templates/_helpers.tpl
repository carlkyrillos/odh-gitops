{{/*
Expand the name of the chart.
*/}}
{{- define "rhai-on-xks-chart.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Internal infrastructure namespace used by ai-gateway-operator for maas-api and payload-processing.
Not user-configurable — defined here to avoid repetition across templates.
*/}}
{{- define "rhai-on-xks-chart.infrastructureNamespace" -}}
redhat-ai-gateway-infra
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "rhai-on-xks-chart.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "rhai-on-xks-chart.labels" -}}
helm.sh/chart: {{ include "rhai-on-xks-chart.chart" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.labels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Check if imagePullSecret is enabled (dockerConfigJson is provided).
*/}}
{{- define "rhai-on-xks-chart.imagePullSecretEnabled" -}}
{{- if .Values.imagePullSecret.dockerConfigJson -}}
true
{{- end -}}
{{- end -}}

{{/*
Return the imagePullSecret name.
*/}}
{{- define "rhai-on-xks-chart.imagePullSecretName" -}}
{{- .Values.imagePullSecret.name | default "rhai-pull-secret" -}}
{{- end -}}

{{/*
Render a dockerconfigjson Secret for a given namespace.
Pass a dict with "root" (top-level context), "namespace", and optional "annotations" (dict).
*/}}
{{- define "rhai-on-xks-chart.imagePullSecretResource" -}}
apiVersion: v1
kind: Secret
metadata:
  name: {{ include "rhai-on-xks-chart.imagePullSecretName" .root }}
  namespace: {{ .namespace }}
  labels:
    {{- include "rhai-on-xks-chart.labels" .root | nindent 4 }}
  {{- with .annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: {{ .root.Values.imagePullSecret.dockerConfigJson | b64enc }}
{{- end -}}

{{/*
Render imagePullSecrets block for pod specs.
Always outputs the block so that pre-created secrets are picked up.
*/}}
{{- define "rhai-on-xks-chart.imagePullSecrets" -}}
imagePullSecrets:
  - name: {{ include "rhai-on-xks-chart.imagePullSecretName" . }}
{{- end -}}

{{/*
Add the allowedRoutes block for a Gateway listener (HTTP and HTTPS).
Accepts a dict with key "allowedRoutes" (the gateway.allowedRoutes value block).
Usage:
  {{- include "rhai-on-xks-chart.gatewayAllowedRoutes" (dict "allowedRoutes" .Values.components.kserve.gateway.allowedRoutes) | nindent 6 }}
*/}}
{{- define "rhai-on-xks-chart.gatewayAllowedRoutes" -}}
{{- $ns := .allowedRoutes.namespaces -}}
{{- if and (eq $ns.from "Selector") (not $ns.selector) -}}
{{- fail "allowedRoutes.namespaces.selector is required when from is set to Selector" -}}
{{- end -}}
allowedRoutes:
  namespaces:
    from: {{ $ns.from }}
{{- if and (eq $ns.from "Selector") $ns.selector }}
    selector:
      {{- toYaml $ns.selector | nindent 6 }}
{{- end }}
{{- end -}}

{{/*
Collect dependency namespaces from enabled providers.
Pass a dict with "root" (top-level context), optional "managedOnly" (bool), and
optional "includeRhclCleanup" (bool). When managedOnly is true, only Managed
dependencies are included, except RHCL while CCM cleanup is still in progress.
RHCL's default namespaces must match the Cloud Manager defaults when no override is set.
Returns a JSON object with key "items" containing unique namespace strings.
Usage:
  (include "rhai-on-xks-chart.kubernetesEngineDependencyNamespaces" (dict "root" . "managedOnly" true) | fromJson).items
*/}}
{{- define "rhai-on-xks-chart.kubernetesEngineDependencyNamespaces" -}}
{{- $namespaces := list }}
{{- $managedOnly := .managedOnly | default false }}
{{- $includeRhclCleanup := .includeRhclCleanup | default false }}
{{- $provider := include "rhai-on-xks-chart.activeProvider" .root | fromYaml }}
{{- if and $provider (index $provider "keEnabled") }}
  {{- $provVals := index $.root.Values (index $provider "name") | default dict }}
  {{- range $depName, $dep := (dig "kubernetesEngine" "spec" "dependencies" (dict) $provVals) }}
    {{- if or (not $managedOnly) (eq (dig "managementPolicy" "" $dep) "Managed") (and (eq $depName "rhcl") $includeRhclCleanup) }}
      {{- $config := dig "configuration" (dict) $dep }}
      {{- if eq $depName "rhcl" }}
        {{- $namespaces = append $namespaces ($config.operatorNamespace | default "kuadrant-operators") }}
        {{- $namespaces = append $namespaces ($config.operandNamespace | default "kuadrant-system") }}
      {{- else }}
        {{- with (index $config "namespace") }}
          {{- $namespaces = append $namespaces . }}
        {{- end }}
      {{- end }}
    {{- end }}
  {{- end }}
{{- end }}
{{- dict "items" ($namespaces | uniq) | toJson }}
{{- end -}}

{{/* Match a CCM resource's owner reference to the current KubernetesEngine UID. */}}
{{- define "rhai-on-xks-chart.rhclResourceOwnedByKE" -}}
{{- $owned := false -}}
{{- $keUID := dig "metadata" "uid" "" .ke -}}
{{- range (dig "metadata" "ownerReferences" (list) .resource) -}}
  {{- if and $keUID (eq (index . "uid") $keUID) (eq (index . "apiVersion") "infrastructure.opendatahub.io/v1alpha1") (eq (index . "kind") (index $.provider "keKind")) (eq (index . "name") (index $.provider "keName")) -}}
    {{- $owned = true -}}
  {{- end -}}
{{- end -}}
{{- if $owned }}true{{- end -}}
{{- end -}}

{{/*
Keep RHCL pull secrets until both the KE-owned Kuadrant CR and CCM-owned workloads
in RHCL's operator namespace are gone. CCM can delete the CR before they finish
terminating. The xKS post-upgrade hook changes the KE after Helm applies regular
resources, so this check must use the live cluster state.
*/}}
{{- define "rhai-on-xks-chart.rhclCleanupPending" -}}
{{- $pending := false -}}
{{- $provider := include "rhai-on-xks-chart.activeProvider" . | fromYaml -}}
{{- if and $provider (index $provider "keEnabled") -}}
  {{- $provVals := index .Values (index $provider "name") | default dict -}}
  {{- $rhcl := dig "kubernetesEngine" "spec" "dependencies" "rhcl" (dict) $provVals -}}
  {{- if eq (dig "managementPolicy" "" $rhcl) "Unmanaged" -}}
    {{- $keCRD := lookup "apiextensions.k8s.io/v1" "CustomResourceDefinition" "" (printf "%s.infrastructure.opendatahub.io" (index $provider "keResource")) -}}
    {{- if $keCRD -}}
      {{- $ke := lookup "infrastructure.opendatahub.io/v1alpha1" (index $provider "keKind") "" (index $provider "keName") | default dict -}}
      {{- if $ke -}}
        {{- $crd := lookup "apiextensions.k8s.io/v1" "CustomResourceDefinition" "" "kuadrants.kuadrant.io" -}}
        {{- if $crd -}}
          {{- $operandNamespace := dig "configuration" "operandNamespace" "" $rhcl | default "kuadrant-system" -}}
          {{- $kuadrant := lookup "kuadrant.io/v1beta1" "Kuadrant" $operandNamespace "kuadrant" | default dict -}}
          {{- if $kuadrant -}}
            {{- $pending = eq (include "rhai-on-xks-chart.rhclResourceOwnedByKE" (dict "resource" $kuadrant "ke" $ke "provider" $provider)) "true" -}}
          {{- end -}}
        {{- end -}}
        {{- if not $pending -}}
          {{- $operatorNamespace := dig "configuration" "operatorNamespace" "" $rhcl | default "kuadrant-operators" -}}
          {{- if (lookup "v1" "Namespace" "" $operatorNamespace) -}}
            {{- range $kind := list "Deployment" "StatefulSet" "DaemonSet" "ReplicaSet" -}}
              {{- $workloads := lookup "apps/v1" $kind $operatorNamespace "" | default dict -}}
              {{- range (dig "items" (list) $workloads) -}}
                {{- if eq (include "rhai-on-xks-chart.rhclResourceOwnedByKE" (dict "resource" . "ke" $ke "provider" $provider)) "true" -}}
                  {{- $pending = true -}}
                {{- end -}}
              {{- end -}}
            {{- end -}}
          {{- end -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- if $pending }}true{{- end -}}
{{- end -}}

{{/* Render an existing namespace only when it belongs to this Helm release. */}}
{{- define "rhai-on-xks-chart.shouldRenderNamespace" -}}
{{- $existing := .existing | default dict -}}
{{- if not $existing -}}
true
{{- else -}}
  {{- $labels := dig "metadata" "labels" (dict) $existing -}}
  {{- $annotations := dig "metadata" "annotations" (dict) $existing -}}
  {{- if and (eq (index $labels "app.kubernetes.io/managed-by") "Helm") (eq (index $annotations "meta.helm.sh/release-name") .root.Release.Name) (eq (index $annotations "meta.helm.sh/release-namespace") .root.Release.Namespace) -}}
true
  {{- end -}}
{{- end -}}
{{- end -}}

{{/*
Return "true" when MaaS (modelsAsAService) is enabled and Managed.
*/}}
{{- define "rhai-on-xks-chart.maasManaged" -}}
{{- if and .Values.components.aigateway.enabled (eq (dig "spec" "modelsAsAService" "managementState" "" .Values.components.aigateway) "Managed") -}}
true
{{- end -}}
{{- end -}}

{{/*
Return the infrastructure namespace for MaaS workloads (e.g. payload-processing).
*/}}
{{- define "rhai-on-xks-chart.maasInfrastructureNamespace" -}}
redhat-ai-gateway-infra
{{- end -}}

{{/*
Return the KubernetesEngine CRD plural resource name for the active cloud provider.
*/}}
{{- define "rhai-on-xks-chart.keResourceName" -}}
{{- $provider := include "rhai-on-xks-chart.activeProvider" . | fromYaml }}
{{- if and $provider (index $provider "keEnabled") -}}
  {{- index $provider "keResource" -}}
{{- end }}
{{- end -}}

{{/*
Validate that exactly one cloud provider is enabled.
*/}}
{{- define "rhai-on-xks-chart.validateCloudProvider" -}}
{{- $registry := include "rhai-on-xks-chart.providerRegistry" . | fromYaml }}
{{- $enabledCount := 0 -}}
{{- $enabledNames := list -}}
{{- range $name := keys $registry | sortAlpha }}
  {{- $providerVals := index $.Values $name | default dict }}
  {{- if $providerVals.enabled }}
    {{- $enabledCount = add $enabledCount 1 }}
    {{- $enabledNames = append $enabledNames $name }}
  {{- end }}
{{- end }}
{{- if and .Values.enabled (eq (int $enabledCount) 0) -}}
{{- fail (printf "Exactly one cloud provider must be enabled: set %s" (join ".enabled=true, " (keys $registry | sortAlpha) | printf "%s.enabled=true")) -}}
{{- end -}}
{{- if and .Values.enabled (gt (int $enabledCount) 1) -}}
{{- fail (printf "Only one cloud provider can be enabled at a time: set either %s, not multiple" (join ".enabled=true, " $enabledNames | printf "%s.enabled=true")) -}}
{{- end -}}
{{- end -}}
