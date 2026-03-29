#!/bin/bash
################################################################################
# NuoPanel - 06 Mail, FTP and DNS
# Descricao: Instalacao e configuracao de Mail, FTP e DNS
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

install_mail_and_ftp_server() {
    log_info "Configurando Postfix..."
    echo "postfix postfix/mailname string example.com" | sudo debconf-set-selections
    echo "postfix postfix/main_mailer_type string 'Internet Site'" | sudo debconf-set-selections
    
    log_info "Instalando Postfix, Dovecot e Pure-FTPd..."
    sudo apt-get install -y postfix postfix-mysql dovecot-core dovecot-imapd dovecot-pop3d dovecot-lmtpd dovecot-mysql
    sudo apt-get install -y dovecot-sqlite dovecot-mysql
    sudo apt install -y pure-ftpd-mysql
    sudo apt install -y opendkim opendkim-tools
    
    log_success "Mail e FTP instalados"
}

install_powerdns_and_mysql_backend() {
    log_info "Instalando PowerDNS..."
    sudo apt install -y openssl pdns-server pdns-backend-mysql
    
    log_info "Configurando permissoes do PowerDNS..."
    sudo chmod 644 /etc/powerdns/pdns.conf
    sudo chown pdns:pdns /etc/powerdns/pdns.conf
    
    log_success "PowerDNS instalado"
}

copy_files_and_replace_password() {
    local source_dir="$1"
    local target_dir="$2"
    local new_password="$3"
    
    if [ -z "$source_dir" ] || [ -z "$target_dir" ] || [ -z "$new_password" ]; then
        log_error "Parametros faltando para copy_files_and_replace_password"
        return 1
    fi
    
    if [ ! -d "$source_dir" ]; then
        log_error "Diretorio fonte $source_dir nao existe"
        return 1
    fi
    
    if [ ! -d "$target_dir" ]; then
        mkdir -p "$target_dir"
    fi
    
    log_info "Copiando arquivos de $source_dir para $target_dir..."
    rsync -av --progress "$source_dir/" "$target_dir/" >/dev/null 2>&1
    
    log_info "Substituindo senhas nos arquivos..."
    find "$target_dir" -type f -exec sed -i "s/%password%/$new_password/g" {} \;
    
    # Configurar vmail
    sudo groupadd -g 5000 vmail 2>/dev/null || true
    sudo useradd -g vmail -u 5000 vmail -d /var/mail 2>/dev/null || true
    sudo mkdir -p /var/mail/vhosts
    sudo chown -R vmail:vmail /var/mail/vhosts
    
    # Permissoes Postfix
    sudo chown root:postfix /etc/postfix/mysql-virtual_domains.cf
    sudo chmod 640 /etc/postfix/mysql-virtual_domains.cf
    sudo chown root:postfix /etc/postfix/mysql-virtual_forwardings.cf
    sudo chmod 640 /etc/postfix/mysql-virtual_forwardings.cf
    sudo chown root:postfix /etc/postfix/mysql-virtual_mailboxes.cf
    sudo chmod 640 /etc/postfix/mysql-virtual_mailboxes.cf
    sudo chown root:postfix /etc/postfix/mysql-virtual_email2email.cf
    sudo chmod 640 /etc/postfix/mysql-virtual_email2email.cf
    sudo chown root:postfix /etc/postfix/mysql_transport.cf
    sudo chmod 640 /etc/postfix/mysql_transport.cf
    sudo chown root:postfix /etc/postfix/main.cf
    sudo chmod 644 /etc/postfix/main.cf
    sudo chown root:postfix /etc/postfix/master.cf
    sudo chmod 644 /etc/postfix/master.cf
    sudo chown root:postfix /etc/postfix/vmail_ssl.map
    sudo chmod 644 /etc/postfix/vmail_ssl.map
    
    sudo mkdir -p /home/vmail
    sudo chown -R vmail:vmail /home/vmail
    sudo chmod -R 700 /home/vmail
    
    log_success "Arquivos copiados e configurados"
}

generate_pureftpd_ssl_certificate() {
    local cert_path="/etc/ssl/private/pure-ftpd.pem"
    local subject="/C=US/ST=Denial/L=Springfield/O=Dis/CN=www.example.com"
    local days=3650
    
    log_info "Gerando certificado SSL para Pure-FTPd..."
    
    if [ ! -d "$(dirname "$cert_path")" ]; then
        sudo mkdir -p "$(dirname "$cert_path")"
    fi
    
    sudo openssl req -newkey rsa:1024 -new -nodes -x509 -days "$days" -subj "$subject" -keyout "$cert_path" -out "$cert_path"
    sudo chmod 600 "$cert_path"
    
    log_success "Certificado Pure-FTPd gerado"
}

create_dovecot_cert() {
    local cert_path="/etc/dovecot/cert.pem"
    local key_path="/etc/dovecot/key.pem"
    
    log_info "Criando certificado SSL para Dovecot..."
    
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$key_path" -out "$cert_path" -subj "/CN=localhost"
    
    chmod 600 "$key_path"
    chmod 644 "$cert_path"
    chown root:root "$cert_path" "$key_path"
    
    log_success "Certificado Dovecot criado"
}

create_vmail_user() {
    log_info "Criando usuario vmail..."
    
    if ! grep -q "^vmail:" /etc/group; then
        sudo groupadd -g 5000 vmail
    fi
    
    if ! id -u vmail &>/dev/null; then
        sudo useradd -g vmail -u 5000 -d /var/mail -s /sbin/nologin vmail
    fi
    
    sudo mkdir -p /var/mail/vhosts
    sudo chown -R vmail:vmail /var/mail/vhosts
    sudo chmod -R 770 /var/mail
    
    log_success "Usuario vmail criado"
}

fix_dovecot_log_permissions() {
    local log_file="/home/vmail/dovecot-deliver.log"
    local log_dir="/home/vmail"
    local user="vmail"
    
    if [ ! -f "$log_file" ]; then
        touch "$log_file"
    fi
    
    chown -R $user:$user "$log_dir"
    chmod 644 "$log_file"
    chmod -R 700 "$log_dir"
    
    systemctl restart dovecot
    
    log_success "Permissoes Dovecot configuradas"
}

################################################################################
# Main
################################################################################

main() {
    log_info "Iniciando instalacao Mail, FTP e DNS..."
    
    local admin_password=$(cat "$DB_USER_PASSWORD_FILE" 2>/dev/null)
    
    install_mail_and_ftp_server
    install_powerdns_and_mysql_backend
    copy_files_and_replace_password "$ITEM_DIR/move/etc" "/etc" "$admin_password"
    generate_pureftpd_ssl_certificate
    copy_files_and_replace_password "$ITEM_DIR/move/html" "/usr/local/lsws/Example/html" "$admin_password"
    create_dovecot_cert
    create_vmail_user
    fix_dovecot_log_permissions
    
    log_success "Mail, FTP e DNS configurados"
}

main "$@"
