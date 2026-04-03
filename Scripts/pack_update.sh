#!/bin/bash
# ============================================================
# NUOPANEL - SMART UPDATE PACKAGER v2.0
# Cria panel_update.zip com manifest.json inteligente
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}============================================================"
echo "🚀 NUOPANEL - SMART UPDATE PACKAGER"
echo "============================================================${NC}"
echo ""

# Verificações básicas
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}❌ Execute como root!${NC}"
    exit 1
fi

PANEL_DIR="/usr/local/lsws/Example/html/nuopanel"
if [ ! -d "$PANEL_DIR" ]; then
    echo -e "${RED}❌ Painel não encontrado!${NC}"
    exit 1
fi

# Verificar se jq está instalado
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}⚠️  jq não encontrado, instalando...${NC}"
    apt-get update -qq
    apt-get install -y jq
fi

# Solicitar versão
CURRENT_VERSION=$(cat $PANEL_DIR/etc/version 2>/dev/null || echo "unknown")
echo -e "${YELLOW}📌 Versão atual: $CURRENT_VERSION${NC}"
echo ""

while true; do
    read -p "Digite a NOVA versão (formato X.X.X): " NEW_VERSION
    if [[ $NEW_VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        break
    else
        echo -e "${RED}❌ Formato inválido! Use: X.X.X (ex: 1.0.3)${NC}"
    fi
done

echo ""
echo -e "${GREEN}✅ Nova versão: $NEW_VERSION${NC}"
echo ""

read -p "Continuar empacotamento? (s/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo -e "${RED}❌ Cancelado${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"

# PASSO 1: Criar diretório de trabalho
echo -e "${GREEN}[1/10] Criando diretório de trabalho...${NC}"
WORK_DIR="/root/panel_update_package_v${NEW_VERSION}"
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR/panel_update"
cd "$WORK_DIR"
echo -e "       ${GREEN}✓ Diretório criado: $WORK_DIR${NC}"
echo ""

# PASSO 2: Copiar código Django
echo -e "${GREEN}[2/10] Copiando código Django...${NC}"
cp -r /usr/local/lsws/Example/html/nuopanel ./panel_update/
echo -e "       ${GREEN}✓ nuopanel/ copiado${NC}"
echo ""

# PASSO 3: Copiar 3rdparty (Roundcube + Rainloop)
echo -e "${GREEN}[3/10] Copiando webmails (3rdparty)...${NC}"
mkdir -p ./panel_update/3rdparty
cp -r /usr/local/lsws/Example/html/nuopanel/3rdparty/roundcube ./panel_update/3rdparty/ 2>/dev/null || echo "  Roundcube não encontrado"
cp -r /usr/local/lsws/Example/html/nuopanel/3rdparty/rainloop ./panel_update/3rdparty/ 2>/dev/null || echo "  Rainloop não encontrado"
echo -e "       ${GREEN}✓ 3rdparty/ copiado${NC}"
echo ""

# PASSO 4: Copiar phpMyAdmin
echo -e "${GREEN}[4/10] Copiando phpMyAdmin...${NC}"
cp -r /usr/local/lsws/Example/html/phpmyadmin ./panel_update/ 2>/dev/null || echo "  phpMyAdmin não encontrado"
echo -e "       ${GREEN}✓ phpmyadmin/ copiado${NC}"
echo ""

# PASSO 5: Copiar Softaculous (se existir)
echo -e "${GREEN}[5/10] Verificando Softaculous...${NC}"
if [ -d "/usr/local/softaculous" ]; then
    cp -r /usr/local/softaculous ./panel_update/
    echo -e "       ${GREEN}✓ softaculous/ copiado${NC}"
else
    echo -e "       ${YELLOW}⚠️  Softaculous não encontrado (opcional)${NC}"
fi
echo ""

# PASSO 6: Limpar arquivos temporários
echo -e "${GREEN}[6/10] Limpando arquivos temporários...${NC}"
find ./panel_update/nuopanel -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
find ./panel_update/nuopanel -name "*.pyc" -delete 2>/dev/null || true
find ./panel_update/nuopanel/logs/ -name "*.log" -delete 2>/dev/null || true
rm -f ./panel_update/nuopanel/db.sqlite3 2>/dev/null || true
rm -rf ./panel_update/nuopanel/media/uploads/* 2>/dev/null || true
echo -e "       ${GREEN}✓ Arquivos temporários removidos${NC}"
echo ""

# PASSO 7: Criar manifest.json
echo -e "${GREEN}[7/10] Gerando manifest.json...${NC}"
cat > ./panel_update/manifest.json << ENDMANIFEST
{
  "version": "$NEW_VERSION",
  "release_date": "$(date +%Y-%m-%d)",
  "components": [
    {
      "name": "nuopanel",
      "source": "nuopanel/",
      "destination": "/usr/local/lsws/Example/html/nuopanel/",
      "action": "update",
      "preserve": [
        "db.sqlite3",
        "etc/mysqlPassword",
        "etc/ip",
        "etc/osName",
        "etc/osVersion",
        "etc/conf.ini",
        "media/uploads",
        "logs"
      ],
      "permissions": {
        "owner": "www-data",
        "group": "www-data",
        "chmod": "755"
      },
      "post_update": [
        "python3 manage.py migrate",
        "systemctl restart cp"
      ]
    },
    {
      "name": "3rdparty",
      "source": "3rdparty/",
      "destination": "/usr/local/lsws/Example/html/nuopanel/3rdparty/",
      "action": "replace",
      "preserve": [
        "roundcube/config/config.inc.php",
        "rainloop/data/_data_/_default_/configs/application.ini"
      ],
      "permissions": {
        "owner": "www-data",
        "group": "www-data",
        "chmod": "755"
      }
    },
    {
      "name": "phpmyadmin",
      "source": "phpmyadmin/",
      "destination": "/usr/local/lsws/Example/html/phpmyadmin/",
      "action": "replace",
      "preserve": [
        "config.inc.php"
      ],
      "permissions": {
        "owner": "www-data",
        "group": "www-data",
        "chmod": "755"
      }
    }
  ],
  "database_migrations": true,
  "backup_before_update": true,
  "min_version_required": "1.0.0"
}
ENDMANIFEST

echo -e "       ${GREEN}✓ manifest.json criado${NC}"
echo ""

# PASSO 8: Criar README
echo -e "${GREEN}[8/10] Criando README...${NC}"
cat > ./panel_update/README.txt << 'ENDREADME'
NUOPANEL UPDATE PACKAGE
=======================

Version: __VERSION__
Release Date: __DATE__

This package contains:
- NuoPanel Django application (with migrations)
- Webmail clients (Roundcube, Rainloop)
- phpMyAdmin
- manifest.json (update instructions)

DO NOT extract manually!
Use the official upgrade script:

  curl -sSL https://raw.githubusercontent.com/SolusTec/NuoPanel/main/Scripts/upgrade.sh | bash

Or run check_version:

  /root/.venv/bin/python manage.py check_version

ENDREADME

sed -i "s/__VERSION__/$NEW_VERSION/g" ./panel_update/README.txt
sed -i "s/__DATE__/$(date +%Y-%m-%d)/g" ./panel_update/README.txt
echo -e "       ${GREEN}✓ README.txt criado${NC}"
echo ""

# PASSO 9: Criar ZIP
echo -e "${GREEN}[9/10] Criando arquivo ZIP...${NC}"
ZIP_NAME="panel_update_v${NEW_VERSION}.zip"
cd panel_update
zip -r "../$ZIP_NAME" . >/dev/null 2>&1
cd ..

if [ ! -f "$ZIP_NAME" ]; then
    echo -e "${RED}❌ Erro ao criar ZIP!${NC}"
    exit 1
fi

FILE_SIZE=$(ls -lh "$ZIP_NAME" | awk '{print $5}')
echo -e "       ${GREEN}✓ ZIP criado: $ZIP_NAME (${FILE_SIZE})${NC}"
echo ""

# PASSO 10: Copiar para /root
echo -e "${GREEN}[10/10] Finalizando...${NC}"
cp "$ZIP_NAME" "/root/$ZIP_NAME"
echo -e "       ${GREEN}✓ Arquivo disponível em: /root/$ZIP_NAME${NC}"
echo ""

# RESUMO FINAL
echo -e "${BLUE}════════════════════════════════════════════════════════════"
echo "✅ UPDATE PACKAGE CRIADO COM SUCESSO!"
echo "════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}📊 RESUMO:${NC}"
echo -e "   Versão: ${GREEN}$NEW_VERSION${NC}"
echo -e "   Arquivo: ${GREEN}/root/$ZIP_NAME${NC}"
echo -e "   Tamanho: ${GREEN}${FILE_SIZE}${NC}"
echo ""
echo -e "${YELLOW}📦 COMPONENTES INCLUÍDOS:${NC}"
echo -e "   ✓ NuoPanel Django (com migrations)"
echo -e "   ✓ Webmails (Roundcube + Rainloop)"
echo -e "   ✓ phpMyAdmin"
echo -e "   ✓ manifest.json"
echo ""
echo -e "${YELLOW}📤 PRÓXIMOS PASSOS:${NC}"
echo ""
echo -e "${BLUE}# 1. Atualizar repositório GitHub:${NC}"
echo -e "   cd ~/NuoPanel"
echo -e "   cp ~/panel_update_v${NEW_VERSION}.zip Assets/panel_update.zip"
echo -e "   echo '$NEW_VERSION' > version.txt"
echo -e "   git add Assets/panel_update.zip version.txt"
echo -e "   git commit -m 'Release v$NEW_VERSION - Smart Update'"
echo -e "   git push origin main"
echo ""
echo -e "${BLUE}# 2. Testar update em servidor de testes:${NC}"
echo -e "   /root/.venv/bin/python manage.py check_version"
echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo ""

# Limpar diretório de trabalho
cd /root
rm -rf "$WORK_DIR"

exit 0
