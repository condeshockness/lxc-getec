#!/bin/bash

# ==============================================================================
# PARTE 1: INSTALAÇÃO DO SISTEMA BASE (COCKPIT v353+)
# Inclui: Core, Files, Navigator, Usuário Semaphore e CORREÇÃO DE REDE
# Autor : Ramon Silas Shockness (Versão Final com Usuário)
# ==============================================================================

set -e
source /etc/os-release

echo "--- [1/6] Preparando Repositórios e Dependências ---"
# Adicionado 'sudo' que é necessário para o usuário semaphore
apt update && apt install -t ${VERSION_CODENAME} wget curl tar xz-utils findutils sudo -y

# Repositório Backports
cat <<EOF >/etc/apt/sources.list.d/debian-backports.sources
Types: deb deb-src
URIs: http://deb.debian.org/debian
Suites: ${VERSION_CODENAME}-backports
Components: main
Enabled: yes
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF
apt update

echo "--- [2/6] Instalando Cockpit Core (Backports) ---"
apt install -t ${VERSION_CODENAME}-backports cockpit cockpit-networkmanager cockpit-packagekit network-manager --no-install-recommends -y

# Ajuste permissão root
if [ -f /etc/cockpit/disallowed-users ]; then
    sed -i "s/root//g" /etc/cockpit/disallowed-users
fi

echo "--- [3/6] Instalando Plugin: Cockpit Files (v13) ---"
FILES_DIR="/usr/share/cockpit/files"
TEMP_DIR="/tmp/cockpit-files-install"
rm -rf "$FILES_DIR" "$TEMP_DIR"
mkdir -p "$FILES_DIR" "$TEMP_DIR"

wget -q "https://github.com/cockpit-project/cockpit-files/releases/download/13/cockpit-files-13.tar.xz" -O "$TEMP_DIR/files.tar.xz"
tar -xJf "$TEMP_DIR/files.tar.xz" -C "$TEMP_DIR"
SOURCE_PATH=$(find "$TEMP_DIR" -name "manifest.json" -printf "%h\n" | head -n 1)
cp -r "$SOURCE_PATH"/* "$FILES_DIR/"
rm -rf "$TEMP_DIR"

echo "--- [4/6] Instalando Plugin: Navigator ---"
wget -q "https://github.com/45Drives/cockpit-navigator/releases/download/v0.6.0/cockpit-navigator_0.6.0-1bookworm_all.deb" -O cockpit-navigator.deb
apt install ./cockpit-navigator.deb -y
rm cockpit-navigator.deb

echo "--- [5/6] Criando Usuário de Automação (Semaphore) ---"
# Verifica se o usuário já existe para não dar erro em reexecução
if id "semaphore" &>/dev/null; then
    echo "Usuário 'semaphore' já existe. Pulando..."
else
    # Cria usuário com Home (-m), Shell Bash (-s) e adiciona ao grupo sudo (-G)
    useradd -m -s /bin/bash -c "Semaphore" -G sudo semaphore
    
    # Bloqueia a senha para exigir chave SSH (conforme imagem "Não permitir senha interativa")
    passwd -l semaphore
    
    # (Opcional) Se você precisar que o Semaphore rode comandos sudo SEM senha, descomente a linha abaixo:
    # echo "semaphore ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/semaphore
    
    echo "Usuário 'semaphore' criado com sucesso (acesso somente via chave SSH)."
fi

echo "--- [6/6] Ajustes Finais de Rede (SOLUÇÃO PÓS-REBOOT) ---"
echo "Blindando o sistema contra alterações do Proxmox..."

# 1. Configura NetworkManager
if [ -f /etc/NetworkManager/NetworkManager.conf ]; then
    sed -i 's/managed=false/managed=true/g' /etc/NetworkManager/NetworkManager.conf
    touch /etc/NetworkManager/conf.d/10-globally-managed-devices.conf
fi

# 2. TRAVA O PROXMOX E O SERVIÇO ANTIGO
touch /etc/network/.pve-ignore.interfaces
systemctl disable networking

cat <<EOF >/etc/network/interfaces
auto lo
iface lo inet loopback
EOF

# Habilita Cockpit
systemctl enable --now cockpit.socket

# 3. TROCA DE GUARDA (Execução imediata)
echo "Trocando gerenciamento de rede..."

systemctl stop networking
ip addr flush dev eth0 || true
systemctl enable --now NetworkManager
systemctl restart NetworkManager

# Loop de espera
echo "Aguardando novo IP via DHCP..."
for i in {1..15}; do
    if ip -4 addr show eth0 | grep -q "inet"; then
        echo "Rede restabelecida!"
        break
    fi
    sleep 2
done

# Captura o novo IP
NEW_IP=$(ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)

systemctl restart cockpit

echo "==================================================="
echo " INSTALAÇÃO COMPLETA!"
echo "==================================================="
echo "Acesse: https://${NEW_IP}:9090"
echo "Usuário 'semaphore' criado (adicione a chave SSH via interface)."
echo "==================================================="