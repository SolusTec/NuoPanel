#!/bin/bash
################################################################################
# NuoPanel - 03 MariaDB Installation
# Descricao: Instalacao e configuracao do MariaDB
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
# Funcoes (extraidas do panel.sh original)
################################################################################

generate_mariadb_password() {
    DB_PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)
    echo "$DB_PASSWORD"
}

install_mariadb() {
    local MYSQL_ROOT_PASSWORD="$1"

    if [ -z "$MYSQL_ROOT_PASSWORD" ]; then
        log_error "Senha nao fornecida para usuario root"
        return 1
    fi

    log_info "Instalando MariaDB server e client..."
    sudo apt update && sudo apt install -y mariadb-server mariadb-client

    if [ $? -ne 0 ]; then
        log_error "Falha ao instalar MariaDB"
        return 1
    fi

    log_info "Configurando MariaDB (mysql_secure_installation)..."
    sudo mysql_secure_installation <<EOF

Y
$MYSQL_ROOT_PASSWORD
$MYSQL_ROOT_PASSWORD
Y
Y
Y
Y
EOF

    if [ $? -ne 0 ]; then
        log_error "Falha ao configurar MariaDB"
        return 1
    fi

    log_success "MariaDB instalado e configurado"
}

change_mysql_root_password() {
    local NEW_PASSWORD="$1"

    if [ -z "$NEW_PASSWORD" ]; then
        log_error "Senha nao fornecida"
        return 1
    fi

    OUTPUT=$(mysql -u root -e "
    ALTER USER 'root'@'localhost' IDENTIFIED BY '$NEW_PASSWORD';
    FLUSH PRIVILEGES;" 2>&1)

    if echo "$OUTPUT" | grep -qE "ERROR|Access denied|authentication failure|wrong password"; then
        log_error "Falha ao alterar senha root. Continuando..."
        return 1
    fi

    log_success "Senha root do MariaDB alterada"
    return 0
}

create_database_and_user() {
    local ROOT_PASSWORD="$1"
    local DB_NAME="$2"
    local DB_USER="$3"

    if [ -z "$ROOT_PASSWORD" ] || [ -z "$DB_NAME" ] || [ -z "$DB_USER" ]; then
        log_error "Parametros faltando para criar banco/usuario"
        return 1
    fi

    local DB_PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)
    echo -n "${DB_PASSWORD}" > "$DB_USER_PASSWORD_FILE"
    chmod 600 "$DB_USER_PASSWORD_FILE"

    log_info "Criando banco '$DB_NAME' e usuario '$DB_USER'..."

    mysql -u root -p"${ROOT_PASSWORD}" <<EOF
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

    if [ $? -eq 0 ]; then
        log_success "Banco '$DB_NAME' e usuario '$DB_USER' criados"
        log_debug "Senha salva em: $DB_USER_PASSWORD_FILE"
    else
        log_error "Falha ao criar banco ou usuario"
        return 1
    fi
}

get_password_from_file() {
    local password_file="$1"

    if [ ! -f "$password_file" ]; then
        log_error "Arquivo $password_file nao existe"
        return 1
    fi

    local password=$(cat "$password_file")

    if [ -z "$password" ]; then
        log_error "Arquivo $password_file esta vazio"
        return 1
    fi

    echo "$password"
}

import_database() {
    local ROOT_PASSWORD="$1"
    local DB_NAME="$2"
    local DUMP_FILE="$3"

    if [ -z "$ROOT_PASSWORD" ] || [ -z "$DB_NAME" ] || [ -z "$DUMP_FILE" ]; then
        log_error "Parametros faltando para importar banco"
        return 1
    fi

    if [ ! -f "$DUMP_FILE" ]; then
        log_error "Arquivo de dump '$DUMP_FILE' nao existe"
        return 1
    fi

    log_info "Importando banco de '$DUMP_FILE' para '$DB_NAME'..."

    mysql -u root -p"${ROOT_PASSWORD}" --force "$DB_NAME" < "$DUMP_FILE"

    if [ $? -eq 0 ]; then
        log_success "Banco importado para '$DB_NAME'"
    else
        log_error "Falha ao importar banco"
        return 1
    fi
}

################################################################################
# Main
################################################################################

main() {
    log_info "Iniciando configuracao do MariaDB..."
    
    # Gerar senha root
    local root_password=$(generate_mariadb_password)
    echo -n "$root_password" > "$DB_ROOT_PASSWORD_FILE"
    chmod 600 "$DB_ROOT_PASSWORD_FILE"
    log_debug "Senha root salva em: $DB_ROOT_PASSWORD_FILE"
    
    # Instalar MariaDB
    install_mariadb "$root_password"
    
    # Alterar senha root
    change_mysql_root_password "$root_password"
    
    # Criar banco e usuario do painel
    create_database_and_user "$root_password" "$DB_NAME" "$DB_USER"
    
    # Importar dump SQL (se existir)
    local dump_file="${ITEM_DIR}/panel_db.sql"
    if [ -f "$dump_file" ]; then
        import_database "$root_password" "$DB_NAME" "$dump_file"
    else
        log_warning "Arquivo panel_db.sql nao encontrado em $dump_file"
    fi
    
    log_success "MariaDB configurado"
}

main "$@"
