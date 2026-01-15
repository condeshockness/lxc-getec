#!/usr/bin/env bash
set -e

echo "[INFO] Atualizando sistema"
apt update && apt -y upgrade

echo "[INFO] Instalando dependências"
apt install -y ca-certificates curl gnupg uidmap dbus

echo "[INFO] Configurando Docker"
mkdir -p /etc/docker
cat <<EOF > /etc/docker/daemon.json
{
  "log-driver": "journald",
  "storage-driver": "overlay2"
}
EOF

echo "[INFO] Instalando Docker"
curl -fsSL https://get.docker.com | sh

systemctl enable docker
systemctl restart docker

echo "[INFO] Testando Docker"
docker run --rm hello-world

echo "[INFO] Instalando Portainer"
docker volume create portainer_data

docker rm -f portainer 2>/dev/null || true

docker run -d \
  --name portainer \
  --restart=always \
  -p 9443:9443 \
  -p 8000:8000 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:latest

echo "[OK] Docker e Portainer instalados com sucesso"
