{{- define "gha-base-name" -}}
gha-rs
{{- end }}

{{- define "gha-runners.org" -}}
{{- $flavour := (index . 0) }}
{{- $root := (index . 1) }}
{{- $root.Values.global.org }}
{{- end }}

{{- define "gha-runners.environment" -}}
{{- $flavour := (index . 0) }}
{{- $root := (index . 1) }}
{{- $root.Values.global.environment }}
{{- end }}

{{- define "gha-runners.flavour-name" -}}
{{- $flavour := (index . 0) }}
{{- $root := (index . 1) }}
{{- coalesce ($flavour.repository) ($flavour).name | default "" }}
{{- end }}

{{- define "gha-runners.name" -}}
{{- $flavour := (index . 0) }}
{{- $root := (index . 1) }}
{{- $name := default (include "gha-base-name" .) $root.Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- printf "%s-%s-%s" (include "gha-runners.org" .) $name (include "gha-runners.flavour-name" .) }}
{{- end }}

{{- define "gha-runners.resources-name-prefix" -}}
{{- $root := (index . 1) }}
{{- default (include "gha-base-name" .) $root.Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "gha-runners.resources-name-suffix" -}}
{{- $flavour := (index . 0) }}
{{- $root := (index . 1) }}
{{- $org := include "gha-runners.org" . }}
{{- $name := default (include "gha-base-name" .) $root.Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- $env := include "gha-runners.environment" . }}
{{- $flavourName := include "gha-runners.flavour-name" . | trimSuffix "-" | printf "%s-" | trimPrefix "-"}}
{{- printf "%s-%s%s" $org $flavourName $env }}
{{- end }}

{{- define "gha-runners.scale-set-name" -}}
{{- printf "%s-runners-%s" (include "gha-runners.resources-name-prefix" .) (include "gha-runners.resources-name-suffix" .) }}
{{- end }}

