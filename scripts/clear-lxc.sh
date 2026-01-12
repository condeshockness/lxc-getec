#!/usr/bin/env bash
# ==============================================================================
# PREPARAR LXC PARA TEMPLATE — MANTENDO CHAVE SSH DO SEMAPHORE
# Ambiente: Debian 13 LXC Proxmox
# Autor: Ramon Silas Shockness
# ==============================================================================

set -e

echo "==> Desabilitando login SSH do root..."
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config

echo "==> Bloqueando usuário root..."
passwd -l root

echo "==> Bloqueando root no Cockpit..."
echo root >> /etc/cockpit/disallowed-users || true
systemctl restart cockpit

echo "================ LIMPEZA PARA TEMPLATE LXC ================"

# ----------------------------------------------------------------------
# HISTÓRICO E CACHE
# ----------------------------------------------------------------------
echo "==> Limpando históricos e cache..."

rm -f /root/.bash_history
rm -f /home/*/.bash_history 2>/dev/null || true

find /var/log -type f -exec truncate -s 0 {} \;

apt clean
apt autoremove -y

# ----------------------------------------------------------------------
# MACHINE-ID (GERA NOVO NO CLONE)
# ----------------------------------------------------------------------
echo "==> Resetando machine-id..."

truncate -s 0 /etc/machine-id
rm -f /var/lib/dbus/machine-id
ln -sf /etc/machine-id /var/lib/dbus/machine-id

# ----------------------------------------------------------------------
# CHAVES SSH DO HOST (REGERADAS NO CLONE)
# ----------------------------------------------------------------------
echo "==> Removendo chaves SSH do host..."

rm -f /etc/ssh/ssh_host_*

# NÃO remove authorized_keys de usuários
# (semaphore permanece com acesso SSH)


# ----------------------------------------------------------------------
# TEMP E SOCKETS
# ----------------------------------------------------------------------
echo "==> Limpando temporários..."

rm -rf /tmp/*
rm -rf /var/tmp/*

# ----------------------------------------------------------------------
# REDE — GARANTE DHCP LIMPO
# ----------------------------------------------------------------------
echo "==> Limpando leases DHCP..."

rm -f /var/lib/NetworkManager/*lease*
rm -f /var/lib/dhcp/*

# ----------------------------------------------------------------------
# PRIMEIRO LOGIN (RESET PARA TODOS OS CLONES)
# ----------------------------------------------------------------------
echo "==> Resetando flags de primeiro login..."

rm -f /home/*/.first_login_done 2>/dev/null || true

# ----------------------------------------------------------------------
# SINCRONIZA DISCO
# ----------------------------------------------------------------------
sync

echo "==========================================================="
echo " PRONTO PARA CONVERTER EM TEMPLATE NO PROXMOX ✅"
echo " Usuário 'semaphore' e chave SSH foram PRESERVADOS 🔐"
echo " Agora desligue o container e converta para template."
echo "==========================================================="
