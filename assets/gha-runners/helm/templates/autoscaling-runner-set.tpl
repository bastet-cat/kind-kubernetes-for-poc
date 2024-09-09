{{- define "gha-runners.autoscaling-runner-set" -}}
{{- $flavour := index . 0 }}
{{- $root := index . 1 }}
apiVersion: actions.github.com/v1alpha1
kind: AutoscalingRunnerSet
metadata:
  name: {{ include "gha-runners.scale-set-name" . }}
  labels:
    app.kubernetes.io/component: "autoscaling-runner-set"
    {{- include "gha-runners.labels" . | nindent 4 }}
  annotations:
    {{- include "gha-runners.annotations" . | nindent 4 }}
spec:
  githubConfigUrl: {{ include "gha-runners.githubConfigUrl" .}}
  githubConfigSecret: {{ include "gha-runners.githubsecret" . }}
  {{- with $flavour.runnerGroup }}
  runnerGroup: {{ . }}
  {{- end }}
  {{- with (include "gha-runners.scale-set-name" .) }}
  runnerScaleSetName: {{ . }}
  {{- end }}
  maxRunners: {{ include "gha-runners.maxRunners" . }}
  minRunners: {{ include "gha-runners.minRunners" . }}
  {{- with coalesce $flavour.listenerTemplate $root.Values.global.listenerTemplate }}
  listenerTemplate:
    {{- toYaml . | nindent 4}}
  {{- end }}
  template:
    {{- with ($flavour.template).metadata }}
    metadata:
      {{- with .labels }}
      labels:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .annotations }}
      annotations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
    {{- end }}
    spec:
      {{- range $key, $val := ($flavour.template).spec }}
        {{- if and (ne $key "containers") (ne $key "volumes") (ne $key "initContainers") (ne $key "serviceAccountName") }}
      {{ $key }}: {{ $val | toYaml | nindent 8 }}
        {{- end }}
      {{- end }}
      {{- if not (($flavour.template).spec).restartPolicy }}
      restartPolicy: Never
      {{- end }}
      {{- $containerMode := coalesce $flavour.containerMode $root.Values.global.containerMode }}
      {{- if eq $containerMode.type "kubernetes" }}
      serviceAccountName: {{ default (include "gha-runners.kubeModeServiceAccountName" .) (include "gha-runners.serviceAccountName" (list nil $root)) }}
      {{- else }}
      serviceAccountName: {{ default (include "gha-runners.noPermissionServiceAccountName" .) (include "gha-runners.serviceAccountName" (list nil $root)) }}
      {{- end }}
      {{- if or (coalesce (($flavour.template).spec).containers (($root.Values.global.template).spec).containers) (eq $containerMode.type "dind") }}
      initContainers:
        {{- if eq $containerMode.type "dind" }}
      - name: init-dind-externals
        {{- include "gha-runners.dind-init-container" . | nindent 8 }}
        {{- end }}
        {{- with (coalesce (($flavour.template).spec).initContainers (($root.Values.global.template).spec).initContainers) }}
      {{- toYaml . | nindent 6 }}
        {{- end }}
      {{- end }}
      containers:
      {{- if eq $containerMode.type "dind" }}
      - name: runner
        {{- include "gha-runners.dind-runner-container" . | nindent 8 }}
      - name: dind
        {{- include "gha-runners.dind-container" . | nindent 8 }}
      {{- include "gha-runners.non-runner-non-dind-containers" . | nindent 6 }}
      {{- else if eq $containerMode.type "kubernetes" }}
      - name: runner
        {{- include "gha-runners.kubernetes-mode-runner-container" $flavour | nindent 8 }}
      {{- include "gha-runners.non-runner-containers" $flavour | nindent 6 }}
      {{- else }}
      {{- include "gha-runners.default-mode-runner-containers" $flavour | nindent 6 }}
      {{- end }}
      {{- $tlsConfig := (default (dict) $root.Values.global.githubServerTLS) }}
      {{- if or ($flavour.template).spec.volumes (eq $containerMode.type "dind") (eq $containerMode.type "kubernetes") $tlsConfig.runnerMountPath }}
      volumes:
        {{- if $tlsConfig.runnerMountPath }}
          {{- include "gha-runners.tls-volume" $tlsConfig | nindent 6 }}
        {{- end }}
        {{- if eq $containerMode.type "dind" }}
          {{- include "gha-runners.dind-volume" $flavour | nindent 6 }}
          {{- include "gha-runners.dind-work-volume" . | nindent 6 }}
          {{- include "gha-runners.non-work-volumes" . | nindent 6 }}
        {{- else if eq $containerMode.type "kubernetes" }}
          {{- include "gha-runners.kubernetes-mode-work-volume" $flavour | nindent 6 }}
          {{- include "gha-runners.non-work-volumes" $flavour | nindent 6 }}
        {{- else }}
          {{- with (($flavour.template).spec).volumes }}
        {{- toYaml . | nindent 6 }}
          {{- end }}
        {{- end }}
      {{- end }}
{{- end -}}
