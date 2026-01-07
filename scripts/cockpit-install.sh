#!/bin/bash

# ==============================================================================
# MASTER INSTALLER: COCKPIT v353+ (Bleeding Edge)
# Projeto: GETEC IFRO
# Ambiente: Debian 13 LXC Proxmox
# Autor: Ramon Silas Shockness
# ==============================================================================

set -e
source /etc/os-release

echo "--- INICIANDO INSTALAÇÃO DO COCKPIT (V353+) ---"

# ----------------------------------------------------------------
# 1. REPOSITÓRIOS E ATUALIZAÇÃO (MÉTODO BACKPORTS)
# ----------------------------------------------------------------
echo "1/6 - Configurando Repositórios e Base..."

apt update && apt install -t ${VERSION_CODENAME} wget curl tar xz-utils findutils -y

# Adiciona repositório Backports (Conforme validado)
cat <<EOF >/etc/apt/sources.list.d/debian-backports.sources
Types: deb deb-src
URIs: http://deb.debian.org/debian
Suites: ${VERSION_CODENAME}-backports
Components: main
Enabled: yes
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF

apt update

# ----------------------------------------------------------------
# 2. INSTALAÇÃO DO CORE (VERSÃO RECENTE)
# ----------------------------------------------------------------
echo "2/6 - Instalando Cockpit v353+..."

# Força instalação via backports
apt install -t ${VERSION_CODENAME}-backports cockpit cockpit-networkmanager cockpit-packagekit --no-install-recommends -y

# Liberar acesso root
if [ -f /etc/cockpit/disallowed-users ]; then
    sed -i "s/root//g" /etc/cockpit/disallowed-users
fi

# ----------------------------------------------------------------
# 3. INSTALAÇÃO DE PLUGINS
# ----------------------------------------------------------------
echo "3/6 - Instalando Plugins (Files & Navigator)..."

# --- Plugin: Files (v13) ---
FILES_DIR="/usr/share/cockpit/files"
TEMP_DIR="/tmp/cockpit-files-install"
rm -rf "$FILES_DIR" "$TEMP_DIR"
mkdir -p "$FILES_DIR" "$TEMP_DIR"

wget -q "https://github.com/cockpit-project/cockpit-files/releases/download/13/cockpit-files-13.tar.xz" -O "$TEMP_DIR/files.tar.xz"
tar -xJf "$TEMP_DIR/files.tar.xz" -C "$TEMP_DIR"
# Busca inteligente do manifesto
SOURCE_PATH=$(find "$TEMP_DIR" -name "manifest.json" -printf "%h\n" | head -n 1)
cp -r "$SOURCE_PATH"/* "$FILES_DIR/"
rm -rf "$TEMP_DIR"

# --- Plugin: Navigator ---
wget -q "https://github.com/45Drives/cockpit-navigator/releases/download/v0.6.0/cockpit-navigator_0.6.0-1bookworm_all.deb" -O cockpit-navigator.deb
apt install ./cockpit-navigator.deb -y
rm cockpit-navigator.deb

# ----------------------------------------------------------------
# 4. BRANDING: GETEC IFRO (CSS PATTERNFLY 5)
# ----------------------------------------------------------------
echo "4/6 - Aplicando Identidade Visual GETEC..."

# Limpeza de lixo (Arch, Kubernetes, etc)
cd /usr/share/cockpit/branding
rm -rf arch kubernetes registry default 2>/dev/null || true

# Criar estrutura GETEC
BRANDING_DIR="/usr/share/cockpit/branding/getec"
mkdir -p "$BRANDING_DIR"

# Manifesto
cat <<EOF > "$BRANDING_DIR/manifest.json"
{
  "label": "GETEC IFRO",
  "product": "Servidor de Gerenciamento",
  "logo": "logo.png",
  "favicon": "favicon.ico"
}
EOF

# CSS GERAL (PatternFly 5 - Atualizado para v353)
cat <<EOF > "$BRANDING_DIR/branding.css"
/* Ajuste de altura da logo no menu */
.pf-v5-c-brand {
    height: 40px;
    width: auto;
}
EOF

# CSS LOGIN (PatternFly 5 - Atualizado para v353)
cat <<EOF > "$BRANDING_DIR/login.css"
/* Fundo Clean Escuro */
.pf-v5-c-login { 
    background-image: none !important;
    background-color: #1b1b1b !important;
}
/* Tamanho da Logo no Login */
.pf-v5-c-login__main-header .pf-v5-c-brand {
    height: 100px !important;
    width: auto !important;
    max-width: 350px;
    object-fit: contain;
}
EOF

# Logo Provisória (Debian) - Substituir depois!
wget -q "https://upload.wikimedia.org/wikipedia/commons/thumb/c/ca/Debian_logo_2.svg/200px-Debian_logo_2.svg.png" -O "$BRANDING_DIR/logo.png"
cp "$BRANDING_DIR/logo.png" "$BRANDING_DIR/favicon.ico"

# Ajustar Permissões
chown -R root:root "$BRANDING_DIR"
chmod 755 "$BRANDING_DIR"
chmod 644 "$BRANDING_DIR"/*

# Configurar cockpit.conf para usar GETEC
CONF_FILE="/etc/cockpit/cockpit.conf"
[ ! -f "$CONF_FILE" ] && echo "[WebService]" > "$CONF_FILE"
sed -i '/^Branding/d' "$CONF_FILE"
if grep -q "\[WebService\]" "$CONF_FILE"; then
    sed -i '/\[WebService\]/a Branding = getec' "$CONF_FILE"
else
    echo "" >> "$CONF_FILE"
    echo "[WebService]" >> "$CONF_FILE"
    echo "Branding = getec" >> "$CONF_FILE"
fi

# Mensagem de Texto
echo "GETEC - IFRO" > /etc/issue.cockpit
echo "Acesso Restrito" >> /etc/issue.cockpit

# ----------------------------------------------------------------
# 5. FIX DE REDE (LXC PROXMOX)
# ----------------------------------------------------------------
echo "5/6 - Ajustando NetworkManager..."

# Limpar interfaces para deixar NetworkManager assumir
cat <<EOF >/etc/network/interfaces
source /etc/network/interfaces.d/*
auto lo
iface lo inet loopback
EOF

# Habilitar NetworkManager
if [ -f /etc/NetworkManager/NetworkManager.conf ]; then
    sed -i 's/managed=false/managed=true/g' /etc/NetworkManager/NetworkManager.conf
fi

# ----------------------------------------------------------------
# 6. FINALIZAÇÃO
# ----------------------------------------------------------------
echo "6/6 - Reiniciando serviços..."
systemctl enable --now cockpit.socket
systemctl restart cockpit

echo "==================================================="
echo " INSTALAÇÃO FINALIZADA! (v353)"
echo "==================================================="
echo "Acesse: https://$(hostname -I | awk '{print $1}'):9090"
echo " "
echo ">>> PRÓXIMO PASSO (IMPORTANTE) <<<"
echo "1. Abra o Cockpit > Navigator"
echo "2. Navegue até: $BRANDING_DIR"
echo "3. Apague o arquivo 'logo.png' (espiral vermelha)"
echo "4. Faça upload da logo do IFRO e renomeie para 'logo.png'"
echo " "
echo "Recomendado reiniciar o container (reboot) para"
echo "aplicar as configurações de rede 100%."
echo "==================================================="