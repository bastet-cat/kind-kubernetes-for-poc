# EXEMPLOS:

## Prepare

### Scripts pŕe instalação do ARGOCD:

crie um arquivo para configurar a secret do argocd antes de instalar
`scripts/pre-argo/my-secrets.sh`

```
touch scripts/pre-argo/my-secrets.sh
chmod +x scripts/pre-argo/my-secrets.sh
```


```
#!/usr/bin/env bash
vault_secret_name=${VAULT_SECRET_NAME:-vault-keys}
external_secrets_namespace=${VAULT_NAMESPACE:-external-secrets}
root_token=${VAULT_ROOT_TOKEN:-$(kubectl get secret ${vault_secret_name} -n ${external_secrets_namespace} -o jsonpath="{.data.token}" | base64 -d)}
app_id=<<<SEU_APP_ID>>>
installation_id=<<<SEU_INSTALLATION_ID>>>
pem_file=<<<PATH_DO_SEU_PEM>>>
pem_content=$(awk '{printf "%s\\n", $0}' $pem_file)
curl -X POST \
  -H "X-Vault-Token: $root_token" \
  -d "{ \"data\": { \"github-app-id\": \"${app_id}\", \"github-installation-id\": \"${installation_id}\", \"github-app-private-key\": \"${pem_content}\" } }" \
  http://vault-127-0-0-1.nip.io/v1/apps/data/bastet-cat/arc-system
```

### Scripts de instalação das apps depois de instalar o argocd

crie um arquivo para configurar a secret do argocd antes de instalar
`scripts/pre-end/install-apps.sh`

```
touch scripts/pre-end/install-apps.sh
chmod +x scripts/pre-end/install-apps.sh
```

```
#!/usr/bin/env bash
vault_secret_name=${VAULT_SECRET_NAME:-vault-keys}
namespace=${TARGET_NAMESPACE:-external-secrets}
token=$(kubectl get secret ${vault_secret_name} -n ${namespace} -o jsonpath="{.data.token}" | base64 -d)
admin_secret=$(curl -s -H "X-Vault-Token: ${token}" -X GET http://vault-127-0-0-1.nip.io/v1/tools/data/argocd | jq -r '.data.data."admin-secret"')

argocd login argocd-127-0-0-1.nip.io --username admin --password "${admin_secret}" --insecure --grpc-web --plaintext

argocd repo add \
    URL_DO_SEU_REPO \
    --name kind-kubernetes-for-poc \
    --username SEU_USUARIO \
    --password SEU_PAT \
    --upsert

kubectl apply -n argo-cd -f applications.d/gha-runner-scale-set-controller/applicationset.yaml
kubectl apply -n argo-cd -f applications.d/gha-runner-scale-set/applicationset.yaml
```

## Instale

```
LOCAL_DOMAIN=-127-0-0-1.nip.io make create-cluster
```

## Outras formas de criar o cluster

```
make create-cluster
```

```
LOCAL_DOMAIN=-127-0-0-1.nip.io make create-cluster
```

```
CLUSTER_NAME=my-cluster LOCAL_DOMAIN=-127-0-0-1.nip.io make create-cluster
```

## Apagar o Cluster

```
make destroy-cluster
```

### Resumo

Instalando com:

```
LOCAL_DOMAIN=-127-0-0-1.nip.io make create-cluster
```

- [argocd](http://argocd-127-0-0-1.nip.io)

- A senha do argo estará armazenada no [vault](http://vault-127-0-0-1.nip.io) em **secrets/tools/argocd**
