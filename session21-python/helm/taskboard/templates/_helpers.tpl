{{/*
Resource name prefix. Release "taskboard" -> "taskboard", release "demo" -> "demo-taskboard".
*/}}
{{- define "taskboard.fullname" -}}
{{- if contains .Chart.Name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end }}
