#!/usr/bin/env bash
set -e

echo "== Atualizando sistema =="
apt update && apt -y upgrade

echo "== Dependências =="
apt install -y ca-certificates curl gnupg uidmap dbus-user-session

echo "== Config Docker (journald + systemd cgroup) =="
mkdir -p /etc/docker
cat <<EOF >/etc/docker/daemon.json
{
  "log-driver": "journald",
  "exec-opts": ["native.cgroupdriver=systemd"],
  "storage-driver": "overlay2"
}
EOF

echo "== Instalando Docker =="
curl -fsSL https://get.docker.com | sh

systemctl enable docker
systemctl restart docker

echo "== Teste Docker =="
docker run --rm hello-world

echo "== Instalando Portainer =="
docker volume create portainer_data

docker run -d \
  --name portainer \
  --restart=always \
  -p 8000:8000 \
  -p 9443:9443 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:latest

echo "== Pronto =="
