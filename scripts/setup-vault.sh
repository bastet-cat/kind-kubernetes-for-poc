function initialize_vault() {
    local namespace=$1
    local secret_name=$2
    local pod_name=$3

    if kubectl get secrets $secret_name -n $namespace --ignore-not-found &> /dev/null; then
        echo "Inicializando o vault"
        until kubectl exec -n $namespace $pod_name -- vault version | grep -q "Vault"; do printf '.'; sleep 5; done; sleep 5;
        kubectl exec -n $namespace pod/$pod_name -- vault operator init -key-shares=5 -key-threshold=3 -format=json > init-keys.json
        kubectl create secret generic $secret_name -n $namespace \
            --from-literal=root_token=$(cat init-keys.json | jq -r '.root_token') \
            --from-literal=unseal_keys=$(cat init-keys.json | jq -r '.unseal_keys_b64 | join(",")')
        rm -rf init-keys.json
    else
        echo "Vault já inicializado"
    fi
}

function get_root_token() {
    local namespace=$1
    local secret_name=$2

    echo $(kubectl get secret ${secret_name} -n ${namespace} -o jsonpath="{.data.root_token}" | base64 -d)
}

function build_and_load_docker_image() {
    local image=$1
    local cluster_name=$2

    DOCKER_BUILDKIT=1 docker build -t $image -f assets/vault-unseal/image/Dockerfile .
    kind load docker-image $image --name $cluster_name
}

function wait_for_vault() {
    local url=$1

    echo -e "\e[2mAguardando a disponibilidade do vault\e[0m";
    until ! curl -s ${url}/v1/sys/health | grep -q 'jq: parse error'; do printf "."; sleep 10; done; echo "";
}

function setup_vault_unseal_cronjob() {
    local namespace=$1

    helm upgrade --install vault-unseal-cronjob ./assets/vault-unseal/helm --namespace $namespace
    kubectl create job -n $namespace --from=cronjob/vault-unseal my-immediate-job
}

function wait_for_vault_unseal() {
    local url=$1

    echo -e "\e[2mAguardando o vault ser desbloqueado\e[0m";
    until curl -s ${url}/v1/sys/health | jq '.sealed' | grep -q 'false'; do printf "."; sleep 5; done; echo "";
    echo -e "\e[2mVault desbloqueado\e[0m"
}

function enable_userpass_auth() {
    local url=$1
    local header=$2

    if ! curl -s -H "${header}" -X GET ${url}/v1/sys/auth/userpass | jq '.' | grep -q 'mount_type'; then
        echo -e "\e[34mSetting up vault\e[0m"
		echo "curl -s -H \"${header}\" -X POST -d '{\"type\": \"userpass\"}' ${url}/v1/sys/auth/userpass | jq '.'"
        curl -s -H "${header}" -X POST -d '{"type": "userpass"}' ${url}/v1/sys/auth/userpass | jq '.'
    else
        echo "userpass auth method already enabled"
    fi
}

function create_poweruser_policy() {
    local url=$1
    local header=$2

    local poweruser_data=$(cat <<-EOL
		path "cubbyhole/*" {
			capabilities = ["create", "read", "update", "delete", "list"]
		}

		path "apps/*" {
			capabilities = ["create", "read", "update", "delete", "list"]
		}

		path "tools/*" {
			capabilities = ["create", "read", "update", "delete", "list"]
		}

		path "sys/mounts/*" {
			capabilities = ["create", "read", "update", "delete", "list"]
		}

		path "auth/token/create" {
			capabilities = ["create", "update"]
		}
		EOL
    )
    poweruser_data="{\"policy\": \"$(echo $poweruser_data | sed 's/\"/\\\"/g')\"}"

    if ! curl -s -H "${header}" -X GET ${url}/v1/sys/policies/acl/poweruser | jq '.' | grep -q 'mount_type'; then
        echo -e "\e[34mCreating poweruser policy\e[0m"
        curl -s -H "${header}" -X POST -d "$poweruser_data" ${url}/v1/sys/policies/acl/poweruser | jq '.'
    else
        echo "poweruser policy already exists"
    fi
}

