{{- define "gh-runner-scale-set-external-secret" }}
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: gha-runner-scale-set-{{ .org }}-secrets
spec:
  secretStoreRef:
    name: vault-apps-backend
    kind: ClusterSecretStore
  target:
    name: gh-runners-{{ .org }}-secrets
    creationPolicy: Owner
  data:
  - secretKey: "github_app_id"
    remoteRef:
      conversionStrategy: Default
      decodingStrategy: None
      key: "{{ .org }}/{{ .path }}"
      metadataPolicy: None
      property: "github-app-id"
  - secretKey: "github_app_installation_id"
    remoteRef:
      conversionStrategy: Default
      decodingStrategy: None
      key: "{{ .org }}/{{ .path }}"
      metadataPolicy: None
      property: "github-installation-id"
  - secretKey: "github_app_private_key"
    remoteRef:
      conversionStrategy: Default
      decodingStrategy: None
      key: "{{ .org }}/{{ .path }}"
      metadataPolicy: None
      property: "github-app-private-key"
{{- end }}
