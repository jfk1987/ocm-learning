{{- define "target-application.name" -}}
target-application
{{- end -}}

{{- define "target-application.labels" -}}
app.kubernetes.io/name: {{ include "target-application.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end -}}

