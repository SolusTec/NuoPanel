#!/bin/bash
################################################################################
# Script 02 - MariaDB (GERA SENHA PRIMEIRO)
################################################################################

source /root/nuopanel-install/common-functions.sh
source /root/nuopanel-install/config.env

main() {
    log_info "Iniciando instalacao do MariaDB..."
    
    generate_and_save_password
    install_mariadb
    secure_mariadb
    create_database_and_user
    
    log_success "MariaDB configurado com sucesso"
}

generate_and_save_password() {
    log_info "Gerando senhas..."
    
    # Gerar senha root MySQL
    PASSWORD=$(generate_mariadb_password)
    echo -n "$PASSWORD" > "$DB_ROOT_PASSWORD_FILE"
    chmod 600 "$DB_ROOT_PASSWORD_FILE"
    
    # Gerar senha usuario panel
    DB_PASSWORD=$(generate_mariadb_password)
    echo -n "$DB_PASSWORD" > "$DB_USER_PASSWORD_FILE"
    chmod 600 "$DB_USER_PASSWORD_FILE"
    
    log_success "Senhas geradas e salvas"
}

install_mariadb() {
    log_info "Instalando MariaDB..."
    wait_for_apt_lock
    sudo apt install -y mariadb-server mariadb-client
    
    if [ $? -ne 0 ]; then
        log_error "Falha ao instalar MariaDB"
        return 1
    fi
    
    log_success "MariaDB instalado"
}

secure_mariadb() {
    local ROOT_PASSWORD=$(get_password_from_file "$DB_ROOT_PASSWORD_FILE")
    
    log_info "Configurando senha root do MariaDB..."
    sudo mysql_secure_installation <<EOF

Y
$ROOT_PASSWORD
$ROOT_PASSWORD
Y
Y
Y
Y
EOF
    
    # Alterar senha root
    mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$ROOT_PASSWORD'; FLUSH PRIVILEGES;" 2>/dev/null || true
    
    log_success "MariaDB protegido"
}

create_database_and_user() {
    local ROOT_PASSWORD=$(get_password_from_file "$DB_ROOT_PASSWORD_FILE")
    local USER_PASSWORD=$(get_password_from_file "$DB_USER_PASSWORD_FILE")
    
    log_info "Criando banco de dados '$DB_NAME' e usuario '$DB_USER'..."
    
    mysql -u root -p"${ROOT_PASSWORD}" <<EOF
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${USER_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF
    
    if [ $? -eq 0 ]; then
        log_success "Banco '$DB_NAME' e usuario '$DB_USER' criados"
    else
        log_error "Falha ao criar banco ou usuario"
        return 1
    fi
}

main
