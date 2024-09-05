# Use a imagem base Alpine
FROM alpine:3.18

# Defina a versão do Vault CLI que você deseja instalar
ENV VAULT_VERSION="1.15.0"
ENV KUBECTL_VERSION="v1.28.0"

# Instale dependências necessárias e o kubectl
RUN apk add --no-cache \
    curl \
    unzip \
    ca-certificates \
    && curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
    && chmod +x kubectl \
    && mv kubectl /usr/local/bin/kubectl

# Instale o Vault CLI
RUN curl -O "https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip" \
    && unzip vault_${VAULT_VERSION}_linux_amd64.zip \
    && mv vault /usr/local/bin/ \
    && rm vault_${VAULT_VERSION}_linux_amd64.zip

# Verifique as instalações
RUN kubectl version --client && vault --version

# Defina o comando padrão
CMD ["sh"]
