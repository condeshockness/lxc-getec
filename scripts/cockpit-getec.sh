#!/usr/bin/env bash
# ==============================================================================
# Personalizar: COCKPIT v353+ (Bleeding Edge)
# Projeto: GETEC IFRO
# Ambiente: Debian 13 LXC Proxmox
# Autor: Ramon Silas Shockness
# ==============================================================================
set -e

# ==============================================================================
# AVISO LEGAL — ANTES DO LOGIN (TTY + SSH)
# ==============================================================================
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

# ==============================================================================
# DESATIVAR MOTD PADRÃO
# ==============================================================================
echo "==> Desativando MOTD padrão do Debian..."

rm -f /etc/motd
if [ -d /etc/update-motd.d ]; then
  chmod -x /etc/update-motd.d/* || true
fi

# ==============================================================================
# HOSTNAME AUTOMÁTICO: aluno-<CTID> (EXECUTA SÓ UMA VEZ)
# ==============================================================================
echo "==> Configurando hostname automático baseado no CTID do Proxmox..."

cat <<'EOF' >/usr/local/sbin/set-hostname-from-ctid.sh
#!/usr/bin/env bash
set -e

FLAG="/etc/hostname.lock"
[ -f "$FLAG" ] && exit 0

# Detecta CTID real do LXC pelo cgroup
CTID=$(basename "$(cat /proc/1/cpuset 2>/dev/null)" | tr -cd '0-9')

[ -z "$CTID" ] && exit 0

NEW_HOST="aluno-${CTID}"

echo "$NEW_HOST" > /etc/hostname
hostnamectl set-hostname "$NEW_HOST" --static

touch "$FLAG"
EOF


chmod +x /usr/local/sbin/set-hostname-from-ctid.sh

cat <<'EOF' >/etc/systemd/system/set-hostname-from-ctid.service
[Unit]
Description=Define hostname aluno-<CTID> no primeiro boot
After=systemd-remount-fs.service
Wants=systemd-remount-fs.service

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/set-hostname-from-ctid.sh

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable set-hostname-from-ctid.service

# ==============================================================================
# BANNER PÓS-LOGIN (DINÂMICO + CPU/RAM + PRIMEIRO LOGIN DO ALUNO)
# ==============================================================================
echo "==> Configurando banner GETEC pós-login (dinâmico)..."

cat <<'EOF' >/etc/profile.d/getec-banner.sh
#!/usr/bin/env bash

USER_NAME=$(whoami)
HOST=$(hostname)
IP_ADDR=$(hostname -I | awk '{print $1}')
OS_NAME=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d= -f2 | tr -d '"')

# ==== CPU (% aproximado) ====
CPU_IDLE=$(top -bn1 | awk '/Cpu\(s\)/ {print $8}' | cut -d. -f1)
CPU_USED=$((100 - CPU_IDLE))

# ==== RAM ====
MEM_USED=$(free -m | awk '/Mem:/ {print $3}')
MEM_TOTAL=$(free -m | awk '/Mem:/ {print $2}')

FIRST_FLAG="$HOME/.first_login_done"

clear
echo
echo "LXC base"
echo "    🌐   GETEC IFRO"
echo
echo "    🖥️   OS: ${OS_NAME}"
echo "    🏠   Hostname: ${HOST}"
echo "    💡   IP Address: ${IP_ADDR}"
echo "    ⚙️   CPU em uso: ${CPU_USED}%"
echo "    🧠   RAM: ${MEM_USED}MB / ${MEM_TOTAL}MB"
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

# ===== Aviso educativo no primeiro login do aluno =====
if [ "$USER_NAME" = "aluno" ] && [ ! -f "$FIRST_FLAG" ]; then
  echo
  echo "    🔐  IMPORTANTE:"
  echo "        Sua senha foi alterada neste primeiro acesso."
  echo "        GUARDE SUA SENHA para não perder o acesso ao laboratório."
  echo
  touch "$FIRST_FLAG"
fi

echo
echo "------------------------------------------------------------"
echo
EOF

chmod +x /etc/profile.d/getec-banner.sh

# ==============================================================================
# PERSONALIZAÇÃO DO COCKPIT (BRANDING)
# ==============================================================================
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
#badge {
  inline-size: 96px;
  block-size: 96px;
  background-image: url("logo.jpg");
  background-size: contain;
  background-repeat: no-repeat;
  background-position: center;
}

#brand::before {
  content: "GETEC";
}

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
