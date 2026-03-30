#!/bin/bash
################################################################################
# Script 04 - Python e Virtual Environment
################################################################################

source /root/nuopanel-install/common-functions.sh
source /root/nuopanel-install/config.env

main() {
    log_info "Configurando Python..."
    
    install_python_deps
    create_venv
    install_requirements
    
    log_success "Python configurado"
}

install_python_deps() {
    log_info "Instalando dependencias Python..."
    wait_for_apt_lock
    sudo apt install -y python3 python3-venv python3-pip pkg-config libmysqlclient-dev build-essential python3-dev libssl-dev
    
    if [ $? -ne 0 ]; then
        log_error "pip3 nao esta instalado"
        return 1
    fi
    
    log_success "Dependencias instaladas"
}

create_venv() {
    log_info "Criando virtual environment..."
    python3 -m venv "$VENV_PATH"
    source "$VENV_PATH/bin/activate"
    pip install --upgrade pip setuptools
    pip install --no-binary :all: mysqlclient
    deactivate
    log_success "Virtual environment criado"
}

install_requirements() {
    log_info "Baixando requirements..."
    wget -q -O "$WORK_DIR/ubuntu.txt" "$REQUIREMENTS_UBUNTU_URL"
    
    log_info "Instalando pacotes Python..."
    source "$VENV_PATH/bin/activate"
    "$VENV_PATH/bin/python3" -m pip install --upgrade pip
    "$VENV_PATH/bin/python3" -m pip install -r "$WORK_DIR/ubuntu.txt"
    deactivate
    
    log_success "Pacotes Python instalados"
}

main
