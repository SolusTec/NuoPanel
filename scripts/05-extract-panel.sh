#!/bin/bash
################################################################################
# Script 05 - Extrair Painel Django
################################################################################

source /root/nuopanel-install/common-functions.sh
source /root/nuopanel-install/config.env

main() {
    log_info "Extraindo painel Django..."
    
    download_install_zip
    download_panel_zip
    extract_panel
    set_permissions
    copy_mysql_password
    
    log_success "Painel extraido"
}

download_install_zip() {
    log_info "Baixando install.zip..."
    wget -q -O "$ITEM_DIR/install.zip" "$INSTALL_ZIP_URL" 2>/dev/null
    
    if [ $? -ne 0 ]; then
        log_warning "Falha ao baixar install.zip"
        return 1
    fi
    
    unzip -q "$ITEM_DIR/install.zip" -d "$ITEM_DIR/"
    log_success "install.zip extraido"
}

download_panel_zip() {
    log_info "Baixando panel_latest.zip..."
    wget -q -O "$ITEM_DIR/panel_setup.zip" "$PANEL_ZIP_URL"
    
    if [ $? -ne 0 ]; then
        log_error "Falha ao baixar panel_latest.zip"
        return 1
    fi
    
    log_success "panel_latest.zip baixado"
}

extract_panel() {
    local extract_dir="$ITEM_DIR/cp"
    local target_dir="/usr/local/lsws/Example/html"
    
    log_info "Extraindo painel para $target_dir..."
    
    mkdir -p "$extract_dir"
    mkdir -p "$target_dir"
    
    unzip -q "$ITEM_DIR/panel_setup.zip" -d "$extract_dir"
    mv "$extract_dir"/* "$target_dir"
    
    # Remover arquivos default
    rm -f "$target_dir/index.html" "$target_dir/phpinfo.php" "$target_dir/upload.html" "$target_dir/upload.php"
    
    log_success "Painel extraido"
}

set_permissions() {
    log_info "Configurando permissoes..."
    
    sudo chown -R www-data:www-data /usr/local/lsws/Example/html/phpmyadmin 2>/dev/null || true
    sudo chmod -R 755 /usr/local/lsws/Example/html/phpmyadmin 2>/dev/null || true
    
    sudo chown -R www-data:www-data /usr/local/lsws/Example/html/mypanel
    sudo chmod -R 755 /usr/local/lsws/Example/html/mypanel
    
    sudo chown -R www-data:www-data /usr/local/lsws/Example/html/webmail 2>/dev/null || true
    sudo chmod -R 755 /usr/local/lsws/Example/html/webmail 2>/dev/null || true
    
    sudo groupadd nobody 2>/dev/null || true
    sudo groupadd nuopanel 2>/dev/null || true
    
    sudo chown -R nobody:nobody /usr/local/lsws/Example/html/webmail/data 2>/dev/null || true
    sudo chmod -R 755 /usr/local/lsws/Example/html/webmail/data 2>/dev/null || true
    
    log_success "Permissoes configuradas"
}

copy_mysql_password() {
    log_info "Copiando senha MySQL para painel..."
    
    local source_file="$DB_ROOT_PASSWORD_FILE"
    local target_dir="$PANEL_DIR/etc"
    local target_file="$target_dir/mysqlPassword"
    
    if [ ! -f "$source_file" ]; then
        log_error "Senha MySQL nao encontrada"
        return 1
    fi
    
    mkdir -p "$target_dir"
    cp "$source_file" "$target_file"
    chmod 600 "$target_file"
    
    log_success "Senha copiada"
}

main
