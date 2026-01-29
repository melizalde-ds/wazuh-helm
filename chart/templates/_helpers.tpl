{{/*
Expand the name of the chart.
*/}}
{{- define "wazuh.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "wazuh.fullname" -}}
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

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "wazuh.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "wazuh.labels" -}}
helm.sh/chart: {{ include "wazuh.chart" . }}
{{ include "wazuh.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "wazuh.selectorLabels" -}}
app.kubernetes.io/name: {{ include "wazuh.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Get the issuer reference for certificates
*/}}
{{- define "wazuh.issuerRef" -}}
{{- if .Values.certificates.selfSigned -}}
name: {{ .Release.Name }}-ca-issuer
kind: Issuer
{{- else -}}
name: {{ .Values.certificates.issuerRef.name }}
kind: {{ .Values.certificates.issuerRef.kind }}
{{- end -}}
{{- end -}}


{{/*
Get the root CA secret name.
If selfSigned, use the generated name.
If external issuer, use the provided secretName.
*/}}
{{- define "wazuh.rootCASecretName" -}}
{{- if .Values.certificates.selfSigned -}}
{{- .Values.certificates.rootCA.secretName | default (printf "%s-rootca-certificate" .Release.Name) -}}
{{- else -}}
{{- required "certificates.rootCA.secretName is required when using an external issuer" .Values.certificates.rootCA.secretName -}}
{{- end -}}
{{- end -}}