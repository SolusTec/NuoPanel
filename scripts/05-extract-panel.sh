#!/bin/bash
################################################################################
# NuoPanel - 05 Extract Panel
# Descricao: Extracao e configuracao dos arquivos do painel
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

download_install_files() {
    log_info "Baixando arquivos de instalacao..."
    
    # Baixar install.zip
    if wget -O "$ITEM_DIR/install.zip" "$INSTALL_ZIP_URL" 2>/dev/null; then
        unzip -q "$ITEM_DIR/install.zip" -d "$ITEM_DIR/"
        log_success "install.zip extraido"
    else
        log_warning "Falha ao baixar install.zip"
    fi
}

unzip_and_move() {
    log_info "Baixando panel_latest.zip..."
    
    if ! wget -O "$ITEM_DIR/panel_setup.zip" "$PANEL_ZIP_URL"; then
        log_error "Falha ao baixar panel_latest.zip"
        return 1
    fi
    
    local zip_file="$ITEM_DIR/panel_setup.zip"
    local extract_dir="$ITEM_DIR/cp"
    local target_dir="/usr/local/lsws/Example/html"
    
    if [ ! -f "$zip_file" ]; then
        log_error "Arquivo $zip_file nao existe"
        return 1
    fi
    
    if [ ! -d "$target_dir" ]; then
        mkdir -p "$target_dir"
    fi
    
    if [ ! -d "$extract_dir" ]; then
        mkdir -p "$extract_dir"
    fi
    
    log_info "Extraindo panel_setup.zip..."
    unzip -q -o "$zip_file" -d "$extract_dir"
    
    if [ $? -ne 0 ]; then
        log_error "Falha ao extrair panel_setup.zip"
        return 1
    fi
    
    log_info "Movendo arquivos para $target_dir..."
    mv "$extract_dir"/* "$target_dir"
    
    log_success "Arquivos do painel extraidos"
}

remove_files_in_html_folder() {
    local target_dir="/usr/local/lsws/Example/html"
    local files_to_remove="index.html phpinfo.php upload.html upload.php"
    
    log_info "Removendo arquivos padrao do OpenLiteSpeed..."
    
    for file in $files_to_remove; do
        file_path="$target_dir/$file"
        if [ -f "$file_path" ]; then
            rm -f "$file_path"
            log_debug "Removido: $file"
        fi
    done
    
    log_success "Arquivos padrao removidos"
}

set_ownership_and_permissions() {
    log_info "Configurando permissoes e propriedades..."
    
    sudo chown -R www-data:www-data /usr/local/lsws/Example/html/phpmyadmin 
    sudo chmod -R 755 /usr/local/lsws/Example/html/phpmyadmin 
    
    sudo chown -R www-data:www-data /usr/local/lsws/Example/html/mypanel
    sudo chmod -R 755 /usr/local/lsws/Example/html/mypanel
    
    sudo chown -R www-data:www-data /usr/local/lsws/Example/html/webmail
    sudo chmod -R 755 /usr/local/lsws/Example/html/webmail
    
    sudo groupadd nobody 2>/dev/null || true
    sudo groupadd nuopanel 2>/dev/null || true
    
    sudo chown -R nobody:nobody /usr/local/lsws/Example/html/webmail/data
    sudo chmod -R 755 /usr/local/lsws/Example/html/webmail/data
    
    log_success "Permissoes configuradas"
}

################################################################################
# Main
################################################################################

main() {
    log_info "Iniciando extracao do painel..."
    
    download_install_files
    remove_files_in_html_folder
    unzip_and_move
    set_ownership_and_permissions
    
    log_success "Extracao do painel concluida"
}

main "$@"
