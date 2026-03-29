#!/bin/bash
################################################################################
# NuoPanel - 02 OpenLiteSpeed Installation
# Descricao: Instalacao e configuracao do OpenLiteSpeed e PHP
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

install_openlitespeed() {
    local admin_password="$1"
    
    log_info "Instalando OpenLiteSpeed Web Server..."
    
    wget -O /tmp/openlitespeed.sh https://repo.litespeed.sh
    sudo bash /tmp/openlitespeed.sh
    sudo apt install openlitespeed -y
    
    if command -v lswsctrl &> /dev/null; then
        log_success "OpenLiteSpeed instalado"
        
        log_info "Iniciando OpenLiteSpeed..."
        sudo /usr/local/lsws/bin/lswsctrl start
        sudo systemctl enable "$SYSTEMD_SERVICE"
        
        local version=$(sudo /usr/local/lsws/bin/lshttpd -v)
        log_info "Versao: $version"
    else
        log_error "Falha na instalacao do OpenLiteSpeed"
        return 1
    fi
}

change_ols_password() {
    local webadmin_pass="$1"
    
    if [ -z "$webadmin_pass" ]; then
        log_error "Senha nao fornecida para o WebAdmin"
        return 1
    fi
    
    log_info "Configurando senha do WebAdmin..."
    
    local encrypt_string=$(/usr/local/lsws/admin/fcgi-bin/admin_php /usr/local/lsws/admin/misc/htpasswd.php "${webadmin_pass}")
    
    if [ $? -ne 0 ]; then
        log_error "Falha ao criptografar senha"
        return 1
    fi
    
    echo "admin:$encrypt_string" > /usr/local/lsws/admin/conf/htpasswd
    chown lsadm:lsadm /usr/local/lsws/admin/conf/htpasswd
    chmod 600 /usr/local/lsws/admin/conf/htpasswd
    
    echo "${webadmin_pass}" > /root/webadmin
    chmod 600 /root/webadmin
    
    log_success "Senha do WebAdmin configurada"
}

install_all_lsphp_versions() {
    log_info "Instalando versoes PHP: $PHP_VERSIONS"
    log_info "Versao padrao: PHP ${PHP_DEFAULT_VERSION}"
    
    sudo apt-get install -y software-properties-common
    sudo add-apt-repository -y ppa:openlitespeed/php
    
    for version in $PHP_VERSIONS; do
        log_info "Instalando PHP $version..."
        
        sudo apt-get install -y \
            lsphp"$version" \
            lsphp"$version"-common \
            lsphp"$version"-mysql \
            lsphp"$version"-curl \
            lsphp"$version"-json
        
        if [ -x "/usr/local/lsws/lsphp$version/bin/php" ]; then
            log_success "PHP $version instalado"
            
            php_version=$(echo "$version" | awk '{print substr($0,1,1) "." substr($0,2,1)}')
            
            ini_file_path="/usr/local/lsws/lsphp$version/etc/php/$php_version/litespeed/php.ini"
            ini_file_path_old="/usr/local/lsws/lsphp$version/etc/php.ini"
            
            if [ -f "$ini_file_path" ]; then
                target_ini="$ini_file_path"
            elif [ -f "$ini_file_path_old" ]; then
                target_ini="$ini_file_path_old"
            else
                log_warning "php.ini nao encontrado para PHP $php_version"
                continue
            fi
            
            log_debug "Configurando $target_ini..."
            sudo sed -i 's/^disable_functions\s*=.*/disable_functions = pcntl_alarm,pcntl_fork,pcntl_waitpid,pcntl_wait,pcntl_wifexited,pcntl_wifstopped,pcntl_wifsignaled,pcntl_wifcontinued,pcntl_wexitstatus,pcntl_wtermsig,pcntl_wstopsig,pcntl_signal,pcntl_signal_get_handler,pcntl_signal_dispatch,pcntl_get_last_error,pcntl_strerror,pcntl_sigprocmask,pcntl_sigwaitinfo,pcntl_sigtimedwait,pcntl_exec,pcntl_getpriority,pcntl_setpriority,pcntl_async_signals,pcntl_unshare/' "$target_ini"
            sudo sed -i 's/^upload_max_filesize\s*=.*/upload_max_filesize = 80M/' "$target_ini"
            sudo sed -i 's/^post_max_size\s*=.*/post_max_size = 80M/' "$target_ini"
        else
            log_warning "Falha ao instalar PHP $version"
        fi
    done
    
    pkill lsphp 2>/dev/null || true
    
    log_success "Instalacao de versoes PHP concluida"
}

set_default_php_version() {
    log_info "Configurando PHP ${PHP_DEFAULT_VERSION} como versao padrao..."
    
    if [ -f "$OLS_CONF_DIR/httpd_config.conf" ]; then
        sudo sed -i "s|path.*lsphp[0-9]*/bin/lsphp|path                    lsphp${PHP_DEFAULT_VERSION}/bin/lsphp|g" "$OLS_CONF_DIR/httpd_config.conf"
        log_success "Versao padrao configurada: PHP ${PHP_DEFAULT_VERSION}"
    else
        log_warning "Arquivo httpd_config.conf nao encontrado"
    fi
}

################################################################################
# Main
################################################################################

main() {
    log_info "Iniciando instalacao do OpenLiteSpeed..."
    
    local admin_password=$(cat "$DB_USER_PASSWORD_FILE" 2>/dev/null)
    
    if [ -z "$admin_password" ]; then
        log_error "Senha nao encontrada em $DB_USER_PASSWORD_FILE"
        return 1
    fi
    
    install_openlitespeed "$admin_password"
    change_ols_password "$admin_password"
    install_all_lsphp_versions
    set_default_php_version
    
    log_success "OpenLiteSpeed instalado e configurado"
}

main "$@"
