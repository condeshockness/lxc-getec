# Stage 1 - pega o binário do Terraform pronto
FROM hashicorp/terraform:1.6.0 AS terraform

# Stage 2 - imagem final do Semaphore
FROM semaphoreui/semaphore:v2.16.47

USER root

# copia o binário do terraform
COPY --from=terraform /bin/terraform /usr/local/bin/terraform

# valida (opcional)
RUN terraform version

USER semaphore
