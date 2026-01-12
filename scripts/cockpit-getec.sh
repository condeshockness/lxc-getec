#!/usr/bin/env bash
# ==============================================================================
# Personalizar: COCKPIT v353+ (Bleeding Edge)
# Projeto: GETEC IFRO
# Ambiente: Debian 13 LXC Proxmox
# Autor: Ramon Silas Shockness
# ==============================================================================
set -e

#Personalização de login
echo "==> Configurando aviso legal institucional (antes do login)..."

cat <<'EOF' >/etc/issue
********************************************************************
*  SISTEMA INSTITUCIONAL - GETEC IFRO                               *
*                                                                  *
*  O acesso é restrito a usuários autorizados.                     *
*  Atividades podem ser monitoradas e registradas.                *
*  Uso indevido está sujeito às penalidades previstas em lei.     *
********************************************************************
EOF

cp /etc/issue /etc/issue.net

echo "==> Desativando MOTD padrão do Debian..."

rm -f /etc/motd
if [ -d /etc/update-motd.d ]; then
  chmod -x /etc/update-motd.d/* || true
fi

echo "==> Configurando banner GETEC pós-login (dinâmico)..."

cat <<'EOF' >/etc/profile.d/getec-banner.sh
#!/usr/bin/env bash

USER_NAME=$(whoami)
HOST=$(hostname)
IP_ADDR=$(hostname -I | awk '{print $1}')
OS_NAME=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d= -f2 | tr -d '"')

clear

echo
echo "LXC base"
echo "    🌐   GETEC IFRO"
echo
echo "    🖥️   OS: ${OS_NAME}"
echo "    🏠   Hostname: ${HOST}"
echo "    💡   IP Address: ${IP_ADDR}"
echo

# ===== Mensagem por tipo de usuário =====
case "$USER_NAME" in
  aluno)
    echo "    📘  Ambiente de estudos — utilize apenas para atividades acadêmicas."
    ;;
  professor)
    echo "    📗  Ambiente docente — utilize com responsabilidade institucional."
    ;;
  semaphore)
    echo "    🤖  Conta de automação — acesso restrito."
    ;;
  *)
    echo "    👤  Usuário: ${USER_NAME}"
    ;;
esac

echo
echo "------------------------------------------------------------"
echo
EOF

chmod +x /etc/profile.d/getec-banner.sh


#Personalização cockpit


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
