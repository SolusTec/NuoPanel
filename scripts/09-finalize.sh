#!/bin/bash
################################################################################
# NuoPanel - 09 Finalization
# Descricao: Finalizacao, configuracoes finais e limpeza
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

copy_vhconf_files() {
    log_info "Copiando arquivos vhconf..."
    
    # VHost Example
    local source_example="$ITEM_DIR/move/conf/Example/vhconf.conf"
    local target_example="/usr/local/lsws/conf/vhosts/Example"
    
    if [ -f "$source_example" ]; then
        mkdir -p "$target_example"
        cp "$source_example" "$target_example/vhconf.conf"
        log_success "vhconf Example copiado"
    else
        log_warning "vhconf Example nao encontrado"
    fi
    
    # VHost mypanel
    local source_mypanel="$ITEM_DIR/move/conf/mypanel/vhconf.conf"
    local target_mypanel="/usr/local/lsws/conf/vhosts/mypanel"
    
    if [ -f "$source_mypanel" ]; then
        mkdir -p "$target_mypanel"
        cp "$source_mypanel" "$target_mypanel/vhconf.conf"
        log_success "vhconf mypanel copiado"
    else
        log_warning "vhconf mypanel nao encontrado"
    fi
}

copy_httpd_config() {
    log_info "Copiando httpd_config.conf..."
    
    local source_httpd="$ITEM_DIR/move/conf/httpd_config.conf"
    local target_httpd="/usr/local/lsws/conf/httpd_config.conf"
    
    if [ -f "$source_httpd" ]; then
        cp "$source_httpd" "$target_httpd"
        sudo systemctl restart "$SYSTEMD_SERVICE"
        log_success "httpd_config.conf copiado"
    else
        log_warning "httpd_config.conf nao encontrado"
    fi
}

copy_banner_ssh() {
    log_info "Instalando banner SSH..."
    
    # Baixar banner-ssh.sh
    wget -q -O /tmp/banner-ssh.sh "$BANNER_SCRIPT_URL"
    
    if [ -f /tmp/banner-ssh.sh ]; then
        cp /tmp/banner-ssh.sh /etc/profile.d/banner-ssh.sh
        chmod 755 /etc/profile.d/banner-ssh.sh
        log_success "Banner SSH instalado"
    else
        log_warning "Banner SSH nao encontrado, usando padrao"
        cat > /etc/profile.d/banner-ssh.sh << 'EOFBANNER'
#!/bin/bash
echo ""
echo "  _   _             ____                  _ "
echo " | \ | |_   _  ___|  _ \ __ _ _ __   ___| |"
echo " |  \| | | | |/ _ \ |_) / _\` | '_ \ / _ \ |"
echo " | |\  | |_| |  __/  __/ (_| | | | |  __/ |"
echo " |_| \_|\__,_|\___|_|   \__,_|_| |_|\___|_|"
echo ""
echo " Sistema de Gerenciamento de Hospedagem Web"
echo ""
EOFBANNER
        chmod 755 /etc/profile.d/banner-ssh.sh
    fi
}

setup_postfix_maps() {
    log_info "Configurando mapas Postfix..."
    
    if [ -f /etc/postfix/script_filter ]; then
        sudo postmap /etc/postfix/script_filter
    fi
    
    if [ -f /etc/postfix/vmail_ssl.map ]; then
        sudo postmap /etc/postfix/vmail_ssl.map
    fi
    
    log_success "Mapas Postfix configurados"
}

setup_opendkim_files() {
    log_info "Configurando OpenDKIM..."
    
    mkdir -p /etc/opendkim
    sudo touch /etc/opendkim/key.table
    sudo touch /etc/opendkim/signing.table
    sudo touch /etc/opendkim/TrustedHosts.table
    
    log_success "Arquivos OpenDKIM criados"
}

save_os_info() {
    log_info "Salvando informacoes do SO..."
    
    echo -n "$OS_NAME" > "$PANEL_DIR/etc/osName"
    echo -n "$OS_VERSION" > "$PANEL_DIR/etc/osVersion"
    
    log_success "Informacoes do SO salvas"
}

configure_pureftpd_passive_ip() {
    log_info "Configurando Pure-FTPd IP passivo..."
    
    local ip=$(hostname -I | awk '{print $1}')
    
    # Se for IP privado, pegar IP publico
    if [[ $ip == 10.* || $ip == 172.* || $ip == 192.168.* ]]; then
        ip=$(curl -4 -m 10 -s ifconfig.me)
        [[ -z $ip ]] && ip=$(hostname -I | awk '{print $1}')
    fi
    
    echo "$ip" | sudo tee /etc/pure-ftpd/conf/ForcePassiveIP > /dev/null
    
    log_success "IP passivo Pure-FTPd: $ip"
}

run_external_scripts() {
    log_info "Executando scripts externos de configuracao..."
    
    # Re-config script
    curl -sSL "$OLSPANEL_RE_CONFIG" | sed 's/\r$//' | bash
    
    # Setup missing SSL
    curl -sSL "$OLSPANEL_SSL_SETUP" | sed 's/\r$//' | bash
    
    log_success "Scripts externos executados"
}

