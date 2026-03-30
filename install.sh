#!/bin/bash
################################################################################
# NuoPanel - Instalador Principal
# Versao: 2.0.0
# Repositorio: https://github.com/SolusTec/NuoPanel
################################################################################

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

# Lista completa dos scripts (NOMES EXATOS)
declare -a SCRIPTS=(
    "01-system-setup.sh"
    "02-openlitespeed.sh"
    "03-mariadb.sh"
    "04-python-venv.sh"
    "05-extract-panel.sh"
    "06-mail-ftp-dns.sh"
    "07-ssl-config.sh"
    "08-softaculous.sh"
    "09-finalize.sh"
)

# Baixar cada script
for script in "${SCRIPTS[@]}"; do
    log_info "Baixando ${script}..."
    wget -q -O "${script}" "${REPO_BASE}/scripts/${script}"
    
    if [ $? -ne 0 ]; then
        log_error "Falha ao baixar ${script}"
        exit 1
    fi
    
    chmod +x "${script}"
done

log_success "Scripts baixados com sucesso"

# Executar instalacao
log_info "Iniciando instalacao NuoPanel v${NUOPANEL_VERSION}..."
echo ""

for script in "${SCRIPTS[@]}"; do
    log_info "Executando ${script}..."
    bash "${script}"
    
    if [ $? -ne 0 ]; then
        log_error "Falha ao executar ${script}"
        exit 1
    fi
done

log_success "Instalacao concluida!"
