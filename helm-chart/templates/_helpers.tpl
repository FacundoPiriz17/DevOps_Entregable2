{{/* Nombre corto de la chart */}}
{{- define "playhub.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Nombre base de los recursos: si el release se llama "playhub" queda "playhub" */}}
{{- define "playhub.fullname" -}}
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

{{- define "playhub.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "playhub.labels" -}}
helm.sh/chart: {{ include "playhub.chart" . }}
app.kubernetes.io/name: {{ include "playhub.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "playhub.selectorLabels" -}}
app.kubernetes.io/name: {{ include "playhub.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/* Nombre del Secret: uno existente o el que crea la chart */}}
{{- define "playhub.secretName" -}}
{{- if .Values.secrets.existingSecret }}
{{- .Values.secrets.existingSecret }}
{{- else }}
{{- printf "%s-secrets" (include "playhub.fullname" .) }}
{{- end }}
{{- end }}