// fullname
{{- define "gha-runners.fullname" -}}
{{- $name := (include "gha-base-name" .) }}
{{- printf "%s-%s" $name (include "gha-runners.scale-set-name" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

// Chart Name
{{- define "gha-runners.chart" -}}
{{- $flavour := (index . 0) }}
{{- $root := (index . 1) }}
{{- printf "%s-%s" (include "gha-base-name" .) $root.Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

// Common Labels
{{- define "gha-runners.labels" -}}
{{- $flavour := (index . 0) -}}
{{- $root := (index . 1) -}}
{{ include "gha-runners.selectorLabels" . }}
{{- if $root.Chart.AppVersion }}
app.kubernetes.io/version: {{ $root.Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ $root.Release.Service }}
app.kubernetes.io/part-of: gha-rs
actions.github.com/scale-set-name: {{ include "gha-runners.scale-set-name" . }}
actions.github.com/scale-set-namespace: {{ $root.Release.Namespace }}
{{- range $key, $value := $root.Values.global.extraLabels }}
{{ $key }}: {{ $value | quote }}
{{- end }}
{{- end }}

// Selector Labels
{{- define "gha-runners.selectorLabels" -}}
app.kubernetes.io/name: {{ include "gha-runners.scale-set-name" . }}
app.kubernetes.io/instance: {{ include "gha-runners.scale-set-name" . }}
{{- end }}

// Annotations
{{- define "gha-runners.annotations" -}}
{{- $flavour := (index . 0) }}
{{- $root := (index . 1) -}}
actions.github.com/values-hash: {{ $root | toJson | sha256sum | trunc 63 }}
{{- $containerMode := coalesce ($flavour).containerMode ($root.Values.global).containerMode }}
actions.github.com/cleanup-manager-role-binding: {{ include "gha-runners.managerRoleBindingName" . }}
actions.github.com/cleanup-manager-role-name: {{ include "gha-runners.managerRoleName" . }}
{{- if and $containerMode (eq $containerMode.type "kubernetes") (not (($flavour.template).spec).serviceAccountName) }}
actions.github.com/cleanup-kubernetes-mode-role-binding-name: {{ include "gha-runners.kubeModeRoleBindingName" . }}
actions.github.com/cleanup-kubernetes-mode-role-name: {{ include "gha-runners.kubeModeRoleName" . }}
actions.github.com/cleanup-kubernetes-mode-service-account-name: {{ include "gha-runners.kubeModeServiceAccountName" . }}
{{- end }}
{{- if and (ne $containerMode.type "kubernetes") (not (($flavour.template).spec).serviceAccountName) }}
actions.github.com/cleanup-no-permission-service-account-name: {{ include "gha-runners.noPermissionServiceAccountName" . }}
{{- end }}
{{- range $key, $value := $root.Values.global.extraAnnotations }}
{{ $key }}: {{ $value | quote }}
{{- end }}
{{- range $key, $value := ($flavour).extraAnnotations }}
{{ $key }}: {{ $value | quote }}
{{- end }}
{{- end }}

// githubConfigUrl
{{- define "gha-runners.githubConfigUrl" }}
{{- $flavour := (index . 0) }}
{{- $root := (index . 1) -}}
{{- $url := required ".Values.global.githubConfigUrl is required" (trimSuffix "/" $root.Values.global.githubConfigUrl) }}
{{- if ($flavour.repository) }}
{{- $url = printf "%s/%s" $url $flavour.repository }}
{{- end }}
{{- $url }}
{{- end }}

// githubsecret
{{- define "gha-runners.githubsecret" -}}
{{- $root := (index . 1) }}
{{- $ := (list nil $root) }}
{{- printf "%s-secret-%s" (include "gha-runners.resources-name-prefix" $) (include "gha-runners.resources-name-suffix" $) }}
{{- end }}

// maxRunners
{{- define "gha-runners.maxRunners" -}}
{{- $flavour := (index . 0) }}
{{- $root := (index . 1) }}
{{- if (not (eq $flavour.maxRunners nil)) }}
{{- $flavour.maxRunners | int }}
{{- else }}
{{- if (not (eq $root.Values.global.maxRunners nil)) }}
{{- $root.Values.global.maxRunners | int }}
{{- else }}
{{- 0 | int }}
{{- end }}
{{- end }}
{{- end }}

// minRunners
{{- define "gha-runners.minRunners" -}}
{{- $flavour := (index . 0) }}
{{- $root := (index . 1) }}
{{- if (not (eq $flavour.minRunners nil)) }}
{{- $flavour.minRunners | int }}
{{- else }}
{{- if (not (eq $root.Values.global.minRunners nil)) }}
{{- $root.Values.global.minRunners | int }}
{{- else }}
{{- 0 | int }}
{{- end }}
{{- end }}
{{- end }}

// serviceAccountName
{{- define "gha-runners.serviceAccountName" -}}
{{- $root := (index . 1) }}
{{- $ := (list nil $root) }}
{{- printf "%s-sa-%s" (include "gha-runners.resources-name-prefix" $) (include "gha-runners.resources-name-suffix" $) }}
{{- end }}

// noPermissionServiceAccountName
{{- define "gha-runners.noPermissionServiceAccountName" -}}
{{- include "gha-runners.fullname" . }}-no-permission
{{- end }}

// kubeModeRoleName
{{- define "gha-runners.kubeModeRoleName" -}}
{{- include "gha-runners.fullname" . }}-kube-mode
{{- end }}

// kubeModeRoleBindingName
{{- define "gha-runners.kubeModeRoleBindingName" -}}
{{- include "gha-runners.fullname" . }}-kube-mode
{{- end }}

// kubeModeServiceAccountName
{{- define "gha-runners.kubeModeServiceAccountName" -}}
{{- include "gha-runners.fullname" . }}-kube-mode
{{- end }}

// dind-init-container
{{- define "gha-runners.dind-init-container" -}}
{{- $flavour := (index . 0) }}
{{- $root := (index . 1) }}
{{- range $i, $val := ((coalesce $flavour.template $root.Values.global.template).spec).containers }}
  {{- if eq $val.name "runner" -}}
image: {{ $val.image }}
command: ["cp"]
args: ["-r", "-v", "/home/runner/exgha-runners.dind-init-containerternals/.", "/home/runner/tmpDir/"]
volumeMounts:
  - name: dind-externals
    mountPath: /home/runner/tmpDir
  {{- end }}
{{- end -}}
{{- end -}}

// dind-container
{{- define "gha-runners.dind-container" -}}
image: docker:dind
args:
  - dockerd
  - --host=unix:///var/run/docker.sock
  - --group=$(DOCKER_GROUP_GID)
env:
  - name: DOCKER_GROUP_GID
    value: "123"
securityContext:
  privileged: true
volumeMounts:
  - name: work
    mountPath: /home/runner/_work
  - name: dind-sock
    mountPath: /var/run
  - name: dind-externals
    mountPath: /home/runner/externals
{{- end }}

// dind-volume
{{- define "gha-runners.dind-volume" -}}
- name: dind-sock
  emptyDir: {}
- name: dind-externals
  emptyDir: {}
{{- end }}

// tls-volume
{{- define "gha-runners.tls-volume" -}}
- name: github-server-tls-cert
  configMap:
    name: {{ .certificateFrom.configMapKeyRef.name }}
    items:
      - key: {{ .certificateFrom.configMapKeyRef.key }}
        path: {{ .certificateFrom.configMapKeyRef.key }}
{{- end }}

// dind-work-volume
{{- define "gha-runners.dind-work-volume" -}}
{{- $flavour := (index . 0) }}
{{- $root := (index . 1) -}}
{{- $createWorkVolume := 1 }}
  {{- range $i, $volume := ((coalesce $flavour.template $root.Values.global.template).spec).volumes }}
    {{- if eq $volume.name "work" }}
      {{- $createWorkVolume = 0 }}
- {{ $volume | toYaml | nindent 2 }}
    {{- end }}
  {{- end }}
  {{- if eq $createWorkVolume 1 }}
- name: work
  emptyDir: {}
  {{- end }}
{{- end }}

// kubernetes-mode-work-volume
{{- define "gha-runners.kubernetes-mode-work-volume" -}}
{{- $flavour := (index . 0) }}
{{- $root := (index . 1) -}}
{{- $createWorkVolume := 1 }}
  {{- range $i, $volume := ((coalesce $flavour.template $root.Values.global.template).spec).volumes }}
    {{- if eq $volume.name "work" }}
      {{- $createWorkVolume = 0 }}
- {{ $volume | toYaml | nindent 2 }}
    {{- end }}
  {{- end }}
  {{- if eq $createWorkVolume 1 }}
- name: work
  ephemeral:
    volumeClaimTemplate:
      spec:
        {{- .containerMode.kubernetesModeWorkVolumeClaim | toYaml | nindent 8 }}
  {{- end }}
{{- end }}

// non-work-volumes
{{- define "gha-runners.non-work-volumes" -}}
{{- $flavour := (index . 0) }}
{{- $root := (index . 1) -}}
  {{- range $i, $volume := ((coalesce $flavour.template $root.Values.global.template).spec).volumes }}
    {{- if ne $volume.name "work" }}
- {{ $volume | toYaml | nindent 2 }}
    {{- end }}
  {{- end }}
{{- end }}

// non-runner-containers
{{- define "gha-runners.non-runner-containers" -}}
{{- $flavour := (index . 0) }}
{{- $root := (index . 1) -}}
  {{- range $i, $container := ((coalesce $flavour.template $root.Values.global.template).spec).containers }}
    {{- if ne $container.name "runner" }}
- {{ $container | toYaml | nindent 2 }}
    {{- end }}
  {{- end }}
{{- end }}

{{- define "gha-runners.non-runner-non-dind-containers" -}}
{{- $flavour := (index . 0) }}
{{- $root := (index . 1) -}}
  {{- range $i, $container := ((coalesce $flavour.template $root.Values.global.template).spec).containers }}
    {{- if and (ne $container.name "runner") (ne $container.name "dind") }}
- {{ $container | toYaml | nindent 2 }}
    {{- end }}
  {{- end }}
{{- end }}

{{- define "gha-runners.dind-runner-container" -}}
{{- $flavour := (index . 0) }}
{{- $root := (index . 1) -}}
{{- $tlsConfig := (default (dict) ((coalesce $flavour $root.Values.global).githubServerTLS)) }}
{{- range $i, $container := ((coalesce $flavour.template $root.Values.global.template).spec).containers -}}
  {{- if eq $container.name "runner" }}
    {{- range $key, $val := $container }}
      {{- if and (ne $key "env") (ne $key "volumeMounts") (ne $key "name") }}
{{ $key }}: {{ $val | toYaml | nindent 2 }}
      {{- end }}
    {{- end }}
    {{- $setDockerHost := 1 }}
    {{- $setRunnerWaitDocker := 1 }}
    {{- $setNodeExtraCaCerts := 0 }}
    {{- $setRunnerUpdateCaCerts := 0 }}
    {{- if $tlsConfig.runnerMountPath }}
      {{- $setNodeExtraCaCerts = 1 }}
      {{- $setRunnerUpdateCaCerts = 1 }}
    {{- end }}
{{- if or (coalesce $flavour $root.Values.global).cpu (coalesce $flavour $root.Values.global).memory }}
resources:
    {{- if $container.resources }}
{{ $container.resources | toYaml | indent 2 }}
    {{ else }}
    requests:
      cpu: {{ (coalesce $flavour $root.Values.global).cpu }}
      memory: {{ (coalesce $flavour $root.Values.global).memory }}
    limits:
      memory: {{ (coalesce $flavour $root.Values.global).memory }}
    {{- end }}
{{- end }}
env:
    {{- with $container.env }}
      {{- range $i, $env := . }}
        {{- if eq $env.name "DOCKER_HOST" }}
          {{- $setDockerHost = 0 }}
        {{- end }}
        {{- if eq $env.name "RUNNER_WAIT_FOR_DOCKER_IN_SECONDS" }}
          {{- $setRunnerWaitDocker = 0 }}
        {{- end }}
        {{- if eq $env.name "NODE_EXTRA_CA_CERTS" }}
          {{- $setNodeExtraCaCerts = 0 }}
        {{- end }}
        {{- if eq $env.name "RUNNER_UPDATE_CA_CERTS" }}
          {{- $setRunnerUpdateCaCerts = 0 }}
        {{- end }}
      {{- end }}
{{ $container.env | toYaml | indent 2 }}
    {{- end }}
    {{- if $setDockerHost }}
  - name: DOCKER_HOST
    value: unix:///var/run/docker.sock
    {{- end }}
    {{- if $setRunnerWaitDocker }}
  - name: RUNNER_WAIT_FOR_DOCKER_IN_SECONDS
    value: "120"
    {{- end }}
    {{- if $setNodeExtraCaCerts }}
  - name: NODE_EXTRA_CA_CERTS
    value: {{ clean (print $tlsConfig.runnerMountPath "/" $tlsConfig.certificateFrom.configMapKeyRef.key) }}
    {{- end }}
    {{- if $setRunnerUpdateCaCerts }}
  - name: RUNNER_UPDATE_CA_CERTS
    value: "1"
    {{- end }}
    {{- $mountWork := 1 }}
    {{- $mountDindCert := 1 }}
    {{- $mountGitHubServerTLS := 0 }}
    {{- if $tlsConfig.runnerMountPath }}
      {{- $mountGitHubServerTLS = 1 }}
    {{- end }}
volumeMounts:
    {{- with $container.volumeMounts }}
      {{- range $i, $volMount := . -}}
        {{- if eq $volMount.name "work" }}
          {{- $mountWork = 0 }}
        {{- end }}
        {{- if eq $volMount.name "dind-sock" }}
          {{- $mountDindCert = 0 }}
        {{- end }}
        {{- if eq $volMount.name "github-server-tls-cert" }}
          {{- $mountGitHubServerTLS = 0 }}
        {{- end }}
      {{- end -}}
{{ $container.volumeMounts | toYaml | nindent 2 }}
    {{- end }}
    {{- if $mountWork }}
  - name: work
    mountPath: /home/runner/_work
    {{- end }}
    {{- if $mountDindCert }}
  - name: dind-sock
    mountPath: /var/run
    {{- end }}
    {{- if $mountGitHubServerTLS }}
  - name: github-server-tls-cert
    mountPath: {{ clean (print $tlsConfig.runnerMountPath "/" $tlsConfig.certificateFrom.configMapKeyRef.key) }}
    subPath: {{ $tlsConfig.certificateFrom.configMapKeyRef.key }}
    {{- end }}
  {{- end }}
{{- end -}}
{{- end -}}

{{- define "gha-runners.kubernetes-mode-runner-container" -}}
{{- $flavour := (index . 0) }}
{{- $root := (index . 1) }}
{{- $tlsConfig := (default (dict) (coalesce $flavour $root.Values.global).githubServerTLS) }}
{{- range $i, $container := (((coalesce $flavour $root.Values.global).template).spec).containers }}
  {{- if eq $container.name "runner" }}
    {{- range $key, $val := $container }}
      {{- if and (ne $key "env") (ne $key "volumeMounts") (ne $key "name") }}
{{ $key }}: {{ $val | toYaml | nindent 2 }}
      {{- end }}
    {{- end }}
    {{- $setContainerHooks := 1 }}
    {{- $setPodName := 1 }}
    {{- $setRequireJobContainer := 1 }}
    {{- $setNodeExtraCaCerts := 0 }}
    {{- $setRunnerUpdateCaCerts := 0 }}
    {{- if $tlsConfig.runnerMountPath }}
      {{- $setNodeExtraCaCerts = 1 }}
      {{- $setRunnerUpdateCaCerts = 1 }}
    {{- end }}
env:
    {{- with $container.env }}
      {{- range $i, $env := . }}
        {{- if eq $env.name "ACTIONS_RUNNER_CONTAINER_HOOKS" }}
          {{- $setContainerHooks = 0 }}
        {{- end }}
        {{- if eq $env.name "ACTIONS_RUNNER_POD_NAME" }}
          {{- $setPodName = 0 }}
        {{- end }}
        {{- if eq $env.name "ACTIONS_RUNNER_REQUIRE_JOB_CONTAINER" }}
          {{- $setRequireJobContainer = 0 }}
        {{- end }}
        {{- if eq $env.name "NODE_EXTRA_CA_CERTS" }}
          {{- $setNodeExtraCaCerts = 0 }}
        {{- end }}
        {{- if eq $env.name "RUNNER_UPDATE_CA_CERTS" }}
          {{- $setRunnerUpdateCaCerts = 0 }}
        {{- end }}
  - {{ $env | toYaml | nindent 4 }}
      {{- end }}
    {{- end }}
    {{- if $setContainerHooks }}
  - name: ACTIONS_RUNNER_CONTAINER_HOOKS
    value: /home/runner/k8s/index.js
    {{- end }}
    {{- if $setPodName }}
  - name: ACTIONS_RUNNER_POD_NAME
    valueFrom:
      fieldRef:
        fieldPath: metadata.name
    {{- end }}
    {{- if $setRequireJobContainer }}
  - name: ACTIONS_RUNNER_REQUIRE_JOB_CONTAINER
    value: "true"
    {{- end }}
    {{- if $setNodeExtraCaCerts }}
  - name: NODE_EXTRA_CA_CERTS
    value: {{ clean (print $tlsConfig.runnerMountPath "/" $tlsConfig.certificateFrom.configMapKeyRef.key) }}
    {{- end }}
    {{- if $setRunnerUpdateCaCerts }}
  - name: RUNNER_UPDATE_CA_CERTS
    value: "1"
    {{- end }}
    {{- $mountWork := 1 }}
    {{- $mountGitHubServerTLS := 0 }}
    {{- if $tlsConfig.runnerMountPath }}
      {{- $mountGitHubServerTLS = 1 }}
    {{- end }}
volumeMounts:
    {{- with $container.volumeMounts }}
      {{- range $i, $volMount := . }}
        {{- if eq $volMount.name "work" }}
          {{- $mountWork = 0 }}
        {{- end }}
        {{- if eq $volMount.name "github-server-tls-cert" }}
          {{- $mountGitHubServerTLS = 0 }}
        {{- end }}
  - {{ $volMount | toYaml | nindent 4 }}
      {{- end }}
    {{- end }}
    {{- if $mountWork }}
  - name: work
    mountPath: /home/runner/_work
    {{- end }}
    {{- if $mountGitHubServerTLS }}
  - name: github-server-tls-cert
    mountPath: {{ clean (print $tlsConfig.runnerMountPath "/" $tlsConfig.certificateFrom.configMapKeyRef.key) }}
    subPath: {{ $tlsConfig.certificateFrom.configMapKeyRef.key }}
    {{- end }}
  {{- end }}
{{- end }}
{{- end }}

// default-mode-runner-containers
{{- define "gha-runners.default-mode-runner-containers" -}}
{{- $flavour := (index . 0) }}
{{- $root := (index . 1) }}
{{- $tlsConfig := (default (dict) (coalesce $flavour $root.Values.global).githubServerTLS) }}
{{- if $flavour.template }}
{{- range $i, $container := ((coalesce $flavour $root.Values.global).template).spec.containers }}
{{- if ne $container.name "runner" }}
- {{ $container | toYaml | nindent 2 }}
{{- else }}
- name: {{ $container.name }}
  {{- range $key, $val := $container }}
    {{- if and (ne $key "env") (ne $key "volumeMounts") (ne $key "name") }}
  {{ $key }}: {{ $val | toYaml | nindent 4 }}
    {{- end }}
  {{- end }}
  {{- $setNodeExtraCaCerts := 0 }}
  {{- $setRunnerUpdateCaCerts := 0 }}
  {{- if $tlsConfig.runnerMountPath }}
    {{- $setNodeExtraCaCerts = 1 }}
    {{- $setRunnerUpdateCaCerts = 1 }}
  {{- end }}

  {{- $mountGitHubServerTLS := 0 }}
  {{- if or $container.env $setNodeExtraCaCerts $setRunnerUpdateCaCerts }}
  env:
    {{- with $container.env }}
      {{- range $i, $env := . }}
        {{- if eq $env.name "NODE_EXTRA_CA_CERTS" }}
          {{- $setNodeExtraCaCerts = 0 }}
        {{- end }}
        {{- if eq $env.name "RUNNER_UPDATE_CA_CERTS" }}
          {{- $setRunnerUpdateCaCerts = 0 }}
        {{- end }}
    - {{ $env | toYaml | nindent 6 }}
      {{- end }}
    {{- end }}
    {{- if $setNodeExtraCaCerts }}
    - name: NODE_EXTRA_CA_CERTS
      value: {{ clean (print $tlsConfig.runnerMountPath "/" $tlsConfig.certificateFrom.configMapKeyRef.key) }}
    {{- end }}
    {{- if $setRunnerUpdateCaCerts }}
    - name: RUNNER_UPDATE_CA_CERTS
      value: "1"
    {{- end }}
    {{- if $tlsConfig.runnerMountPath }}
      {{- $mountGitHubServerTLS = 1 }}
    {{- end }}
  {{- end }}

  {{- if or $container.volumeMounts $mountGitHubServerTLS }}
  volumeMounts:
    {{- with $container.volumeMounts }}
      {{- range $i, $volMount := . }}
        {{- if eq $volMount.name "github-server-tls-cert" }}
          {{- $mountGitHubServerTLS = 0 }}
        {{- end }}(coalesce $flavour $root.Values.global)
    - {{ $volMount | toYaml | nindent 6 }}
      {{- end }}
    {{- end }}
    {{- if $mountGitHubServerTLS }}
    - name: github-server-tls-cert
      mountPath: {{ clean (print $tlsConfig.runnerMountPath "/" $tlsConfig.certificateFrom.configMapKeyRef.key) }}
      subPath: {{ $tlsConfig.certificateFrom.configMapKeyRef.key }}
    {{- end }}
  {{- end}}
  {{- end }}
  {{- end }}
{{- end }}
{{- end }}

{{- define "gha-runners.managerRoleName" -}}
{{- include "gha-runners.fullname" . }}-manager
{{- end }}

{{- define "gha-runners.managerRoleBindingName" -}}
{{- include "gha-runners.fullname" . }}-manager
{{- end }}

{{- define "gha-runners.managerServiceAccountName" -}}
{{- $flavour := (index . 0) }}
{{- $root := (index . 1) }}
{{- $searchControllerDeployment := 1 }}
{{- if (coalesce $flavour $root.Values.global).controllerServiceAccount }}
  {{- if (coalesce $flavour $root.Values.global).controllerServiceAccount.name }}
    {{- $searchControllerDeployment = 0 }}
{{- (coalesce $flavour $root.Values.global).controllerServiceAccount.name }}
  {{- end }}
{{- end }}
{{- if eq $searchControllerDeployment 1 }}
  {{- $multiNamespacesCounter := 0 }}
  {{- $singleNamespaceCounter := 0 }}
  {{- $controllerDeployment := dict }}
  {{- $singleNamespaceControllerDeployments := dict }}
  {{- $managerServiceAccountName := "" }}
  {{- range $index, $deployment := (lookup "apps/v1" "Deployment" "" "").items }}
    {{- if kindIs "map" $deployment.metadata.labels }}
      {{- if eq (get $deployment.metadata.labels "app.kubernetes.io/part-of") "gha-rs-controller" }}
        {{- if hasKey $deployment.metadata.labels "actions.github.com/controller-watch-single-namespace" }}
          {{- $singleNamespaceCounter = add $singleNamespaceCounter 1 }}
          {{- $_ := set $singleNamespaceControllerDeployments (get $deployment.metadata.labels "actions.github.com/controller-watch-single-namespace") $deployment}}
        {{- else }}
          {{- $multiNamespacesCounter = add $multiNamespacesCounter 1 }}
          {{- $controllerDeployment = $deployment }}
        {{- end }}
      {{- end }}
    {{- end }}
  {{- end }}
  {{- if and (eq $multiNamespacesCounter 0) (eq $singleNamespaceCounter 0) }}
    {{- fail "No gha-rs-controller deployment found using label (app.kubernetes.io/part-of=gha-rs-controller). Consider setting controllerServiceAccount.name in values.yaml to be explicit if you think the discovery is wrong." }}
  {{- end }}
  {{- if and (gt $multiNamespacesCounter 0) (gt $singleNamespaceCounter 0) }}
    {{- fail "Found both gha-rs-controller installed with flags.watchSingleNamespace set and unset in cluster, this is not supported. Consider setting controllerServiceAccount.name in values.yaml to be explicit if you think the discovery is wrong." }}
  {{- end }}
  {{- if gt $multiNamespacesCounter 1 }}
    {{- fail "More than one gha-rs-controller deployment found using label (app.kubernetes.io/part-of=gha-rs-controller). Consider setting controllerServiceAccount.name in values.yaml to be explicit if you think the discovery is wrong." }}
  {{- end }}
  {{- if eq $multiNamespacesCounter 1 }}
    {{- with $controllerDeployment.metadata }}
      {{- $managerServiceAccountName = (get $controllerDeployment.metadata.labels "actions.github.com/controller-service-account-name") }}
    {{- end }}
  {{- else if gt $singleNamespaceCounter 0 }}
    {{- if hasKey $singleNamespaceControllerDeployments $root.Release.Namespace }}
      {{- $controllerDeployment = get $singleNamespaceControllerDeployments $root.Release.Namespace }}
      {{- with $controllerDeployment.metadata }}
        {{- $managerServiceAccountName = (get $controllerDeployment.metadata.labels "actions.github.com/controller-service-account-name") }}
      {{- end }}
    {{- else }}
      {{- fail "No gha-rs-controller deployment that watch this namespace found using label (actions.github.com/controller-watch-single-namespace). Consider setting controllerServiceAccount.name in values.yaml to be explicit if you think the discovery is wrong." }}
    {{- end }}
  {{- end }}
  {{- if eq $managerServiceAccountName "" }}
    {{- fail "No service account name found for gha-rs-controller deployment using label (actions.github.com/controller-service-account-name), consider setting controllerServiceAccount.name in values.yaml to be explicit if you think the discovery is wrong." }}
  {{- end }}
{{- $managerServiceAccountName }}
{{- end }}
{{- end }}

{{- define "gha-runners.managerServiceAccountNamespace" -}}
{{- $flavour := (index . 0) }}
{{- $root := (index . 1) }}
{{- $searchControllerDeployment := 1 }}
{{- if (coalesce $flavour $root.Values.global).controllerServiceAccount }}
  {{- if (coalesce $flavour $root.Values.global).controllerServiceAccount.namespace }}
    {{- $searchControllerDeployment = 0 }}
{{- (coalesce $flavour $root.Values.global).controllerServiceAccount.namespace }}
  {{- end }}
{{- end }}
{{- if eq $searchControllerDeployment 1 }}
  {{- $multiNamespacesCounter := 0 }}
  {{- $singleNamespaceCounter := 0 }}
  {{- $controllerDeployment := dict }}
  {{- $singleNamespaceControllerDeployments := dict }}
  {{- $managerServiceAccountNamespace := "" }}
  {{- range $index, $deployment := (lookup "apps/v1" "Deployment" "" "").items }}
    {{- if kindIs "map" $deployment.metadata.labels }}
      {{- if eq (get $deployment.metadata.labels "app.kubernetes.io/part-of") "gha-rs-controller" }}
        {{- if hasKey $deployment.metadata.labels "actions.github.com/controller-watch-single-namespace" }}
          {{- $singleNamespaceCounter = add $singleNamespaceCounter 1 }}
          {{- $_ := set $singleNamespaceControllerDeployments (get $deployment.metadata.labels "actions.github.com/controller-watch-single-namespace") $deployment}}
        {{- else }}
          {{- $multiNamespacesCounter = add $multiNamespacesCounter 1 }}
          {{- $controllerDeployment = $deployment }}
        {{- end }}
      {{- end }}
    {{- end }}
  {{- end }}
  {{- if and (eq $multiNamespacesCounter 0) (eq $singleNamespaceCounter 0) }}
    {{- fail "No gha-rs-controller deployment found using label (app.kubernetes.io/part-of=gha-rs-controller). Consider setting controllerServiceAccount.namespace in values.yaml to be explicit if you think the discovery is wrong." }}
  {{- end }}
  {{- if and (gt $multiNamespacesCounter 0) (gt $singleNamespaceCounter 0) }}
    {{- fail "Found both gha-rs-controller installed with flags.watchSingleNamespace set and unset in cluster, this is not supported. Consider setting controllerServiceAccount.namespace in values.yaml to be explicit if you think the discovery is wrong." }}
  {{- end }}
  {{- if gt $multiNamespacesCounter 1 }}
    {{- fail "More than one gha-rs-controller deployment found using label (app.kubernetes.io/part-of=gha-rs-controller). Consider setting controllerServiceAccount.namespace in values.yaml to be explicit if you think the discovery is wrong." }}
  {{- end }}
  {{- if eq $multiNamespacesCounter 1 }}
    {{- with $controllerDeployment.metadata }}
      {{- $managerServiceAccountNamespace = (get $controllerDeployment.metadata.labels "actions.github.com/controller-service-account-namespace") }}
    {{- end }}
  {{- else if gt $singleNamespaceCounter 0 }}
    {{- if hasKey $singleNamespaceControllerDeployments .Release.Namespace }}
      {{- $controllerDeployment = get $singleNamespaceControllerDeployments .Release.Namespace }}
      {{- with $controllerDeployment.metadata }}
        {{- $managerServiceAccountNamespace = (get $controllerDeployment.metadata.labels "actions.github.com/controller-service-account-namespace") }}
      {{- end }}
    {{- else }}
      {{- fail "No gha-rs-controller deployment that watch this namespace found using label (actions.github.com/controller-watch-single-namespace). Consider setting controllerServiceAccount.namespace in values.yaml to be explicit if you think the discovery is wrong." }}
    {{- end }}
  {{- end }}
  {{- if eq $managerServiceAccountNamespace "" }}
    {{- fail "No service account namespace found for gha-rs-controller deployment using label (actions.github.com/controller-service-account-namespace), consider setting controllerServiceAccount.namespace in values.yaml to be explicit if you think the discovery is wrong." }}
  {{- end }}
{{- $managerServiceAccountNamespace }}
{{- end }}
{{- end }}
