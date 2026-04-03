#!/bin/bash
# ============================================================
# SCRIPT DE EMPACOTAMENTO DO NUOPANEL - VERSÃO 3.0 FINAL
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}============================================================"
echo "🚀 NUOPANEL - EMPACOTAMENTO AUTOMÁTICO"
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

# Verificar se zip está instalado
if ! command -v zip &> /dev/null; then
    echo -e "${YELLOW}⚠️  zip não encontrado, instalando...${NC}"
    apt-get update -qq
    apt-get install -y zip
fi

# Versão atual
CURRENT_VERSION=$(cat $PANEL_DIR/etc/version 2>/dev/null || echo "unknown")
echo -e "${YELLOW}📌 Versão atual: $CURRENT_VERSION${NC}"
echo ""

# Solicitar nova versão
while true; do
    read -p "Digite a NOVA versão (formato X.X.X): " NEW_VERSION
    if [[ $NEW_VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        break
    else
        echo -e "${RED}❌ Formato inválido! Use: X.X.X (ex: 3.0.13)${NC}"
    fi
done

echo ""
echo -e "${GREEN}✅ Nova versão: $NEW_VERSION${NC}"
echo ""
echo -e "${YELLOW}Isso vai:${NC}"
echo "  1. Parar o serviço Django"
echo "  2. Atualizar versão: $CURRENT_VERSION → $NEW_VERSION"
echo "  3. Criar backup de segurança"
echo "  4. Gerar panel_setup_v${NEW_VERSION}.zip"
echo "  5. Reiniciar serviço Django"
echo ""

read -p "Continuar? (s/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo -e "${RED}❌ Cancelado${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"

# PASSO 1: Parar serviço
echo -e "${GREEN}[1/12] Parando serviço Django...${NC}"
systemctl stop cp 2>/dev/null || true
sleep 2
echo -e "       ${GREEN}✓ Serviço parado${NC}"
echo ""

# PASSO 2: Atualizar versão
echo -e "${GREEN}[2/12] Atualizando versão no código...${NC}"
echo "$NEW_VERSION" > $PANEL_DIR/etc/version
if [ "$(cat $PANEL_DIR/etc/version)" = "$NEW_VERSION" ]; then
    echo -e "       ${GREEN}✓ Versão atualizada: $CURRENT_VERSION → $NEW_VERSION${NC}"
else
    echo -e "${RED}❌ Erro ao atualizar versão!${NC}"
    systemctl start cp
    exit 1
fi
echo ""

# PASSO 3: Criar backup
echo -e "${GREEN}[3/12] Criando backup de segurança...${NC}"
BACKUP_DIR="/root/nuopanel_packaging_backups"
mkdir -p "$BACKUP_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/backup_v${CURRENT_VERSION}_${TIMESTAMP}.tar.gz"
tar -czf "$BACKUP_FILE" -C /usr/local/lsws/Example/html nuopanel/ 2>/dev/null
echo -e "       ${GREEN}✓ Backup criado${NC}"
echo ""

# PASSO 4: Preparar diretório
echo -e "${GREEN}[4/12] Preparando diretório de trabalho...${NC}"
WORK_DIR="/root/empacotamento_v${NEW_VERSION}"
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"
echo -e "       ${GREEN}✓ Diretório preparado: $WORK_DIR${NC}"
echo ""

# PASSO 5: Copiar arquivos
echo -e "${GREEN}[5/12] Copiando arquivos...${NC}"
cp -r /usr/local/lsws/Example/html/nuopanel ./
echo -e "       ${GREEN}✓ nuopanel/ copiado${NC}"
cp -r /usr/local/lsws/Example/html/phpmyadmin ./
echo -e "       ${GREEN}✓ phpmyadmin/ copiado${NC}"
cp -r /usr/local/lsws/Example/html/webmail ./
echo -e "       ${GREEN}✓ webmail/ copiado${NC}"
echo ""

# PASSO 6: Limpar arquivos
echo -e "${GREEN}[6/12] Limpando arquivos desnecessários...${NC}"
find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
echo -e "       ${GREEN}✓ __pycache__ removidos${NC}"
find . -name "*.pyc" -delete 2>/dev/null || true
echo -e "       ${GREEN}✓ .pyc removidos${NC}"
find nuopanel/logs/ -name "*.log" -delete 2>/dev/null || true
echo -e "       ${GREEN}✓ Logs removidos${NC}"
rm -f nuopanel/db.sqlite3 2>/dev/null || true
echo -e "       ${GREEN}✓ db.sqlite3 removido${NC}"
rm -rf nuopanel/3rdparty/ 2>/dev/null || true
echo -e "       ${GREEN}✓ Duplicatas removidas${NC}"
rm -rf nuopanel/media/uploads/* 2>/dev/null || true
echo -e "       ${GREEN}✓ Uploads removidos${NC}"
echo ""

# PASSO 7: Verificar tamanhos
echo -e "${GREEN}[7/12] Verificando tamanhos...${NC}"
du -sh nuopanel/ phpmyadmin/ webmail/ | sed 's/^/       /'
echo ""

# PASSO 8: Criar ZIP
echo -e "${GREEN}[8/12] Criando arquivo ZIP...${NC}"
ZIP_NAME="panel_setup_v${NEW_VERSION}.zip"
zip -r "$ZIP_NAME" nuopanel/ phpmyadmin/ webmail/ >/dev/null 2>&1

if [ ! -f "$ZIP_NAME" ]; then
    echo -e "${RED}❌ Erro ao criar ZIP!${NC}"
    cd /root
    systemctl start cp
    exit 1
fi
echo -e "       ${GREEN}✓ ZIP criado: $ZIP_NAME${NC}"
echo ""

# PASSO 9: Verificar ZIP
echo -e "${GREEN}[9/12] Testando integridade do ZIP...${NC}"
if unzip -t "$ZIP_NAME" >/dev/null 2>&1; then
    FILE_SIZE=$(ls -lh "$ZIP_NAME" | awk '{print $5}')
    echo -e "       ${GREEN}✓ ZIP válido (${FILE_SIZE})${NC}"
else
    echo -e "${RED}❌ ZIP corrompido!${NC}"
    cd /root
    systemctl start cp
    exit 1
fi
echo ""

# PASSO 10: Copiar para /root
echo -e "${GREEN}[10/12] Copiando para /root...${NC}"
cp "$ZIP_NAME" "/root/$ZIP_NAME"
echo -e "       ${GREEN}✓ Arquivo disponível em: /root/$ZIP_NAME${NC}"
echo ""

# PASSO 11: Limpar
echo -e "${GREEN}[11/12] Limpando diretório de trabalho...${NC}"
cd /root
rm -rf "$WORK_DIR"
echo -e "       ${GREEN}✓ Limpeza concluída${NC}"
echo ""

# PASSO 12: Reiniciar serviço
echo -e "${GREEN}[12/12] Reiniciando serviço Django...${NC}"
systemctl start cp
sleep 3
if systemctl is-active --quiet cp; then
    echo -e "       ${GREEN}✓ Serviço reiniciado com sucesso${NC}"
else
    echo -e "       ${YELLOW}⚠️  Verifique o serviço manualmente${NC}"
fi
echo ""

# RESUMO FINAL
echo -e "${BLUE}════════════════════════════════════════════════════════════"
echo "✅ EMPACOTAMENTO CONCLUÍDO COM SUCESSO!"
echo "════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}📊 RESUMO:${NC}"
echo -e "   Versão: ${RED}$CURRENT_VERSION${NC} → ${GREEN}$NEW_VERSION${NC}"
echo -e "   ZIP: ${GREEN}/root/panel_setup_v${NEW_VERSION}.zip${NC}"
echo -e "   Backup: ${GREEN}$BACKUP_FILE${NC}"
echo ""
echo -e "${YELLOW}📤 PRÓXIMOS PASSOS:${NC}"
echo ""
echo -e "${BLUE}# 1. Transferir para servidor de desenvolvimento:${NC}"
echo -e "   scp root@Nuo-Panel:~/panel_setup_v${NEW_VERSION}.zip ~/"
echo ""
echo -e "${BLUE}# 2. Atualizar repositório GitHub:${NC}"
echo -e "   cd ~/NuoPanel"
echo -e "   cp ~/panel_setup_v${NEW_VERSION}.zip Assets/panel_setup.zip"
echo -e "   echo '$NEW_VERSION' > version.txt"
echo -e "   git add Assets/panel_setup.zip version.txt"
echo -e "   git commit -m 'Release v$NEW_VERSION'"
echo -e "   git push origin main"
echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo ""

exit 0
