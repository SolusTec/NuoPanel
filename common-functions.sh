#!/bin/bash
################################################################################
# NuoPanel - Funcoes Compartilhadas
################################################################################

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Config
LOG_LEVEL="${LOG_LEVEL:-INFO}"
LOG_FILE="${LOG_FILE:-/var/log/nuopanel/install.log}"
VERBOSE="${VERBOSE:-0}"

# Funcao principal de log
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Sempre salva no arquivo
    if [ -n "$LOG_FILE" ]; then
        echo "[${timestamp}] [${level}] ${message}" >> "$LOG_FILE"
    fi
    
    # Exibe na tela
    case "$level" in
        DEBUG)
            [ "$LOG_LEVEL" = "DEBUG" ] && [ "$VERBOSE" -eq 1 ] && echo -e "${BLUE}[DEBUG]${NC} ${message}"
            ;;
        INFO)
            echo -e "${GREEN}${message}${NC}"
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

# Aguardar apt lock
wait_for_apt_lock() {
    while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
        log_info "Aguardando apt lock..."
        sleep 5
    done
}

# Gerar senha MySQL
generate_mariadb_password() {
    tr -dc A-Za-z0-9 </dev/urandom | head -c 16
}

# Ler senha de arquivo
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
