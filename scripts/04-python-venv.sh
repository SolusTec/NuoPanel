#!/bin/bash
################################################################################
# NuoPanel - 04 Python Virtual Environment
# Descricao: Instalacao e configuracao do Python Virtual Environment
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
# Funcoes (extraidas do panel.sh original)
################################################################################

install_pip() {
    log_info "Atualizando sistema..."
    wait_for_apt_lock
    sudo apt update && sudo apt upgrade -y
    
    log_info "Instalando Python..."
    wait_for_apt_lock
    sudo apt install python3 python3-venv python3-pip pkg-config libmysqlclient-dev -y
    
    log_info "Criando virtual environment..."
    python3 -m venv "$VENV_PATH"
    source "$VENV_PATH/bin/activate"
    
    log_info "Atualizando pip e setuptools..."
    pip install --upgrade pip setuptools
    
    log_info "Instalando mysqlclient..."
    pip install --no-binary :all: mysqlclient
    
    deactivate
    
    log_success "Python e pip configurados"
}

install_python_dependencies_in_venv() {
    log_info "Baixando requirements.txt..."
    wget -O "$WORK_DIR/ub24req.txt" "$REQUIREMENTS_URL"
    
    if [ ! -f "$WORK_DIR/ub24req.txt" ]; then
        log_error "Falha ao baixar requirements.txt"
        return 1
    fi
    
    log_info "Instalando dependencias Python no virtual environment..."
    
    if [ ! -d "$VENV_PATH" ]; then
        log_info "Criando virtual environment..."
        python3 -m venv "$VENV_PATH"
    fi
    
    source "$VENV_PATH/bin/activate"
    
    log_info "Atualizando pip e instalando pacotes..."
    "$VENV_PATH/bin/python3" -m pip install --upgrade pip
    "$VENV_PATH/bin/python3" -m pip install -r "$WORK_DIR/ub24req.txt"
    
    deactivate
    
    if [ $? -eq 0 ]; then
        log_success "Dependencias Python instaladas"
    else
        log_error "Falha ao instalar dependencias Python"
        return 1
    fi
}

install_python_dependencies() {
    log_info "Instalando dependencias Python..."
    
    if command -v pip3 &> /dev/null; then
        install_python_dependencies_in_venv
        
        if [ $? -eq 0 ]; then
            log_success "Dependencias Python instaladas com sucesso"
        else
            log_warning "Falha ao instalar dependencias Python"
        fi
    else
        log_error "pip3 nao esta instalado"
        return 1
    fi
}

################################################################################
# Main
################################################################################

main() {
    log_info "Iniciando configuracao Python Virtual Environment..."
    
    install_pip
    install_python_dependencies
    
    log_success "Python Virtual Environment configurado"
}

main "$@"
