#!/bin/bash
# NuoPanel Simple Upgrade Script v1.4

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SELF_REMOVE_PATH="/usr/local/lsws/Example/html/upgrade.sh"

cleanup_self() {

    if [ -f "$SELF_REMOVE_PATH" ]; then
        rm -f "$SELF_REMOVE_PATH"
        echo "Self removed: $SELF_REMOVE_PATH"
    fi

}

# python path
PYTHON_PATH="/root/.venv/bin/python"

if [ ! -x "$PYTHON_PATH" ]; then
    PYTHON_PATH=$(which python3)
fi

echo -e "${GREEN}=========================================="
echo "NuoPanel Upgrade Script v1.4"
echo "==========================================${NC}"

# ensure rsync exists
if ! command -v rsync >/dev/null 2>&1; then
    echo -e "${YELLOW}Installing rsync...${NC}"
    apt-get update -y >/dev/null 2>&1
    apt-get install -y rsync >/dev/null 2>&1
fi

# detect project dir
if [ -f "/etc/nuopanel/base_dir" ]; then
    PROJECT_DIR="$(cat /etc/nuopanel/base_dir)"
else
    PROJECT_DIR="/usr/local/lsws/Example/html/nuopanel"
fi

BACKUP_DIR="/root/nuopanel_backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
TEMP_DIR="/tmp/nuopanel_update_$TIMESTAMP"
BACKUP_FILE="$BACKUP_DIR/backup_$TIMESTAMP.tar.gz"

rollback() {

    echo ""
    echo -e "${RED}ERROR detected, starting rollback...${NC}"

    if [ -f "$BACKUP_FILE" ]; then
        tar -xzf "$BACKUP_FILE" -C /
        echo -e "${GREEN}Rollback completed${NC}"
    else
        echo -e "${RED}Backup not found${NC}"
    fi

    # remove gatilho interno novamente
    rm -f "$PROJECT_DIR/etc/update"
    rm -f "$PROJECT_DIR/etc/update.zip"
    rm -f "$PROJECT_DIR/etc/update.tar.gz"

    cleanup_self
    exit 1
}

trap rollback ERR

echo -e "${YELLOW}Project: $PROJECT_DIR${NC}"

# backup
echo -e "${GREEN}[1/6] Backup${NC}"

mkdir -p "$BACKUP_DIR"

tar -czf "$BACKUP_FILE" \
"$PROJECT_DIR" \
/usr/local/lsws/Example/html/phpmyadmin \
2>/dev/null

echo "OK backup"

# download
echo -e "${GREEN}[2/6] Download update${NC}"

UPDATE_URL="https://github.com/SolusTec/NuoPanel/raw/main/Assets/panel_update.zip"

wget -q -O /tmp/panel_update.zip "$UPDATE_URL?t=$(date +%s)"

if [ ! -f /tmp/panel_update.zip ]; then
    echo "download failed"
    exit 1
fi

echo "OK download"

# extract
echo -e "${GREEN}[3/6] Extract${NC}"

rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"

unzip -q /tmp/panel_update.zip -d "$TEMP_DIR"

echo "OK extract"

# rsync update
echo -e "${GREEN}[4/6] Apply files${NC}"

rsync -a \
--exclude='usr/local/lsws/Example/html/nuopanel/etc/mysqlPassword' \
--exclude='usr/local/lsws/Example/html/nuopanel/etc/ip' \
--exclude='usr/local/lsws/Example/html/nuopanel/etc/osName' \
--exclude='usr/local/lsws/Example/html/nuopanel/etc/osVersion' \
--exclude='usr/local/lsws/Example/html/nuopanel/etc/conf.ini' \
--exclude='usr/local/lsws/Example/html/nuopanel/db.sqlite3' \
--exclude='usr/local/lsws/Example/html/nuopanel/media/uploads/**' \
--exclude='usr/local/lsws/Example/html/nuopanel/logs/**' \
--exclude='usr/local/lsws/Example/html/phpmyadmin/config.inc.php' \
--exclude='usr/local/lsws/Example/html/nuopanel/3rdparty/roundcube/config/config.inc.php' \
--exclude='usr/local/lsws/Example/html/nuopanel/3rdparty/rainloop/data/**' \
"$TEMP_DIR/" /

echo "OK rsync"

# remove gatilho interno
rm -f "$PROJECT_DIR/etc/update"
rm -f "$PROJECT_DIR/etc/update.zip"
rm -f "$PROJECT_DIR/etc/update.tar.gz"

# migrate
echo -e "${GREEN}[5/6] Django migrate${NC}"

cd "$PROJECT_DIR"

set +e

$PYTHON_PATH manage.py migrate --fake
STATUS1=$?

$PYTHON_PATH manage.py migrate
STATUS2=$?

set -e

if [ $STATUS1 -ne 0 ] || [ $STATUS2 -ne 0 ]; then
    exit 1
fi

echo "OK migrate"

# restart
echo -e "${GREEN}[6/6] Restart services${NC}"

systemctl restart cp 2>/dev/null || true
sleep 2
/usr/local/lsws/bin/lswsctrl restart

echo "OK restart"

# cleanup
rm -rf "$TEMP_DIR"
rm -f /tmp/panel_update.zip

# remove gatilho novamente (garantia)
rm -f "$PROJECT_DIR/etc/update"
rm -f "$PROJECT_DIR/etc/update.zip"
rm -f "$PROJECT_DIR/etc/update.tar.gz"

VERSION=$(cat "$PROJECT_DIR/etc/version" 2>/dev/null || echo unknown)

echo ""
echo "Update finished"
echo "Version: $VERSION"
echo "Backup: $BACKUP_FILE"

cleanup_self

# encerra processo que chamou o updater interno
pkill -f "manage.py check_version" 2>/dev/null || true

exit 0