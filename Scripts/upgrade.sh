#!/bin/bash

# ============================================================
# NuoPanel Upgrade Script
# Atualiza instalações existentes do NuoPanel
# ============================================================

# Detectar diretório do projeto
HOME_PATH_FILE="/etc/nuopanel/base_dir"
if [ -f "$HOME_PATH_FILE" ]; then
    PROJECT_DIR="$(cat "$HOME_PATH_FILE")"
else
    PROJECT_DIR="/usr/local/lsws/Example/html/nuopanel"
fi

# Detectar sistema operacional
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_NAME=$ID
    OS_VERSION=${VERSION_ID%%.*}
elif [ -f /etc/centos-release ]; then
    OS_NAME="centos"
    OS_VERSION=$(awk '{print $4}' /etc/centos-release | cut -d. -f1)
fi

# Determinar gerenciador de pacotes
if [[ "$OS_NAME" == "ubuntu" || "$OS_NAME" == "debian" ]]; then
    PACKAGE_MANAGER="apt"
elif [[ "$OS_NAME" =~ ^(centos|almalinux|rhel|fedora|rocky|oraclelinux)$ ]]; then
    if command -v dnf &>/dev/null; then
        PACKAGE_MANAGER="dnf"
    else
        PACKAGE_MANAGER="yum"
    fi
else
    echo "Sistema operacional não suportado"
    exit 1
fi

# Agendar execução com delay (evita problemas com curl | bash)
if [[ "$0" == /* ]]; then
    sudo ${PACKAGE_MANAGER} install at -y
    sudo systemctl start atd
    sudo systemctl enable --now atd
    echo "curl -sSL https://raw.githubusercontent.com/SolusTec/NuoPanel/main/Scripts/upgrade.sh | sed 's/\r\$//' | bash" | at now + 1 minute
    exit 0
fi

echo "============================================================"
echo "   NuoPanel - Iniciando atualização"
echo "============================================================"

# Salvar informações do sistema
echo -n "$OS_NAME" > $PROJECT_DIR/etc/osName
echo -n "$OS_VERSION" > $PROJECT_DIR/etc/osVersion

# ============================================================
# FUNÇÕES AUXILIARES
# ============================================================

remove_extra_cron_lines() {
    crontab -l 2>/dev/null | grep -v '^[[:space:]]*$' | sort | uniq | crontab -
    echo "✓ Linhas extras do cron removidas"
}

add_cronjobs() {
    local CRON_JOBS=(
        "* * * * * /usr/local/bin/nuopanel --fail2ban >/dev/null 2>&1"
    )

    local CURRENT_CRON
    CURRENT_CRON=$(crontab -l 2>/dev/null || true)

    for JOB in "${CRON_JOBS[@]}"; do
        if ! grep -Fq "$JOB" <<< "$CURRENT_CRON"; then
            CURRENT_CRON+=$'\n'"$JOB"
        fi
    done

    printf "%s\n" "$CURRENT_CRON" | crontab -
    remove_extra_cron_lines
    echo "✓ Cron jobs atualizados"
}

update_php_versions() {
    echo "Atualizando versões PHP..."
    
    for version in 74 80 81 82 83 84 85; do
        if [ -x "/usr/local/lsws/lsphp$version/bin/php" ]; then
            php_version=$(echo "$version" | awk '{print substr($0,1,1) "." substr($0,2,1)}')
            
            ini_file_path="/usr/local/lsws/lsphp$version/etc/php/$php_version/litespeed/php.ini"
            ini_file_path_old="/usr/local/lsws/lsphp$version/etc/php.ini"
            
            if [ -f "$ini_file_path" ]; then
                target_ini="$ini_file_path"
            elif [ -f "$ini_file_path_old" ]; then
                target_ini="$ini_file_path_old"
            else
                continue
            fi
            
            sudo sed -i 's/^disable_functions\s*=.*/disable_functions = pcntl_alarm,pcntl_fork,pcntl_waitpid,pcntl_wait,pcntl_wifexited,pcntl_wifstopped,pcntl_wifsignaled,pcntl_wifcontinued,pcntl_wexitstatus,pcntl_wtermsig,pcntl_wstopsig,pcntl_signal,pcntl_signal_get_handler,pcntl_signal_dispatch,pcntl_get_last_error,pcntl_strerror,pcntl_sigprocmask,pcntl_sigwaitinfo,pcntl_sigtimedwait,pcntl_exec,pcntl_getpriority,pcntl_setpriority,pcntl_async_signals,pcntl_unshare/' "$target_ini"
        fi
    done
    
    pkill lsphp 2>/dev/null || true
    echo "✓ Versões PHP atualizadas"
}

# ============================================================
# ATUALIZAÇÃO PRINCIPAL
# ============================================================

echo ""
echo "▶ Baixando atualização do NuoPanel..."

# Baixar panel_setup.zip atualizado
wget -q --show-progress -O ${PROJECT_DIR%/*}/panel_setup.zip \
    "https://raw.githubusercontent.com/SolusTec/NuoPanel/main/Assets/panel_setup.zip?$(date +%s)"

if [ $? -ne 0 ]; then
    echo "✗ Erro ao baixar panel_setup.zip"
    exit 1
fi

echo "✓ Download concluído"

# Descompactar e sobrescrever arquivos
echo ""
echo "▶ Instalando arquivos atualizados..."
sudo unzip -oq ${PROJECT_DIR%/*}/panel_setup.zip -d ${PROJECT_DIR%/*}

if [ $? -ne 0 ]; then
    echo "✗ Erro ao descompactar arquivos"
    exit 1
fi

echo "✓ Arquivos instalados"

# Aplicar migrations Django
echo ""
echo "▶ Aplicando atualizações do banco de dados..."

cd $PROJECT_DIR
source /root/.venv/bin/activate

# Aplicar migrations automaticamente
python manage.py migrate --noinput

if [ $? -ne 0 ]; then
    echo "✗ Erro ao aplicar migrations do Django"
    deactivate
    exit 1
fi

deactivate
echo "✓ Banco de dados atualizado"

# ============================================================
# SCRIPTS AUXILIARES
# ============================================================

echo ""
echo "▶ Executando scripts auxiliares..."

# Swap, firewall e utilitários
curl -sSL "https://raw.githubusercontent.com/SolusTec/NuoPanel/main/Scripts/swap.sh?$(date +%s)" | sed 's/\r$//' | bash

# Configuração SSL
curl -sSL "https://raw.githubusercontent.com/SolusTec/NuoPanel/main/Scripts/ssl.sh?$(date +%s)" | sed 's/\r$//' | bash

# Adicionar cron jobs
add_cronjobs

# Atualizar PHP (opcional, descomente se necessário)
# update_php_versions

echo "✓ Scripts auxiliares executados"

# ============================================================
# FINALIZAÇÃO
# ============================================================

echo ""
echo "▶ Reiniciando serviços..."

sudo systemctl restart cp 2>/dev/null || true
sudo /usr/local/lsws/bin/lswsctrl restart 2>/dev/null || true

echo "✓ Serviços reiniciados"

# Obter versão atualizada
if [ -f "$PROJECT_DIR/etc/version" ]; then
    CURRENT_VERSION=$(cat "$PROJECT_DIR/etc/version")
else
    CURRENT_VERSION="desconhecida"
fi

echo ""
echo "============================================================"
echo "   ✓ Atualização concluída com sucesso!"
echo "   Versão atual: $CURRENT_VERSION"
echo "============================================================"
echo ""
