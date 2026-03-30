#!/bin/bash
################################################################################
# Script 08 - Softaculous/NuoApp
################################################################################

source /root/nuopanel-install/common-functions.sh
source /root/nuopanel-install/config.env

main() {
    log_info "Instalando Softaculous (NuoApp)..."
    
    download_softaculous
    extract_softaculous
    set_permissions
    run_django_command
    
    log_success "Softaculous instalado"
}

download_softaculous() {
    local DEST_DIR="/usr/local/lsws/Example/html"
    local ZIP_FILE="$ITEM_DIR/softaculous.zip"
    
    log_info "Baixando softaculous.zip..."
    wget -q -O "$ZIP_FILE" "$SOFTACULOUS_ZIP_URL"
    
    if [ $? -ne 0 ]; then
        log_error "Falha ao baixar softaculous.zip"
        return 1
    fi
    
    log_success "softaculous.zip baixado"
}

extract_softaculous() {
    local ZIP_FILE="$ITEM_DIR/softaculous.zip"
    local DEST_DIR="/usr/local/lsws/Example/html/olsapp"
    
    log_info "Extraindo para $DEST_DIR..."
    mkdir -p "$DEST_DIR"
    unzip -q -o "$ZIP_FILE" -d "$DEST_DIR"
    rm -f "$ZIP_FILE"
    
    log_success "Softaculous extraido"
}

set_permissions() {
    local DEST_DIR="/usr/local/lsws/Example/html/olsapp"
    
    log_info "Configurando permissoes..."
    
    # Criar usuario nuopanel se nao existir
    if ! id -u nuopanel &>/dev/null; then
        sudo useradd -r -s /bin/false nuopanel 2>/dev/null || true
    fi
    
    sudo chown -R nuopanel:nuopanel "$DEST_DIR" 2>/dev/null || \
    sudo chown -R www-data:www-data "$DEST_DIR"
    
    log_success "Permissoes configuradas"
}

run_django_command() {
    log_info "Executando comando Django install_nuopanel..."
    
    cd "$PANEL_DIR"
    "$VENV_PATH/bin/python" manage.py install_nuopanel
    
    if [ $? -ne 0 ]; then
        log_warning "Comando install_nuopanel falhou (pode ser normal se nao existir)"
    else
        log_success "Comando Django executado"
    fi
}

main
