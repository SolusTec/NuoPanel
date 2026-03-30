#!/bin/bash
# NuoPanel - 08 Softaculous Installation
source /root/nuopanel-install/common-functions.sh 2>/dev/null
source /root/nuopanel-install/config.env 2>/dev/null

main() {
    log_info "Instalando Softaculous..."
    
    # Executar script externo de instalacao
    curl -sSL "$OLSPANEL_SWAP" | sed 's/\r$//' | bash
    curl -sSL "$OLSPANEL_DB_UPDATE" | sed 's/\r$//' | bash
    
    log_success "Softaculous configurado"
}

main "$@"
