function setup-vault() {
    vault_url=${VAULT_URL:-http://vault${DOMAIN:-.bastet-cat.local}}
    vault_secret_name=${VAULT_SECRET_NAME:-vault-keys}
    vault_namespace=${VAULT_NAMESPACE:-vault}
    root_token=${VAULT_ROOT_TOKEN:-$(kubectl get secret ${vault_secret_name} -n ${vault_namespace} -o jsonpath="{.data.root_token}" | base64 -d)}
    auth_header="X-Vault-Token: ${root_token}"
    target_namespace=${TARGET_NAMESPACE:-external-secrets}
    if ! curl -s -H "${auth_header}" -X GET ${vault_url}/v1/sys/auth/userpass | jq '.' | grep -q 'mount_type'; then
        poweruser_data=$(cat <<-EOL
			path "cubbyhole/*" {
				capabilities = ["create", "read", "update", "delete", "list"]
			}

			\n\npath "apps/*" {
				capabilities = ["create", "read", "update", "delete", "list"]
			}

			\n\npath "tools/*" {
				capabilities = ["create", "read", "update", "delete", "list"]
			}

			\n\npath "sys/mounts/*" {
				capabilities = ["create", "read", "update", "delete", "list"]
			}

			\n\npath "auth/token/create" {
				capabilities = ["create", "update"]
			}
		EOL
        )
        poweruser_data="{\"policy\": \"$(echo $poweruser_data | sed 's/\"/\\\"/g')\"}"
        echo -e "\e[34mSetting up vault\e[0m"
        curl -s -H "${auth_header}" -X POST -d '{"type": "userpass"}' ${vault_url}/v1/sys/auth/userpass | jq '.'
    else
        echo "userpass auth method already enabled"
    fi

    if ! curl -s -H "${auth_header}" -X GET ${vault_url}/v1/sys/policies/acl/poweruser | jq '.' | grep -q 'mount_type'; then
        echo -e "\e[34mCreating poweruser policy\e[0m"
        curl -s -H "${auth_header}" -X POST -d "$poweruser_data" ${vault_url}/v1/sys/policies/acl/poweruser | jq '.'
    else
        echo "poweruser policy already exists"
    fi

    if ! curl -s -H "${auth_header}" -X GET ${vault_url}/v1/auth/userpass/users/admin | jq '.' | grep -q 'mount_type'; then
        echo -e "\e[34mCreating admin userpass\e[0m"
        curl -s -H "${auth_header}" -X POST -d '{"password": "admin", "policies": "default,poweruser"}' ${vault_url}/v1/auth/userpass/users/admin | jq '.'
    else
        echo "Admin user already exists"
    fi

    if ! curl -s -H "${auth_header}" -X GET ${vault_url}/v1/auth/userpass/users/system | jq '.' | grep -q 'mount_type'; then
        echo -e "\e[34mCreating system userpass\e[0m"
        curl -s -H "${auth_header}" -X POST -d '{"password": "system", "policies": "default,poweruser"}' ${vault_url}/v1/auth/userpass/users/system | jq '.'
    else
        echo "System user already exists"
    fi

    new_token=$(curl -s -H "${auth_header}" -X POST -d '{"password": "system"}' ${vault_url}/v1/auth/userpass/login/system | jq -r '.auth.client_token')
    auth_header="X-Vault-Token: ${new_token}"

    if ! kubectl get namespace external-secrets >/dev/null 2>&1; then
        echo -e "\e[34mCreating namespace ${target_namespace}\e[0m"
        kubectl create namespace external-secrets
    else
        echo "Namespace external-secrets already exists"
    fi

    if ! kubectl get secret ${vault_secret_name} --namespace ${target_namespace} >/dev/null 2>&1; then
        echo -e "\e[31mCreating secret ${vault_secret_name} in namespace ${target_namespace}\e[0m"
        kubectl create secret generic ${vault_secret_name} \
            --namespace ${target_namespace} \
            --from-literal=token=${new_token} || echo -e "\e[34mSecret already exists\e[0m"
    else
        echo "Secret ${vault_secret_name} in namespace ${target_namespace} already exists"
    fi

    if ! curl -s -H "${auth_header}" -X GET ${vault_url}/v1/sys/mounts/apps | jq '.' | grep -q 'mount_type'; then
        echo -e "\e[34mCreating apps secret engine in Vault\e[0m"
        curl -s -H "${auth_header}" -X POST -d '{"type": "kv-v2"}' ${vault_url}/v1/sys/mounts/apps | jq '.'
    else
        echo "apps secret engine already exists"
    fi

    if ! curl -s -H "${auth_header}" -X GET ${vault_url}/v1/sys/mounts/tools | jq '.' | grep -q 'mount_type'; then
        echo -e "\e[34mCreating tools secret engine in Vault\e[0m"
        curl -s -H "${auth_header}" -X POST -d '{"type": "kv-v2"}' ${vault_url}/v1/sys/mounts/tools | jq '.'
    else
        echo "tools secret engine already exists"
    fi
}
