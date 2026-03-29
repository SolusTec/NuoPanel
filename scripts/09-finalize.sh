#!/bin/bash
# NuoPanel - 09 Finalization
source /root/nuopanel-install/common-functions.sh 2>/dev/null
source /root/nuopanel-install/config.env 2>/dev/null

main() {
    log_info "Finalizando instalacao..."
    
    # Limpeza
    sudo rm -rf /root/item
    sudo rm -f /root/item/mysqlPassword
    sudo rm -f /root/webadmin
    
    # Mensagem final
    IP=$(hostname -I | awk '{print $1}')
    PORT=$(cat /root/item/port.txt 2>/dev/null || echo "8080")
    PASSWORD=$(cat /root/db_credentials_panel.txt 2>/dev/null)
    
    echo ""
    echo "=========================================="
    log_success "NuoPanel instalado com sucesso!"
    echo "=========================================="
    echo "URL Admin: https://${IP}:${PORT}"
    echo "Usuario: admin"
    echo "Senha: ${PASSWORD}"
    echo "=========================================="
}

main "$@"
