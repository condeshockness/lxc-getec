#!/usr/bin/env bash
set -e

STD=">/dev/null 2>&1"

### ========= FUNÇÕES =========

msg_info() { echo -e "\e[34m[INFO]\e[0m $1"; }
msg_ok()   { echo -e "\e[32m[OK]\e[0m $1"; }
msg_error(){ echo -e "\e[31m[ERRO]\e[0m $1"; }

get_latest_release() {
  curl -fsSL https://api.github.com/repos/"$1"/releases/latest | jq -r '.tag_name'
}

### ========= ROOT =========

if [[ "$EUID" -ne 0 ]]; then
  msg_error "Execute como root"
  exit 1
fi

### ========= VERSÕES =========

PORTAINER_LATEST_VERSION=$(get_latest_release "portainer/portainer")

### ========= BASE =========

msg_info "Atualizando sistema base"
apt-get update $STD
apt-get -y upgrade $STD
msg_ok "Sistema atualizado"

msg_info "Instalando dependências"
apt-get install -y \
  ca-certificates curl gnupg lsb-release \
  iptables fuse-overlayfs uidmap jq dbus $STD
msg_ok "Dependências instaladas"

### ========= AJUSTES LXC UNPRIV =========

msg_info "Configurando Docker para LXC sem privilégios"

mkdir -p /etc/docker

cat > /etc/docker/daemon.json <<'EOF'
{
  "log-driver": "journald",
  "storage-driver": "overlay2",
  "exec-opts": ["native.cgroupdriver=systemd"],
  "iptables": true
}
EOF

msg_ok "Configuração Docker aplicada"

### ========= REPOSITÓRIO DOCKER OFICIAL =========

msg_info "Adicionando repositório oficial do Docker"

install -m 0755 -d /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

chmod a+r /etc/apt/keyrings/docker.gpg

UBUNTU_CODENAME=$(lsb_release -cs)

cat > /etc/apt/sources.list.d/docker.list <<EOF
deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $UBUNTU_CODENAME stable
EOF

apt-get update $STD
msg_ok "Repositório Docker configurado"

### ========= INSTALAR DOCKER =========

msg_info "Instalando Docker Engine"

apt-get install -y \
  docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin $STD

msg_ok "Docker instalado"

systemctl enable docker $STD
systemctl restart docker

### ========= PORTAINER CE =========

msg_info "Instalando Portainer CE $PORTAINER_LATEST_VERSION"

docker volume create portainer_data >/dev/null 2>&1 || true

docker run -d \
  -p 8000:8000 \
  -p 9443:9443 \
  --name=portainer \
  --restart=always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:latest

msg_ok "Portainer instalado"

### ========= TESTE =========

msg_info "Testando Docker"
docker run --rm hello-world >/dev/null 2>&1 && msg_ok "Docker funcionando corretamente"

msg_ok "Instalação concluída com sucesso no Ubuntu 25.04 (LXC sem privilégios)!"
exit 0
