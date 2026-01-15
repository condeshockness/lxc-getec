apt update && apt -y upgrade

apt install -y ca-certificates curl gnupg

mkdir -p /etc/docker
echo '{ "log-driver": "journald" }' > /etc/docker/daemon.json

curl -fsSL https://get.docker.com | sh

systemctl enable docker
systemctl restart docker

docker run --rm hello-world

docker volume create portainer_data

docker run -d \
  --name portainer \
  --restart=always \
  -p 9443:9443 \
  -p 8000:8000 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:latest
