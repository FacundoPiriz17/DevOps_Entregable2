{{/* Nombre corto de la chart */}}
{{- define "playhub.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Los permisos de nodos son globales, incluso entre releases de distinto namespace. */}}
{{- define "playhub.monitoring.clusterRoleName" -}}
{{- $name := printf "%s-%s-prometheus-nodes" (include "playhub.fullname" .) .Release.Namespace -}}
{{- if gt (len $name) 63 -}}
{{- printf "%s-%s" ($name | trunc 54 | trimSuffix "-") ($name | sha256sum | trunc 8) -}}
{{- else -}}
{{- $name -}}
{{- end -}}
{{- end -}}

{{/* Conserva los UID de Grafana y adapta solo las consultas al release. */}}
{{- define "playhub.monitoring.nodeExporterPort" -}}
{{- if .Values.monitoring.nodeExporter.port -}}
{{- $port := int .Values.monitoring.nodeExporter.port -}}
{{- if or (lt $port 1) (gt $port 65535) -}}
{{- fail "monitoring.nodeExporter.port debe estar entre 1 y 65535, o ser 0 para seleccion automatica" -}}
{{- end -}}
{{- $port -}}
{{- else -}}
{{- $identity := printf "%s/%s" .Release.Namespace (include "playhub.fullname" .) -}}
{{- add 10000 (mod ($identity | adler32sum | atoi) 20000) -}}
{{- end -}}
{{- end -}}

{{/* Los nombres del dashboard y de la fuente de datos no dependen del release. */}}
{{- define "playhub.monitoring.adaptQueries" -}}
{{- $base := include "playhub.fullname" .root -}}
{{- $content := replace "playhub-backend" (printf "%s-backend" $base) .content -}}
{{- $content = replace "playhub-active-http" (printf "%s-active-http" $base) $content -}}
{{- $content = replace "playhub-.*" (printf "%s-.*" $base) $content -}}
{{- $content -}}
{{- end -}}

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
