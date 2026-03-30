#!/bin/bash
################################################################################
# NuoPanel - Install Plugins
# Descricao: Instala plugins webmail e ferramentas (roundcube, rainloop, phpmyadmin)
################################################################################

# Configuracoes
PANEL_DIR="/usr/local/lsws/Example/html/mypanel"
PLUGINS_DIR="${PANEL_DIR}/3rdparty"
REPO_BASE="https://raw.githubusercontent.com/SolusTec/NuoPanel/main"

# Funcao para baixar e extrair plugin
install_plugin() {
    local PLUGIN_NAME="$1"
    local PLUGIN_URL="${REPO_BASE}/assets/plugins/${PLUGIN_NAME}.zip"
    local PLUGIN_PATH="${PLUGINS_DIR}/${PLUGIN_NAME}"
    local ZIP_FILE="/tmp/${PLUGIN_NAME}.zip"
    
    echo "Verificando plugin: ${PLUGIN_NAME}..."
    
    # Verificar se ja esta instalado
    if [ -f "${PLUGIN_PATH}/index.php" ]; then
        echo "Plugin ${PLUGIN_NAME} ja instalado - pulando"
        return 0
    fi
    
    echo "Baixando ${PLUGIN_NAME}..."
    wget -q -O "$ZIP_FILE" "$PLUGIN_URL"
    
    if [ $? -ne 0 ]; then
        echo "ERRO: Falha ao baixar ${PLUGIN_NAME}"
        return 1
    fi
    
    echo "Extraindo ${PLUGIN_NAME}..."
    mkdir -p "$PLUGIN_PATH"
    unzip -q -o "$ZIP_FILE" -d "$PLUGIN_PATH"
    rm -f "$ZIP_FILE"
    
    # Configurar permissoes
    chown -R www-data:www-data "$PLUGIN_PATH"
    chmod -R 755 "$PLUGIN_PATH"
    
    echo "Plugin ${PLUGIN_NAME} instalado com sucesso"
}

# Criar diretorio de plugins
mkdir -p "$PLUGINS_DIR"

echo "Iniciando instalacao de plugins..."
echo ""

# Instalar Roundcube (Webmail)
install_plugin "roundcube"

# Instalar Rainloop (Webmail alternativo)
install_plugin "rainloop"

# Instalar phpMyAdmin
install_plugin "phpmyadmin"

echo ""
echo "Instalacao de plugins concluida!"
