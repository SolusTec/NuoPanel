#!/bin/bash
################################################################################
# NuoPanel - Instalador Principal
# Versao: 2.0.0
# Repositorio: https://github.com/SolusTec/NuoPanel
################################################################################

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuracoes
LOG_FILE="${LOG_FILE:-/var/log/nuopanel/install.log}"
VERBOSE="${VERBOSE:-0}"
WORK_DIR="/root/nuopanel-install"

# Verificar root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Este script precisa ser executado como root${NC}"
    exit 1
fi

# Criar diretorios
mkdir -p "$WORK_DIR"
mkdir -p "$(dirname "$LOG_FILE")"

echo "================================================================================"
echo "NuoPanel Installation Started: $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"
echo "Version: 2.0.0" >> "$LOG_FILE"
echo "================================================================================"
echo ""

# Baixar arquivos principais
echo -e "${GREEN}Baixando arquivos de configuracao...${NC}"

cd "$WORK_DIR"

wget -q -O config.env https://raw.githubusercontent.com/SolusTec/NuoPanel/main/config.env
wget -q -O common-functions.sh https://raw.githubusercontent.com/SolusTec/NuoPanel/main/common-functions.sh

source config.env
source common-functions.sh

# Baixar scripts modulares
log_info "Baixando scripts modulares..."

for i in 01 02 03 04 05 06 07 08 09; do
    wget -q -O "${i}-script.sh" "${REPO_BASE}/scripts/${i}-*.sh"
    chmod +x "${i}-script.sh"
done

# Executar instalacao
log_info "Iniciando instalacao NuoPanel v${NUOPANEL_VERSION}..."

bash 01-script.sh
bash 02-script.sh  
bash 03-script.sh
bash 04-script.sh
bash 05-script.sh
bash 06-script.sh
bash 07-script.sh
bash 08-script.sh
bash 09-script.sh

log_success "Instalacao concluida!"

