#!/bin/bash
# NuoPanel Simple Upgrade Script v3.3 with auto rollback

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=========================================="
echo "NuoPanel Upgrade Script v1.0"
echo "==========================================${NC}"

# check rsync
if ! command -v rsync >/dev/null 2>&1; then
    echo -e "${YELLOW}Installing rsync...${NC}"
    apt-get update -y >/dev/null 2>&1
    apt-get install -y rsync >/dev/null 2>&1
fi

# Detect project directory
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
        echo -e "${RED}Backup not found, rollback failed${NC}"
    fi

    exit 1
}

trap rollback ERR

echo -e "${YELLOW}Project: $PROJECT_DIR${NC}"
echo ""

# Step 1: Backup
echo -e "${GREEN}[1/6] Creating backup...${NC}"

mkdir -p "$BACKUP_DIR"

tar -czf "$BACKUP_FILE" \
    "$PROJECT_DIR" \
    /usr/local/lsws/Example/html/phpmyadmin \
    2>/dev/null

echo "OK Backup created"
echo ""

# Step 2: Download update
echo -e "${GREEN}[2/6] Downloading update...${NC}"

UPDATE_URL="https://raw.githubusercontent.com/SolusTec/NuoPanel/main/Assets/panel_update.zip"

wget -q -O /tmp/panel_update.zip "$UPDATE_URL?t=$(date +%s)"

echo "OK Downloaded"
echo ""

# Step 3: Extract
echo -e "${GREEN}[3/6] Extracting update...${NC}"

rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"

unzip -q /tmp/panel_update.zip -d "$TEMP_DIR"

echo "OK Extracted"
echo ""

# Step 4: Apply update
echo -e "${GREEN}[4/6] Applying update...${NC}"

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

echo "OK Files updated"
echo ""

# Step 5: Database migrations
echo -e "${GREEN}[5/6] Running migrations...${NC}"

PYTHON_PATH="/root/.venv/bin/python"

if [ ! -x "$PYTHON_PATH" ]; then
    PYTHON_PATH=$(which python3)
fi

cd "$PROJECT_DIR"

$PYTHON_PATH manage.py migrate

echo "OK Migrations completed"
echo ""

# Step 6: Restart services
echo -e "${GREEN}[6/6] Restarting services...${NC}"

systemctl restart cp 2>/dev/null || true
sleep 2

/usr/local/lsws/bin/lswsctrl restart 2>/dev/null || true

echo "OK Services restarted"
echo ""

# cleanup
rm -rf "$TEMP_DIR"
rm -f /tmp/panel_update.zip

NEW_VERSION=$(cat "$PROJECT_DIR/etc/version" 2>/dev/null || echo "unknown")

echo ""
echo -e "${GREEN}=========================================="
echo "Update Completed Successfully"
echo "==========================================${NC}"

echo -e "Version: ${GREEN}$NEW_VERSION${NC}"
echo -e "Backup: ${YELLOW}$BACKUP_FILE${NC}"
echo ""

exit 0