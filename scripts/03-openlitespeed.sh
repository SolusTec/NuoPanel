#!/bin/bash
################################################################################
# Script 03 - OpenLiteSpeed (USA SENHA JA GERADA)
################################################################################

source /root/nuopanel-install/common-functions.sh
source /root/nuopanel-install/config.env

main() {
    log_info "Iniciando instalacao do OpenLiteSpeed..."
    
    # Verificar se senha existe
    if [ ! -f "$DB_USER_PASSWORD_FILE" ]; then
        log_error "Senha nao encontrada em $DB_USER_PASSWORD_FILE"
        return 1
    fi
    
    install_openlitespeed
    change_ols_password
    install_all_lsphp_versions
    
    log_success "OpenLiteSpeed instalado"
}

install_openlitespeed() {
    log_info "Instalando OpenLiteSpeed..."
    wget -O openlitespeed.sh https://repo.litespeed.sh
    
    if [ $? -ne 0 ]; then
        log_error "Falha na instalacao do OpenLiteSpeed"
        return 1
    fi
    
    sudo bash openlitespeed.sh
    sudo apt install openlitespeed -y
    
    if command -v lswsctrl &> /dev/null; then
        sudo /usr/local/lsws/bin/lswsctrl start
        sudo systemctl enable "$SYSTEMD_SERVICE"
        log_success "OpenLiteSpeed instalado e iniciado"
    else
        log_error "Falha na instalacao do OpenLiteSpeed"
        return 1
    fi
}

change_ols_password() {
    local Webadmin_Pass=$(get_password_from_file "$DB_USER_PASSWORD_FILE")
    
    log_info "Configurando senha WebAdmin..."
    Encrypt_string=$(/usr/local/lsws/admin/fcgi-bin/admin_php /usr/local/lsws/admin/misc/htpasswd.php "${Webadmin_Pass}")
    
    echo "admin:$Encrypt_string" > /usr/local/lsws/admin/conf/htpasswd
    chown lsadm:lsadm /usr/local/lsws/admin/conf/htpasswd
    chmod 600 /usr/local/lsws/admin/conf/htpasswd
    
    echo "${Webadmin_Pass}" > /root/webadmin
    chmod 600 /root/webadmin
    
    log_success "Senha WebAdmin configurada"
}

install_all_lsphp_versions() {
    log_info "Instalando PHP 7.4 a 8.5..."
    
    sudo apt-get install -y software-properties-common
    sudo add-apt-repository -y ppa:openlitespeed/php
    wait_for_apt_lock
    sudo apt update
    
    for version in $PHP_VERSIONS; do
        log_info "Instalando PHP $version..."
        sudo apt-get install -y lsphp"$version" lsphp"$version"-common lsphp"$version"-mysql lsphp"$version"-curl lsphp"$version"-json 2>&1 | grep -v "Unable to locate"
        
        if [ $? -ne 0 ]; then
            log_warning "Falha ao instalar PHP $version"
            continue
        fi
        
        if [ -x "/usr/local/lsws/lsphp$version/bin/php" ]; then
            php_version=$(echo "$version" | awk '{print substr($0,1,1) "." substr($0,2,1)}')
            
            ini_file_path="/usr/local/lsws/lsphp$version/etc/php/$php_version/litespeed/php.ini"
            ini_file_path_old="/usr/local/lsws/lsphp$version/etc/php.ini"
            
            if [ -f "$ini_file_path" ]; then
                target_ini="$ini_file_path"
            elif [ -f "$ini_file_path_old" ]; then
                target_ini="$ini_file_path_old"
            else
                continue
            fi
            
            sudo sed -i 's/^disable_functions\s*=.*/disable_functions = pcntl_alarm,pcntl_fork,pcntl_waitpid,pcntl_wait,pcntl_wifexited,pcntl_wifstopped,pcntl_wifsignaled,pcntl_wifcontinued,pcntl_wexitstatus,pcntl_wtermsig,pcntl_wstopsig,pcntl_signal,pcntl_signal_get_handler,pcntl_signal_dispatch,pcntl_get_last_error,pcntl_strerror,pcntl_sigprocmask,pcntl_sigwaitinfo,pcntl_sigtimedwait,pcntl_exec,pcntl_getpriority,pcntl_setpriority,pcntl_async_signals,pcntl_unshare/' "$target_ini"
            sudo sed -i 's/^upload_max_filesize\s*=.*/upload_max_filesize = 80M/' "$target_ini"
            sudo sed -i 's/^post_max_size\s*=.*/post_max_size = 80M/' "$target_ini"
        fi
    done
    
    pkill lsphp 2>/dev/null || true
    log_success "PHP instalado"
}

main
