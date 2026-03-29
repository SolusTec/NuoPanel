#!/bin/bash
# NuoPanel - 07 SSL Configuration
source /root/nuopanel-install/common-functions.sh 2>/dev/null
source /root/nuopanel-install/config.env 2>/dev/null

main() {
    log_info "Configurando SSL e certificados..."
    
    # Instalacao acme.sh
    wget -O - https://get.acme.sh | sh
    /root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
    /root/.acme.sh/acme.sh --upgrade --auto-upgrade
    
    log_success "SSL configurado"
}

main "$@"
