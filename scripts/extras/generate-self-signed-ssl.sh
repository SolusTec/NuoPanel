#!/bin/bash
################################################################################
# NuoPanel - Generate Self-Signed SSL Certificate
# Descricao: Gera certificado SSL autoassinado se nao existir
################################################################################

DOMAIN="nuopanel.local"
SSL_DIR="/etc/letsencrypt/live/$DOMAIN"

# Detectar servico OpenLiteSpeed
if systemctl list-units --type=service | grep -q "lshttpd"; then
    OLS_SERVICE="lshttpd"
elif systemctl list-units --type=service | grep -q "lsws"; then
    OLS_SERVICE="lsws"
else
    OLS_SERVICE="lsws"  # fallback
fi

echo "Configurando SSL autoassinado para: $DOMAIN"

# Criar diretorio se nao existir
if [ ! -d "$SSL_DIR" ]; then
    echo "Criando diretorio SSL: $SSL_DIR"
    mkdir -p "$SSL_DIR"
fi

# Verificar se certificado ja existe
if [ ! -f "$SSL_DIR/privkey.pem" ] || [ ! -f "$SSL_DIR/fullchain.pem" ]; then
    echo "Gerando certificado SSL autoassinado..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$SSL_DIR/privkey.pem" \
        -out "$SSL_DIR/fullchain.pem" \
        -subj "/CN=$DOMAIN"
    
    echo "Certificado SSL gerado: $SSL_DIR"
else
    echo "Certificado SSL ja existe em $SSL_DIR - pulando geracao"
fi

# Definir permissoes
chmod 600 "$SSL_DIR/privkey.pem"
chmod 644 "$SSL_DIR/fullchain.pem"
chown root:root "$SSL_DIR/privkey.pem" "$SSL_DIR/fullchain.pem"

echo "Permissoes configuradas"

# Reiniciar OpenLiteSpeed
echo "Reiniciando OpenLiteSpeed ($OLS_SERVICE)..."
systemctl restart "$OLS_SERVICE" 2>/dev/null || /usr/local/lsws/bin/lswsctrl restart

echo "SSL autoassinado configurado para $DOMAIN"