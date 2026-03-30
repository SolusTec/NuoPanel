#!/bin/bash
################################################################################
# NuoPanel - Create Swap File
# Descricao: Cria arquivo swap se necessario
################################################################################

SWAP_FILE="/nuopanel.swap"

echo "Verificando configuracao de swap..."

# Obter RAM e SWAP em MiB
TOTAL_RAM=$(free -m | awk '/^Mem:/ { print $2 }')
TOTAL_SWAP=$(free -m | awk '/^Swap:/ { print $2 }')

echo "RAM total: ${TOTAL_RAM}MB"
echo "SWAP atual: ${TOTAL_SWAP}MB"

# Calcular swap necessario
SET_SWAP=$((TOTAL_RAM - TOTAL_SWAP))

# Verificar se arquivo swap ja existe
if [ -f "$SWAP_FILE" ]; then
    echo "Arquivo swap ja existe em $SWAP_FILE"
    exit 0
fi

# Verificar se ja tem swap suficiente
if [[ $TOTAL_SWAP -ge $TOTAL_RAM ]]; then
    echo "Swap suficiente ja existe: ${TOTAL_SWAP}MB"
    exit 0
fi

# Limitar swap a 2GB maximo
if [[ $SET_SWAP -gt 2048 ]]; then
    SET_SWAP=2048
fi

echo "Criando arquivo swap de ${SET_SWAP}MB em $SWAP_FILE..."

# Criar arquivo swap
sudo fallocate -l "${SET_SWAP}M" "$SWAP_FILE" || \
sudo dd if=/dev/zero of="$SWAP_FILE" bs=1M count="$SET_SWAP"

sudo chmod 600 "$SWAP_FILE"
sudo mkswap "$SWAP_FILE"
sudo swapon "$SWAP_FILE"

# Adicionar ao fstab
if ! grep -q "$SWAP_FILE" /etc/fstab; then
    echo "$SWAP_FILE swap swap sw 0 0" | sudo tee -a /etc/fstab > /dev/null
fi

# Configurar swappiness
sudo sysctl vm.swappiness=10
if ! grep -q "vm.swappiness" /etc/sysctl.conf; then
    echo "vm.swappiness = 10" | sudo tee -a /etc/sysctl.conf > /dev/null
fi

echo "Swap de ${SET_SWAP}MB configurado com sucesso"
swapon --show
