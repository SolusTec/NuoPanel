#!/bin/bash
################################################################################
# Script 07 - SSL e Configuracoes OLS
################################################################################

source /root/nuopanel-install/common-functions.sh
source /root/nuopanel-install/config.env

main() {
    log_info "Configurando SSL e OpenLiteSpeed..."
    
    install_acme_sh
    configure_ols_ssl
    copy_vhconf_files
    setup_cp_service
    
    log_success "SSL configurado"
}

install_acme_sh() {
    log_info "Instalando acme.sh..."
    wget -q -O - https://get.acme.sh | sh
    /root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
    /root/.acme.sh/acme.sh --upgrade --auto-upgrade
    log_success "acme.sh instalado"
}

configure_ols_ssl() {
    log_info "Configurando SSL OpenLiteSpeed..."
    
    local SERVER_IP=$(curl -4 -m 10 -s ifconfig.me)
    local SSL_DIR="/etc/letsencrypt/live/chandpurtelecom.xyz"
    
    mkdir -p "$SSL_DIR"
    
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$SSL_DIR/privkey.pem" \
        -out "$SSL_DIR/fullchain.pem" \
        -subj "/CN=$SERVER_IP"
    
    # Baixar httpd_config.conf
    if [ -f "$ITEM_DIR/move/conf/httpd_config.conf" ]; then
        cp "$ITEM_DIR/move/conf/httpd_config.conf" /usr/local/lsws/conf/httpd_config.conf
    else
        log_warning "Arquivo httpd_config.conf nao encontrado"
        wget -q -O /usr/local/lsws/conf/httpd_config.conf "$HTTPD_CONFIG_URL" || true
    fi
    
    sudo systemctl restart "$SYSTEMD_SERVICE" 2>/dev/null || true
    
    log_success "SSL configurado"
}

copy_vhconf_files() {
    log_info "Copiando vhconf files..."
    
    mkdir -p /usr/local/lsws/conf/vhosts/Example
    mkdir -p /usr/local/lsws/conf/vhosts/mypanel
    
    if [ -f "$ITEM_DIR/move/conf/Example/vhconf.conf" ]; then
        cp "$ITEM_DIR/move/conf/Example/vhconf.conf" /usr/local/lsws/conf/vhosts/Example/vhconf.conf
    else
        log_warning "vhconf Example nao encontrado"
        wget -q -O /usr/local/lsws/conf/vhosts/Example/vhconf.conf "$VHCONF_EXAMPLE_URL" || true
    fi
    
    if [ -f "$ITEM_DIR/move/conf/mypanel/vhconf.conf" ]; then
        cp "$ITEM_DIR/move/conf/mypanel/vhconf.conf" /usr/local/lsws/conf/vhosts/mypanel/vhconf.conf
    else
        log_warning "vhconf mypanel nao encontrado"
        wget -q -O /usr/local/lsws/conf/vhosts/mypanel/vhconf.conf "$VHCONF_MYPANEL_URL" || true
    fi
    
    log_success "vhconf copiados"
}

setup_cp_service() {
    log_info "Configurando servico Django..."
    
    local new_port=$(shuf -i 1000-9999 -n 1)
    echo "$new_port" > "$ITEM_DIR/port.txt"
    
    # Baixar cp.service
    if [ -f "$ITEM_DIR/move/conf/cp.service" ]; then
        cp "$ITEM_DIR/move/conf/cp.service" /etc/systemd/system/cp.service
    else
        wget -q -O /etc/systemd/system/cp.service "$CP_SERVICE_URL"
    fi
    
    # Atualizar porta no httpd_config.conf
    if [ -f "$ITEM_DIR/move/conf/httpd_config.conf" ]; then
        sed -i "s/2083/$new_port/g" "$ITEM_DIR/move/conf/httpd_config.conf"
    fi
    
    # Substituir python3 por venv python
    sed -i "s|/usr/bin/python3|$VENV_PATH/bin/python|g" /etc/systemd/system/cp.service
    
    sudo systemctl daemon-reload
    sudo systemctl enable cp
    sudo systemctl start cp
    
    # Liberar porta no firewall
    sudo ufw allow ${new_port}/tcp
    
    log_success "Servico Django configurado na porta $new_port"
}

main
