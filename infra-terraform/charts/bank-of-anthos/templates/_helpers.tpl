{{/* Return the inactive color given the active one */}}
{{- define "boa.inactiveColor" -}}
{{- if eq .Values.blueGreen.activeColor "blue" -}}green{{- else -}}blue{{- end -}}
{{- end -}}