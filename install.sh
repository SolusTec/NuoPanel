#!/bin/bash
################################################################################
# NuoPanel - Instalador Principal
# Versao: 2.0.0
# Descricao: Sistema modular de instalacao do NuoPanel
################################################################################

set -e  # Exit on error

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuracoes de logging
LOG_LEVEL="${LOG_LEVEL:-INFO}"
LOG_FILE="${LOG_FILE:-/var/log/nuopanel/install.log}"
VERBOSE="${VERBOSE:-0}"

################################################################################
# Funcoes de Logging
################################################################################

setup_logging() {
    local log_dir=$(dirname "$LOG_FILE")
    mkdir -p "$log_dir"
    
    echo "================================================================================" >> "$LOG_FILE"
    echo "NuoPanel Installation Started: $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"
    echo "Version: 2.0.0" >> "$LOG_FILE"
    echo "================================================================================" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
}

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[${timestamp}] [${level}] ${message}" >> "$LOG_FILE"
    
    case "$level" in
        DEBUG)
            [ "$LOG_LEVEL" = "DEBUG" ] && [ "$VERBOSE" -eq 1 ] && \
                echo -e "${BLUE}[DEBUG]${NC} ${message}"
            ;;
        INFO)
            [ "$VERBOSE" -eq 1 ] && \
                echo -e "${GREEN}[INFO]${NC} ${message}" || \
                echo "${message}"
            ;;
        WARNING)
            echo -e "${YELLOW}[WARNING]${NC} ${message}" >&2
            ;;
        ERROR)
            echo -e "${RED}[ERROR]${NC} ${message}" >&2
            ;;
        SUCCESS)
            echo -e "${GREEN}[OK]${NC} ${message}"
            ;;
    esac
}

log_debug() { log "DEBUG" "$@"; }
log_info() { log "INFO" "$@"; }
log_warning() { log "WARNING" "$@"; }
log_error() { log "ERROR" "$@"; }
log_success() { log "SUCCESS" "$@"; }

################################################################################
# Funcoes de Utilidade
################################################################################

download_file() {
    local url="$1"
    local dest="$2"
    local description="${3:-arquivo}"
    
    log_info "Baixando ${description}..."
    log_debug "URL: ${url}"
    log_debug "Destino: ${dest}"
    
    if wget --show-progress -O "$dest" "$url" 2>&1 | tee -a "$LOG_FILE"; then
        log_success "${description} baixado com sucesso"
        return 0
    else
        log_error "Falha ao baixar ${description}"
        return 1
    fi
}

run_script() {
    local script_url="$1"
    local description="$2"
    local temp_script="${WORK_DIR}/temp_script_$$.sh"
    
    log_info "Executando: ${description}"
    
    if download_file "$script_url" "$temp_script" "$description"; then
        chmod +x "$temp_script"
        if bash "$temp_script" 2>&1 | tee -a "$LOG_FILE"; then
            log_success "${description} concluido"
            rm -f "$temp_script"
            return 0
        else
            log_error "${description} falhou"
            rm -f "$temp_script"
            return 1
        fi
    else
        return 1
    fi
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Este script precisa ser executado como root"
        exit 1
    fi
}

check_os() {
    if [ ! -f /etc/os-release ]; then
        log_error "Sistema operacional nao suportado"
        exit 1
    fi
    
    . /etc/os-release
    
    if [ "$ID" != "ubuntu" ]; then
        log_error "Apenas Ubuntu e suportado. Detectado: $ID"
        exit 1
    fi
    
    log_info "Sistema detectado: Ubuntu ${VERSION_ID}"
}

################################################################################
# Carregamento de Configuracao
################################################################################

load_config() {
    local config_url="https://raw.githubusercontent.com/SolusTec/NuoPanel/main/config.env"
    local config_file="${WORK_DIR}/config.env"
    
    mkdir -p "$WORK_DIR"
    
    log_info "Carregando configuracoes..."
    
    if download_file "$config_url" "$config_file" "configuracoes"; then
        source "$config_file"
        log_success "Configuracoes carregadas"
    else
        log_error "Falha ao carregar configuracoes"
        exit 1
    fi
}

################################################################################
# Execucao de Scripts Modulares
################################################################################

execute_installation_steps() {
    local steps=(
        "$SCRIPT_SYSTEM_SETUP:Configuracao do Sistema"
        "$SCRIPT_OPENLITESPEED:Instalacao OpenLiteSpeed"
        "$SCRIPT_MARIADB:Instalacao MariaDB"
        "$SCRIPT_PYTHON_VENV:Configuracao Python Virtual Environment"
        "$SCRIPT_EXTRACT_PANEL:Extracao do Painel"
        "$SCRIPT_DATABASE_INIT:Inicializacao do Banco de Dados"
        "$SCRIPT_SSL_SETUP:Configuracao SSL"
        "$SCRIPT_SOFTACULOUS:Instalacao Softaculous"
        "$SCRIPT_FINALIZE:Finalizacao"
    )
    
    local total=${#steps[@]}
    local current=0
    
    for step in "${steps[@]}"; do
        current=$((current + 1))
        local script_url="${step%%:*}"
        local description="${step#*:}"
        
        echo ""
        log_info "========================================="
        log_info "Etapa ${current}/${total}: ${description}"
        log_info "========================================="
        
        if ! run_script "$script_url" "$description"; then
            log_error "Instalacao falhou na etapa: ${description}"
            log_error "Verifique o log em: ${LOG_FILE}"
            exit 1
        fi
    done
}

################################################################################
# Finalizacao
################################################################################

display_completion_message() {
    echo ""
    echo "================================================================================"
    log_success "Instalacao do NuoPanel concluida com sucesso!"
    echo "================================================================================"
    echo ""
    echo "  Acesse o painel em: https://seu-dominio.com:7080"
    echo "  Log de instalacao: ${LOG_FILE}"
    echo ""
    echo "  Para atualizar o painel no futuro, execute:"
    echo "    nuopanel-update"
    echo ""
    echo "================================================================================"
}

################################################################################
# Main
################################################################################

main() {
    setup_logging
    
    log_info "Iniciando instalacao do NuoPanel v2.0.0"
    
    check_root
    check_os
    load_config
    execute_installation_steps
    display_completion_message
    
    log_info "Instalacao finalizada em: $(date '+%Y-%m-%d %H:%M:%S')"
}

main "$@"
