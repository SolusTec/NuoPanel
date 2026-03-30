#!/bin/bash
################################################################################
# NuoPanel - Replace Password Placeholders
# Descricao: Substitui %password% nos arquivos de configuracao
################################################################################

replace_password_placeholder() {
    local SEARCH_DIR="$1"
    local NEW_PASS="$2"
    
    if [ -z "$SEARCH_DIR" ] || [ -z "$NEW_PASS" ]; then
        echo "Uso: replace_password_placeholder <diretorio> <nova_senha>"
        return 1
    fi
    
    echo "Buscando %password% em $SEARCH_DIR..."
    
    grep -Ril "%password%" "$SEARCH_DIR" 2>/dev/null | while read file; do
        echo "Substituindo em: $file"
        sed -i "s|%password%|$NEW_PASS|g" "$file"
    done
    
    echo "Substituicao concluida."
}

get_password_from_file() {
    local password_file="$1"
    
    if [ ! -f "$password_file" ]; then
        echo "ERRO: Arquivo $password_file nao existe." >&2
        return 1
    fi
    
    local password=$(cat "$password_file")
    
    if [ -z "$password" ]; then
        echo "ERRO: Arquivo $password_file esta vazio." >&2
        return 1
    fi
    
    echo "$password"
}

# Executar substituicao
replace_password_placeholder /etc "$(get_password_from_file "/root/db_credentials_panel.txt")"