#!/bin/bash
################################################################################
# NuoPanel - 01 System Setup
# Descricao: Configuracao inicial do sistema Ubuntu
################################################################################

# Carregar funcoes comuns
source /root/nuopanel-install/common-functions.sh 2>/dev/null || \
    source "$(dirname "$0")/common-functions.sh" 2>/dev/null || \
    { echo "ERRO: common-functions.sh nao encontrado"; exit 1; }

# Carregar configuracoes
source /root/nuopanel-install/config.env 2>/dev/null || \
    source "$(dirname "$0")/config.env" 2>/dev/null || \
    { echo "ERRO: config.env nao encontrado"; exit 1; }

################################################################################
# Funcoes
################################################################################

install_sudo() {
    if ! command -v sudo &> /dev/null; then
        log_info "sudo nao encontrado. Instalando..."
        if [ "$(id -u)" -ne 0 ]; then
            log_info "Trocando para root para instalar sudo"
            su -c "apt update && apt install sudo -y"
        else
            apt update && apt install sudo -y
        fi
        log_success "sudo instalado"
    else
        log_debug "sudo ja instalado"
    fi
}

disable_kernel_message() {
    log_info "Desabilitando mensagens de upgrade do kernel..."
    sudo sed -i 's/^#\?\(\$nrconf{kernelhints} = \).*/\1 0;/' /etc/needrestart/needrestart.conf
    sudo sed -i 's/^#\?\(\$nrconf{restart} = \).*/\1"a";/' /etc/needrestart/needrestart.conf
    sudo systemctl restart needrestart
    log_success "Mensagens de kernel desabilitadas"
}

suppress_restart_prompts() {
    log_info "Suprimindo prompts de reinicializacao..."
    sudo sed -i 's/#\$nrconf{restart} = '"'"'i'"'"';/\$nrconf{restart} = '"'"'a'"'"';/' /etc/needrestart/needrestart.conf
    sudo sed -i 's/#$nrconf{restart} = '"'"'i'"'"';/$nrconf{restart} = '"'"'a'"'"';/' /etc/needrestart/needrestart.conf
    log_success "Prompts suprimidos"
}

install_basic_packages() {
    log_info "Instalando pacotes basicos..."
    wait_for_apt_lock
    sudo apt update
    sudo apt upgrade -y
    sudo apt install -y \
        wget \
        curl \
        zip \
        unzip \
        tar \
        bind9-dnsutils \
        ufw \
        libwww-perl \
        pkg-config \
        software-properties-common
    log_success "Pacotes basicos instalados"
}

setup_firewall() {
    log_info "Configurando firewall (UFW)..."
    sudo systemctl enable ufw
    sudo systemctl start ufw
    echo "y" | sudo ufw enable
    
    for port in $FIREWALL_PORTS; do
        sudo ufw allow "$port/tcp" >/dev/null 2>&1
        log_debug "Porta $port/tcp liberada"
    done
    
    sudo ufw allow "$FTP_PASSIVE_RANGE/tcp" >/dev/null 2>&1
    sudo ufw allow 53/udp >/dev/null 2>&1
    sudo ufw reload >/dev/null 2>&1
    
    log_success "Firewall configurado"
}

create_work_directories() {
    log_info "Criando diretorios de trabalho..."
    mkdir -p "$WORK_DIR"
    mkdir -p "$ITEM_DIR"
    mkdir -p "$LOG_DIR"
    log_success "Diretorios criados"
}

disable_systemd_resolved() {
    log_info "Desabilitando systemd-resolved..."
    sudo systemctl stop systemd-resolved >/dev/null 2>&1
    sudo systemctl disable systemd-resolved >/dev/null 2>&1
    sudo systemctl restart systemd-networkd >/dev/null 2>&1
    log_success "systemd-resolved desabilitado"
}

################################################################################
# Main
################################################################################

main() {
    log_info "Iniciando configuracao do sistema..."
    
    install_sudo
    disable_kernel_message
    suppress_restart_prompts
    install_basic_packages
    create_work_directories
    setup_firewall
    disable_systemd_resolved
    
    log_success "Configuracao do sistema concluida"
}

main "$@"
