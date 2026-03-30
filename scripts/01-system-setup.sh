#!/bin/bash
################################################################################
# Script 01 - Configuracao do Sistema
################################################################################

source /root/nuopanel-install/common-functions.sh
source /root/nuopanel-install/config.env

main() {
    log_info "Iniciando configuracao do sistema..."
    
    install_sudo
    configure_dns
    disable_kernel_message
    suppress_restart_prompts
    install_basic_packages
    create_work_directories
    setup_firewall
    disable_systemd_resolved
    
    log_success "Configuracao do sistema concluida"
}

install_sudo() {
    if ! command -v sudo &> /dev/null; then
        log_info "Instalando sudo..."
        if [ "$(id -u)" -ne 0 ]; then
            su -c "apt update && apt install sudo -y"
        else
            apt update && apt install sudo -y
        fi
    else
        log_debug "sudo ja instalado"
    fi
}

configure_dns() {
    log_info "Configurando DNS fixo..."
    echo "nameserver 8.8.8.8" > /etc/resolv.conf
    echo "nameserver 1.1.1.1" >> /etc/resolv.conf
    log_success "DNS configurado"
}

disable_kernel_message() {
    log_info "Desabilitando mensagens de upgrade do kernel..."
    sudo sed -i 's/^#\?\(\$nrconf{kernelhints} = \).*/\1 0;/' /etc/needrestart/needrestart.conf 2>/dev/null || true
    sudo sed -i 's/^#\?\(\$nrconf{restart} = \).*/\1"a";/' /etc/needrestart/needrestart.conf 2>/dev/null || true
    sudo systemctl restart needrestart 2>/dev/null || true
    log_success "Mensagens de kernel desabilitadas"
}

suppress_restart_prompts() {
    log_info "Suprimindo prompts de reinicializacao..."
    sudo sed -i 's/#\$nrconf{restart} = '\''i'\'';/\$nrconf{restart} = '\''a'\'';/' /etc/needrestart/needrestart.conf 2>/dev/null || true
    sudo sed -i 's/#$nrconf{restart} = '\''i'\'';/$nrconf{restart} = '\''a'\'';/' /etc/needrestart/needrestart.conf 2>/dev/null || true
    log_success "Prompts suprimidos"
}

install_basic_packages() {
    log_info "Instalando pacotes basicos..."
    wait_for_apt_lock
    sudo apt update
    sudo apt upgrade -y
    sudo apt install -y wget curl zip unzip tar bind9-dnsutils ufw libwww-perl pkg-config software-properties-common
    log_success "Pacotes basicos instalados"
}

create_work_directories() {
    log_info "Criando diretorios de trabalho..."
    mkdir -p "$WORK_DIR"
    mkdir -p "$ITEM_DIR"
    mkdir -p "$LOG_DIR"
    log_success "Diretorios criados"
}

setup_firewall() {
    log_info "Configurando firewall (UFW)..."
    sudo systemctl enable ufw
    sudo systemctl start ufw
    echo "y" | sudo ufw enable
    
    for port in $FIREWALL_PORTS; do
        sudo ufw allow ${port}/tcp
        log_debug "Porta ${port}/tcp liberada"
    done
    
    sudo ufw allow ${FTP_PASSIVE_RANGE}/tcp
    sudo ufw allow 53/udp
    sudo ufw reload
    log_success "Firewall configurado"
}

disable_systemd_resolved() {
    log_info "Desabilitando systemd-resolved..."
    sudo systemctl stop systemd-resolved 2>/dev/null || true
    sudo systemctl disable systemd-resolved 2>/dev/null || true
    sudo systemctl restart systemd-networkd 2>/dev/null || true
    log_success "systemd-resolved desabilitado"
}

main
