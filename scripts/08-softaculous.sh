#!/bin/bash
################################################################################
# Script 08 - Softaculous (olsapp)
################################################################################

source /root/nuopanel-install/common-functions.sh
source /root/nuopanel-install/config.env

main() {
    log_info "Instalando Softaculous..."
    
    # Este script é chamado pelo original via curl
    # Mantemos compatibilidade
    curl -sSL https://olspanel.com/olsapp/install.sh | sed 's/\r$//' | bash
    
    log_success "Softaculous instalado"
}

main