function create_userpass_user() {
    local url=$1
    local header=$2
    local username=$3
    local password=$4

    if ! curl -s -H "${header}" -X GET ${url}/v1/auth/userpass/users/${username} | jq '.' | grep -q 'mount_type'; then
        echo -e "\e[34mCreating ${username} userpass\e[0m"
        curl -s -H "${header}" -X POST -d "{\"password\": \"${password}\", \"policies\": \"default,poweruser\"}" ${url}/v1/auth/userpass/users/${username} | jq '.'
    else
        echo "${username} user already exists"
    fi
}

function login_userpass() {
    local url=$1
    local username=$2
    local password=$3

    echo $(curl -s -X POST -d "{\"password\": \"${password}\"}" ${url}/v1/auth/userpass/login/${username} | jq -r '.auth.client_token')
}

function create_namespace() {
    local namespace=$1

    if ! kubectl get namespace ${namespace} >/dev/null 2>&1; then
        echo -e "\e[34mCreating namespace ${namespace}\e[0m"
        kubectl create namespace ${namespace}
    else
        echo "Namespace ${namespace} already exists"
    fi
}

function create_secret_in_namespace() {
    local namespace=$1
    local secret_name=$2
    local token=$3

    if ! kubectl get secret ${secret_name} --namespace ${namespace} >/dev/null 2>&1; then
        echo -e "\e[31mCreating secret ${secret_name} in namespace ${namespace}\e[0m"
        kubectl create secret generic ${secret_name} \
            --namespace ${namespace} \
            --from-literal=token=${token} || echo -e "\e[34mSecret already exists\e[0m"
    else
        echo "Secret ${secret_name} in namespace ${namespace} already exists"
    fi
}

function create_secret_engine() {
    local url=$1
    local header=$2
    local engine_name=$3

    if ! curl -s -H "${header}" -X GET ${url}/v1/sys/mounts/${engine_name} | jq '.' | grep -q 'mount_type'; then
        echo -e "\e[34mCreating ${engine_name} secret engine in Vault\e[0m"
        curl -s -H "${header}" -X POST -d '{"type": "kv-v2"}' ${url}/v1/sys/mounts/${engine_name} | jq '.'
    else
        echo "${engine_name} secret engine already exists"
    fi
}

function setup-vault() {
    local vault_url=${VAULT_URL:-http://vault${DOMAIN:-.bastet-cat.local}}
    local vault_secret_name=${VAULT_SECRET_NAME:-vault-keys}
    local vault_namespace=${VAULT_NAMESPACE:-vault}
    local target_namespace=${TARGET_NAMESPACE:-external-secrets}
    local kind_cluster_name=${KIND_CLUSTER_NAME:-bastet-cluster}
    local vault_unseal_image=vault-unseal:v0

    local pod_name=$(kubectl get pods --selector app.kubernetes.io/name=vault -n $vault_namespace -o jsonpath='{.items[0].metadata.name}')
    initialize_vault $vault_namespace $vault_secret_name $pod_name

    local root_token=$(get_root_token $vault_namespace $vault_secret_name)
    local auth_header="X-Vault-Token: ${root_token}"

    build_and_load_docker_image $vault_unseal_image $kind_cluster_name
    wait_for_vault $vault_url

    setup_vault_unseal_cronjob $vault_namespace
    wait_for_vault_unseal $vault_url

    enable_userpass_auth $vault_url "$auth_header"
    create_poweruser_policy $vault_url "$auth_header"
    create_userpass_user $vault_url "$auth_header" "admin" "admin"
    create_userpass_user $vault_url "$auth_header" "system" "system"

    local new_token=$(login_userpass $vault_url "system" "system")
    auth_header="X-Vault-Token: ${new_token}"

    create_namespace $target_namespace
    create_secret_in_namespace $target_namespace $vault_secret_name $new_token

    create_secret_engine $vault_url "$auth_header" "apps"
    create_secret_engine $vault_url "$auth_header" "tools"
}
