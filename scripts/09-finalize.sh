#!/bin/bash
################################################################################
# Script 09 - Finalizacao
################################################################################

source /root/nuopanel-install/common-functions.sh
source /root/nuopanel-install/config.env

main() {
    log_info "Finalizando instalacao..."
    
    save_os_info
    run_migrations
    reset_admin_password
    install_nuopanel_apps
    add_cronjobs
    copy_postfix_resolv
    copy_banner_ssh
    run_external_scripts
    restart_all_services
    cleanup
    display_success
    
    log_success "Instalacao finalizada"
}

save_os_info() {
    log_info "Salvando informacoes do SO..."
    echo -n "$OS_NAME" > "$PANEL_DIR/etc/osName"
    echo -n "$OS_VERSION" > "$PANEL_DIR/etc/osVersion"
}

run_migrations() {
    log_info "Executando migrations Django..."
    cd "$PANEL_DIR"
    "$VENV_PATH/bin/python" manage.py migrate --noinput
    
    if [ $? -ne 0 ]; then
        log_error "Falha ao executar migrations"
        return 1
    fi
    
    log_success "Migrations executadas"
}

reset_admin_password() {
    log_info "Configurando senha admin..."
    local DB_PASSWORD=$(get_password_from_file "$DB_USER_PASSWORD_FILE")
    "$VENV_PATH/bin/python" "$PANEL_DIR/manage.py" reset_admin_password "$DB_PASSWORD"
    log_success "Senha admin configurada"
}

install_nuopanel_apps() {
    log_info "Instalando aplicativos do painel..."
    "$VENV_PATH/bin/python" "$PANEL_DIR/manage.py" install_nuopanel
    log_success "Aplicativos instalados"
}

add_cronjobs() {
    log_info "Adicionando cronjobs..."
    
    local PYTHON_CMD="$VENV_PATH/bin/python"
    local MANAGE="$PANEL_DIR/manage.py"
    
    ( crontab -l 2>/dev/null | grep -v "$MANAGE"; cat <<EOF
0 * * * * $PYTHON_CMD $MANAGE backup --hour
0 0 * * * $PYTHON_CMD $MANAGE backup --day
0 0 * * 0 $PYTHON_CMD $MANAGE backup --week
0 0 1 * * $PYTHON_CMD $MANAGE backup --month
0 0 * * * $PYTHON_CMD $MANAGE check_version
0 */3 * * * $PYTHON_CMD $MANAGE limit_check
*/3 * * * * if ! find /home/*/* -maxdepth 2 \( -path "/home/vmail" -o -path "/home/nuopanel" -o -path "/home/*/logs" -o -path "/home/*/.trash" -o -path "/home/*/backup" \) -prune -o -type f -name '.htaccess' -newer /usr/local/lsws/cgid -exec false {} +; then /usr/local/lsws/bin/lswsctrl restart; fi
* * * * * /usr/local/bin/nuopanel --fail2ban >/dev/null 2>&1
EOF
) | crontab -
    
    log_success "Cronjobs adicionados"
}

copy_postfix_resolv() {
    log_info "Copiando resolv.conf para Postfix..."
    cp /etc/resolv.conf /var/spool/postfix/etc/resolv.conf
}

copy_banner_ssh() {
    log_info "Copiando banner SSH..."
    if [ -f "$ITEM_DIR/move/conf/banner-ssh.sh" ]; then
        cp "$ITEM_DIR/move/conf/banner-ssh.sh" /etc/profile.d/banner-ssh.sh
    else
        wget -q -O /etc/profile.d/banner-ssh.sh "$BANNER_SCRIPT_URL" || true
    fi
    chmod +x /etc/profile.d/banner-ssh.sh
}

run_external_scripts() {
    log_info "Executando scripts auxiliares..."
    
    # 1. Substituir placeholders de senha
    log_info "Substituindo placeholders de senha..."
    curl -sSL "$REPLACE_PASSWORDS_SCRIPT" | bash
    
    # 2. Gerar SSL autoassinado
    log_info "Gerando certificado SSL autoassinado..."
    curl -sSL "$GENERATE_SSL_SCRIPT" | bash
    
    # 3. Criar swap
    log_info "Configurando swap..."
    curl -sSL "$CREATE_SWAP_SCRIPT" | bash
    
    # 4. Instalar plugins
    log_info "Instalando plugins..."
    curl -sSL "$INSTALL_PLUGINS_SCRIPT" | bash
    
    log_success "Scripts auxiliares executados"
}

restart_all_services() {
    log_info "Reiniciando todos os servicos..."
    
    sudo systemctl restart pdns 2>/dev/null || true
    sudo systemctl restart postfix 2>/dev/null || true
    sudo systemctl restart dovecot 2>/dev/null || true
    sudo systemctl restart pure-ftpd-mysql 2>/dev/null || true
    sudo systemctl restart opendkim 2>/dev/null || true
    sudo systemctl restart cp 2>/dev/null || true
    sudo /usr/local/lsws/bin/lswsctrl restart 2>/dev/null || true
    
    log_success "Servicos reiniciados"
}

cleanup() {
    log_info "Limpando arquivos temporarios..."
    sudo rm -rf "$ITEM_DIR"
    sudo rm -f "$DB_ROOT_PASSWORD_FILE"
    sudo rm -f "$DB_USER_PASSWORD_FILE"
    sudo rm -f /root/webadmin
    log_success "Limpeza concluida"
}

display_success() {
    local GREEN='\033[38;5;83m'
    local NC='\033[0m'
    
    local IP=$(hostname -I | awk '{print $1}')
    if [[ $IP == 10.* || $IP == 172.* || $IP == 192.168.* ]]; then
        IP=$(curl -4 -m 10 -s ifconfig.me)
    fi
    
    local PORT=$(cat "$ITEM_DIR/port.txt" 2>/dev/null || echo "8011")
    local PASSWORD=$(cat "$PANEL_DIR/etc/mysqlPassword" 2>/dev/null || echo "verificar_no_servidor")
    
    echo ""
    echo "================================================================================"
    echo -e "${GREEN}NUOPANEL INSTALADO COM SUCESSO!${NC}"
    echo "================================================================================"
    echo ""
    echo "URL Admin:  https://${IP}:${PORT}"
    echo "Usuario:    admin"
    echo "Senha:      ${PASSWORD}"
    echo ""
    echo "================================================================================"
}

main
