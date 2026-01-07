# lxc-getec

nano cockpit.sh

cole

#!/bin/bash

# ==============================================================================
# PARTE 1: INSTALAÇÃO DO SISTEMA BASE (COCKPIT v353+)
# Inclui: Core, Files, Navigator e Fix de Rede LXC
# ==============================================================================

set -e
source /etc/os-release

echo "--- [1/5] Preparando Repositórios e Dependências ---"
apt update && apt install -t ${VERSION_CODENAME} wget curl tar xz-utils findutils -y

# Adiciona repositório Backports (Essencial para Cockpit v353)
cat <<EOF >/etc/apt/sources.list.d/debian-backports.sources
Types: deb deb-src
URIs: http://deb.debian.org/debian
Suites: ${VERSION_CODENAME}-backports
Components: main
Enabled: yes
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF
apt update

echo "--- [2/5] Instalando Cockpit Core (Backports) ---"
# Instala a versão mais recente disponível
apt install -t ${VERSION_CODENAME}-backports cockpit cockpit-networkmanager cockpit-packagekit --no-install-recommends -y

# Permitir root (Opcional, mas útil em LXC dev)
if [ -f /etc/cockpit/disallowed-users ]; then
    sed -i "s/root//g" /etc/cockpit/disallowed-users
fi

echo "--- [3/5] Instalando Plugin: Cockpit Files (v13) ---"
FILES_DIR="/usr/share/cockpit/files"
TEMP_DIR="/tmp/cockpit-files-install"
rm -rf "$FILES_DIR" "$TEMP_DIR"
mkdir -p "$FILES_DIR" "$TEMP_DIR"

wget -q "https://github.com/cockpit-project/cockpit-files/releases/download/13/cockpit-files-13.tar.xz" -O "$TEMP_DIR/files.tar.xz"
tar -xJf "$TEMP_DIR/files.tar.xz" -C "$TEMP_DIR"
# Encontra a pasta correta dentro do tar
SOURCE_PATH=$(find "$TEMP_DIR" -name "manifest.json" -printf "%h\n" | head -n 1)
cp -r "$SOURCE_PATH"/* "$FILES_DIR/"
rm -rf "$TEMP_DIR"

echo "--- [4/5] Instalando Plugin: Navigator ---"
wget -q "https://github.com/45Drives/cockpit-navigator/releases/download/v0.6.0/cockpit-navigator_0.6.0-1bookworm_all.deb" -O cockpit-navigator.deb
apt install ./cockpit-navigator.deb -y
rm cockpit-navigator.deb

echo "--- [5/5] Ajustes Finais (Rede LXC e Serviço) ---"
# Configuração limpa para o NetworkManager assumir a rede
cat <<EOF >/etc/network/interfaces
source /etc/network/interfaces.d/*
auto lo
iface lo inet loopback
EOF

if [ -f /etc/NetworkManager/NetworkManager.conf ]; then
    sed -i 's/managed=false/managed=true/g' /etc/NetworkManager/NetworkManager.conf
fi

systemctl enable --now cockpit.socket
systemctl restart cockpit

echo "==================================================="
echo " INSTALAÇÃO BASE CONCLUÍDA!"
echo "==================================================="
echo "Acesse: https://$(hostname -I | awk '{print $1}'):9090"
echo "Nota: O visual ainda é o padrão do Debian."
echo "==================================================="


chmod +x cockpit.sh

./cockpit.sh

Apos instalar o cockpit rode o script de personalização

cockpit-getec.sh
