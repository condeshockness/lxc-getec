# lxc-getec

nano cockpit-install.sh

cole

```bash
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
```


chmod +x cockpit.sh

./cockpit.sh

Apos instalar o cockpit rode o script de personalização

cockpit-getec.sh

```bash
#!/usr/bin/env bash
# ==============================================================================
# Personalizar: COCKPIT v353+ (Bleeding Edge)
# Projeto: GETEC IFRO
# Ambiente: Debian 13 LXC Proxmox
# Autor: Ramon Silas Shockness
# ==============================================================================
set -e

BRAND_DIR="/usr/share/cockpit/branding/getec"
LINK_DIR="/etc/cockpit/branding"

echo "==> Criando diretório de branding..."
mkdir -p "$BRAND_DIR"

echo "==> Baixando imagens do GitHub..."
curl -fsSL -o "$BRAND_DIR/logo.jpg" \
  https://raw.githubusercontent.com/condeshockness/images/refs/heads/main/lxc/logo.jpg

curl -fsSL -o "$BRAND_DIR/favicon.ico" \
  https://raw.githubusercontent.com/condeshockness/images/refs/heads/main/lxc/favicon.ico

curl -fsSL -o "$BRAND_DIR/fundo.jpg" \
  https://raw.githubusercontent.com/condeshockness/images/refs/heads/main/lxc/fundo.jpg

echo "==> Criando manifest.json..."
cat > "$BRAND_DIR/manifest.json" <<'EOF'
{
  "version": 1,
  "name": "getec",
  "description": "Branding GETEC",
  "priority": 1,
  "css": ["branding.css"],
  "icon": "logo.jpg",
  "favicon": "favicon.ico"
}
EOF

echo "==> Criando branding.css..."
cat > "$BRAND_DIR/branding.css" <<'EOF'
/* ================= LOGO ================= */
#badge {
  inline-size: 96px;
  block-size: 96px;
  background-image: url("logo.jpg");
  background-size: contain;
  background-repeat: no-repeat;
  background-position: center;
}

/* Nome */
#brand::before {
  content: "GETEC";
}

/* ========== FUNDO APENAS NO LOGIN ========== */

body.login-pf {
  background-image: url("fundo.jpg") !important;
  background-size: cover !important;
  background-position: center !important;
  background-repeat: no-repeat !important;
}

body.login-pf::before {
  content: "";
  position: fixed;
  inset: 0;
  background: rgba(0,0,0,0.55);
  z-index: -1;
}

body.login-pf .container {
  background: rgba(15, 23, 42, 0.88) !important;
  backdrop-filter: blur(6px);
  border-radius: 18px;
  padding: 24px;
}
EOF

echo "==> Criando link simbólico em /etc/cockpit/branding..."
rm -rf "$LINK_DIR"
ln -sfn "$BRAND_DIR" "$LINK_DIR"

echo "==> Limpando cache do Cockpit..."
rm -rf /var/cache/cockpit/*
rm -rf /run/cockpit/*

echo "==> Reiniciando cockpit.socket..."
systemctl restart cockpit.socket

echo "==> Concluído! Recarregue o navegador com Ctrl+Shift+R."

```
