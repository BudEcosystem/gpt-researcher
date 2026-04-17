{{/*
Expand the name of the chart.
*/}}
{{- define "gpt-researcher.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Fully qualified app name.
*/}}
{{- define "gpt-researcher.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{- define "gpt-researcher.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "gpt-researcher.labels" -}}
helm.sh/chart: {{ include "gpt-researcher.chart" . }}
{{ include "gpt-researcher.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Base selector labels (component appended by component helpers).
*/}}
{{- define "gpt-researcher.selectorLabels" -}}
app.kubernetes.io/name: {{ include "gpt-researcher.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Component-specific helpers. Pass a dict: (dict "ctx" . "component" "backend")
*/}}
{{- define "gpt-researcher.componentName" -}}
{{- printf "%s-%s" (include "gpt-researcher.fullname" .ctx) .component | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "gpt-researcher.componentLabels" -}}
{{ include "gpt-researcher.labels" .ctx }}
app.kubernetes.io/component: {{ .component }}
{{- end }}

{{- define "gpt-researcher.componentSelectorLabels" -}}
{{ include "gpt-researcher.selectorLabels" .ctx }}
app.kubernetes.io/component: {{ .component }}
{{- end }}

{{/*
ServiceAccount name.
*/}}
{{- define "gpt-researcher.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "gpt-researcher.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Resolve image reference honoring global.imageRegistry, image.tag fallback,
and optional image.tagSuffix (e.g. "-full").
Pass a dict: (dict "image" .Values.backend.image "ctx" .)
*/}}
{{- define "gpt-researcher.image" -}}
{{- $registry := .ctx.Values.global.imageRegistry | default "" -}}
{{- $repo := .image.repository -}}
{{- $tag := default .ctx.Chart.AppVersion .image.tag -}}
{{- $suffix := .image.tagSuffix | default "" -}}
{{- if $registry -}}
{{ $registry }}/{{ $repo }}:{{ $tag }}{{ $suffix }}
{{- else -}}
{{ $repo }}:{{ $tag }}{{ $suffix }}
{{- end -}}
{{- end }}

{{/*
Secret name to reference in envFrom (existing, external, or rendered).
*/}}
{{- define "gpt-researcher.secretName" -}}
{{- if .Values.secrets.existingSecret -}}
{{ .Values.secrets.existingSecret }}
{{- else if .Values.secrets.externalSecrets.enabled -}}
{{ include "gpt-researcher.fullname" . }}-secrets
{{- else if .Values.secrets.create -}}
{{ include "gpt-researcher.fullname" . }}-secrets
{{- end -}}
{{- end }}

{{/*
ConfigMap name.
*/}}
{{- define "gpt-researcher.configMapName" -}}
{{ include "gpt-researcher.fullname" . }}-config
{{- end }}

{{/*
envFrom block — combines ConfigMap and Secret refs (if a secret name exists).
*/}}
{{- define "gpt-researcher.envFrom" -}}
- configMapRef:
    name: {{ include "gpt-researcher.configMapName" . }}
{{- $secretName := include "gpt-researcher.secretName" . }}
{{- if $secretName }}
- secretRef:
    name: {{ $secretName }}
{{- end }}
{{- end }}

{{/*
imagePullSecrets block honoring global override.
*/}}
{{- define "gpt-researcher.imagePullSecrets" -}}
{{- with .Values.global.imagePullSecrets }}
imagePullSecrets:
{{ toYaml . | indent 2 }}
{{- end }}
{{- end }}

{{/*
PVC name for a backend persistence entry. Accepts dict: (dict "ctx" . "key" "myDocs" "volume" "my-docs")
*/}}
{{- define "gpt-researcher.pvcName" -}}
{{- $p := index .ctx.Values.backend.persistence .key -}}
{{- if $p.existingClaim -}}
{{ $p.existingClaim }}
{{- else -}}
{{ include "gpt-researcher.fullname" .ctx }}-{{ .volume }}
{{- end -}}
{{- end }}
