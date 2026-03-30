#!/bin/bash
################################################################################
# NuoPanel - Instalador Principal
# Versao: 2.0.0
# Repositorio: https://github.com/SolusTec/NuoPanel
################################################################################

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Verificar root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Este script precisa ser executado como root${NC}"
    exit 1
fi

# Configuracoes
WORK_DIR="/root/nuopanel-install"
LOG_FILE="/var/log/nuopanel/install.log"

# Criar diretorios
mkdir -p "$WORK_DIR"
mkdir -p "$(dirname "$LOG_FILE")"

echo "================================================================================"
echo "               NUOPANEL INSTALLATION v2.0.0"
echo "================================================================================"
echo "Inicio: $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$LOG_FILE"
echo ""

cd "$WORK_DIR"

# Baixar arquivos base
echo -e "${GREEN}Baixando arquivos de configuracao...${NC}"
wget -q -O config.env https://raw.githubusercontent.com/SolusTec/NuoPanel/main/config.env || { echo -e "${RED}Erro ao baixar config.env${NC}"; exit 1; }
wget -q -O common-functions.sh https://raw.githubusercontent.com/SolusTec/NuoPanel/main/common-functions.sh || { echo -e "${RED}Erro ao baixar common-functions.sh${NC}"; exit 1; }

source config.env
source common-functions.sh

# Scripts na ORDEM CORRETA (MariaDB ANTES de OpenLiteSpeed)
declare -a SCRIPTS=(
    "01-system-setup.sh"
    "02-mariadb.sh"
    "03-openlitespeed.sh"
    "04-python-venv.sh"
    "05-extract-panel.sh"
    "06-mail-ftp-dns.sh"
    "07-ssl-config.sh"
    "08-softaculous.sh"
    "09-finalize.sh"
)

# Baixar scripts
log_info "Baixando scripts modulares..."
for script in "${SCRIPTS[@]}"; do
    wget -q -O "${script}" "${REPO_BASE}/scripts/${script}" || { log_error "Falha: ${script}"; exit 1; }
    chmod +x "${script}"
done
log_success "Scripts baixados"

# Executar instalacao
echo ""
log_info "Iniciando instalacao..."
echo ""

for script in "${SCRIPTS[@]}"; do
    echo "================================================================================"
    log_info ">>> Executando: ${script}"
    echo "================================================================================"
    
    bash "${script}"
    
    if [ $? -ne 0 ]; then
        log_error "FALHA em ${script}"
        exit 1
    fi
    
    echo ""
done

echo "================================================================================"
log_success "INSTALACAO CONCLUIDA COM SUCESSO!"
echo "================================================================================"
echo "Fim: $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$LOG_FILE"