update_systemd_service() {
    log_info "Atualizando systemd service..."
    
    local venv_python="$VENV_PATH/bin/python"
    local service_file="/etc/systemd/system/cp.service"
    
    if [ -f "$service_file" ]; then
        sed -i "s|/usr/bin/python3|$venv_python|g" "$service_file"
        systemctl daemon-reload
        log_success "Systemd service atualizado"
    fi
}

run_django_migrations() {
    log_info "Criando schema do banco via Django migrations..."
    
    cd "$PANEL_DIR"
    
    # Executar migrations
    "$VENV_PATH/bin/python" manage.py migrate --noinput
    
    if [ $? -eq 0 ]; then
        log_success "Schema do banco criado com sucesso"
    else
        log_error "Falha ao executar migrations"
        return 1
    fi
}

reset_admin_password() {
    log_info "Resetando senha admin..."
    
    local admin_password=$(cat "$DB_USER_PASSWORD_FILE" 2>/dev/null)
    
    if [ -n "$admin_password" ]; then
        "$VENV_PATH/bin/python" "$PANEL_DIR/manage.py" reset_admin_password "$admin_password"
        log_success "Senha admin resetada"
    fi
}

install_nuoapp() {
    log_info "Instalando Softaculous..."
    
    "$VENV_PATH/bin/python" "$PANEL_DIR/manage.py" install_nuoapp
    
    log_success "Softaculous instalado"
}

add_cronjobs() {
    log_info "Adicionando cronjobs..."
    
    local python_cmd="$VENV_PATH/bin/python"
    local backup_script="$PANEL_DIR/manage.py"
    
    local cron_jobs="\
0 * * * * $python_cmd $backup_script backup --hour
0 0 * * * $python_cmd $backup_script backup --day
0 0 * * 0 $python_cmd $backup_script backup --week
0 0 1 * * $python_cmd $backup_script backup --month
0 0 * * * $python_cmd $backup_script check_version
0 */3 * * * $python_cmd $backup_script limit_check
*/3 * * * * if ! find /home/*/* -maxdepth 2 \( -path \"/home/vmail\" -o -path \"/home/nuopanel\" -o -path \"/home/*/logs\" -o -path \"/home/*/.trash\" -o -path \"/home/*/backup\" \) -prune -o -type f -name '.htaccess' -newer /usr/local/lsws/cgid -exec false {} +; then /usr/local/lsws/bin/lswsctrl restart; fi
* * * * * /usr/local/bin/nuopanel --fail2ban >/dev/null 2>&1
"
    
    ( crontab -l 2>/dev/null | grep -v "$backup_script"; echo "$cron_jobs" ) | crontab -
    
    log_success "Cronjobs adicionados"
}

restart_all_services() {
    log_info "Reiniciando todos os servicos..."
    
    sudo systemctl restart pdns
    sudo systemctl restart postfix
    sudo systemctl restart dovecot
    sudo systemctl restart pure-ftpd-mysql
    sudo systemctl restart opendkim
    sudo systemctl restart cp
    sudo /usr/local/lsws/bin/lswsctrl restart
    
    log_success "Servicos reiniciados"
}

cleanup_installation() {
    log_info "Limpando arquivos temporarios..."
    
    sudo rm -rf "$ITEM_DIR"
    sudo rm -f "$DB_ROOT_PASSWORD_FILE"
    sudo rm -f "$DB_USER_PASSWORD_FILE"
    sudo rm -f /root/webadmin
    
    log_success "Limpeza concluida"
}

display_success_message() {
    local ip=$(hostname -I | awk '{print $1}')
    local port=$(cat "$ITEM_DIR/port.txt" 2>/dev/null || echo "8011")
    local password=$(cat "$DB_USER_PASSWORD_FILE" 2>/dev/null || echo "N/A")
    
    echo ""
    echo "================================================================================"
    log_success "NUOPANEL INSTALADO COM SUCESSO!"
    echo "================================================================================"
    echo ""
    echo "  URL Admin:  https://${ip}:${port}"
    echo "  Usuario:    admin"
    echo "  Senha:      ${password}"
    echo ""
    echo "================================================================================"
    echo ""
    log_info "Documentacao: https://github.com/SolusTec/NuoPanel"
    echo ""
}

################################################################################
# Main
################################################################################

main() {
    log_info "Iniciando finalizacao..."
    
    copy_vhconf_files
    copy_httpd_config
    copy_banner_ssh
    setup_postfix_maps
    setup_opendkim_files
    save_os_info
    configure_pureftpd_passive_ip
    run_external_scripts
    update_systemd_service
    run_django_migrations      # ← CRIA SCHEMA DO BANCO
    reset_admin_password       # ← PRECISA VIR DEPOIS DAS MIGRATIONS
    install_nuoapp
    add_cronjobs
    restart_all_services
    cleanup_installation
    
    display_success_message
    
    log_success "Instalacao finalizada"
}

main "$@"
