#!/bin/bash
################################################################################
# Script 06 - Mail, FTP e DNS
################################################################################

source /root/nuopanel-install/common-functions.sh
source /root/nuopanel-install/config.env

main() {
    log_info "Instalando Mail, FTP e DNS..."
    
    install_mail_server
    install_ftp_server
    install_dns_server
    create_vmail_user
    configure_services
    copy_mail_configs
    
    log_success "Mail/FTP/DNS instalados"
}

install_mail_server() {
    log_info "Instalando Postfix e Dovecot..."
    
    echo "postfix postfix/mailname string example.com" | sudo debconf-set-selections
    echo "postfix postfix/main_mailer_type string 'Internet Site'" | sudo debconf-set-selections
    
    wait_for_apt_lock
    sudo apt-get install -y postfix postfix-mysql dovecot-core dovecot-imapd dovecot-pop3d dovecot-lmtpd dovecot-mysql dovecot-sqlite opendkim opendkim-tools
    
    log_success "Mail server instalado"
}

install_ftp_server() {
    log_info "Instalando Pure-FTPd..."
    wait_for_apt_lock
    sudo apt install -y pure-ftpd-mysql
    
    # Gerar certificado SSL FTP
    local CERT_PATH="/etc/ssl/private/pure-ftpd.pem"
    sudo openssl req -newkey rsa:1024 -new -nodes -x509 -days 3650 -subj "/C=US/ST=State/L=City/O=Org/CN=www.example.com" -keyout "$CERT_PATH" -out "$CERT_PATH"
    sudo chmod 600 "$CERT_PATH"
    
    log_success "FTP instalado"
}

install_dns_server() {
    log_info "Instalando PowerDNS..."
    wait_for_apt_lock
    sudo apt install -y openssl pdns-server pdns-backend-mysql pdns-backend-bind
    
    sudo chmod 644 /etc/powerdns/pdns.conf 2>/dev/null || true
    sudo chown pdns:pdns /etc/powerdns/pdns.conf 2>/dev/null || true
    
    log_success "DNS instalado"
}

create_vmail_user() {
    log_info "Criando usuario vmail..."
    
    if ! grep -q "^vmail:" /etc/group; then
        sudo groupadd -g 5000 vmail
    fi
    
    if ! id -u vmail &>/dev/null; then
        sudo useradd -g vmail -u 5000 -d /var/mail -s /sbin/nologin vmail
    fi
    
    sudo mkdir -p /var/mail/vhosts /home/vmail
    sudo chown -R vmail:vmail /var/mail/vhosts /home/vmail
    sudo chmod -R 770 /var/mail
    sudo chmod -R 700 /home/vmail
    
    log_success "Usuario vmail criado"
}

configure_services() {
    log_info "Configurando servicos de mail..."
    
    # Dovecot cert
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/dovecot/key.pem -out /etc/dovecot/cert.pem -subj "/CN=localhost"
    chmod 600 /etc/dovecot/key.pem
    chmod 644 /etc/dovecot/cert.pem
    
    # Log Dovecot
    touch /home/vmail/dovecot-deliver.log
    chown -R vmail:vmail /home/vmail
    chmod 644 /home/vmail/dovecot-deliver.log
    
    log_success "Servicos configurados"
}

copy_mail_configs() {
    if [ ! -d "$ITEM_DIR/move/etc" ]; then
        log_error "Diretorio fonte $ITEM_DIR/move/etc nao existe"
        return 1
    fi
    
    log_info "Copiando configuracoes de mail..."
    
    local DB_PASSWORD=$(get_password_from_file "$DB_USER_PASSWORD_FILE")
    rsync -av --progress "$ITEM_DIR/move/etc/" /etc/
    find /etc -type f -exec sed -i "s/%password%/$DB_PASSWORD/g" {} \;
    
    # Permissoes Postfix
    sudo chown root:postfix /etc/postfix/mysql-virtual_*.cf 2>/dev/null || true
    sudo chmod 640 /etc/postfix/mysql-virtual_*.cf 2>/dev/null || true
    sudo chown root:postfix /etc/postfix/main.cf 2>/dev/null || true
    sudo chmod 644 /etc/postfix/main.cf 2>/dev/null || true
    
    sudo postmap /etc/postfix/script_filter 2>/dev/null || true
    sudo postmap /etc/postfix/vmail_ssl.map 2>/dev/null || true
    
    # OpenDKIM
    mkdir -p /etc/opendkim
    touch /etc/opendkim/key.table
    touch /etc/opendkim/signing.table
    touch /etc/opendkim/TrustedHosts.table
    
    # FTP Passive IP
    IP=$(hostname -I | awk '{print $1}')
    if [[ $IP == 10.* || $IP == 172.* || $IP == 192.168.* ]]; then
        IP=$(curl -4 -m 10 -s ifconfig.me)
    fi
    echo "$IP" | sudo tee /etc/pure-ftpd/conf/ForcePassiveIP > /dev/null
    
    log_success "Configuracoes copiadas"
}

main
