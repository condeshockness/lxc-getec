# Stage 1 - Terraform
FROM hashicorp/terraform:1.6.6 AS terraform

# Stage 2 - Semaphore oficial
FROM semaphoreui/semaphore:v2.16.51

USER root

# Copia terraform para a imagem final
COPY --from=terraform /bin/terraform /usr/local/bin/terraform

# Dependências úteis para jobs (ssh, git, ansible opcional)
RUN apk add --no-cache \
    openssh-client \
    git \
    bash \
    nano \
    curl

# Validação
RUN terraform version

USER semaphore

