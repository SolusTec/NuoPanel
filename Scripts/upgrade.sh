#!/bin/bash
# NuoPanel Simple Upgrade Script v1.0

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=========================================="
echo "NuoPanel Upgrade Script v3.1"
echo "==========================================${NC}"

# Detect project directory
if [ -f "/etc/nuopanel/base_dir" ]; then
    PROJECT_DIR="$(cat /etc/nuopanel/base_dir)"
else
    PROJECT_DIR="/usr/local/lsws/Example/html/nuopanel"
fi

BACKUP_DIR="/root/nuopanel_backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
TEMP_DIR="/tmp/nuopanel_update_$TIMESTAMP"

echo -e "${YELLOW}Project: $PROJECT_DIR${NC}"
echo ""

# Step 1: Backup
echo -e "${GREEN}[1/7] Creating backup...${NC}"
mkdir -p "$BACKUP_DIR"

tar -czf "$BACKUP_DIR/backup_$TIMESTAMP.tar.gz" \
    "$PROJECT_DIR" \
    /usr/local/lsws/Example/html/phpmyadmin \
    2>/dev/null || true

echo -e "      OK Backup created"
echo ""

# Step 2: Download update
echo -e "${GREEN}[2/7] Downloading update...${NC}"

UPDATE_URL="https://raw.githubusercontent.com/SolusTec/NuoPanel/main/Assets/panel_update.zip"

wget -q -O /tmp/panel_update.zip "$UPDATE_URL?t=$(date +%s)"

if [ ! -f /tmp/panel_update.zip ]; then
    echo -e "${RED}Download failed${NC}"
    exit 1
fi

echo -e "      OK Downloaded"
echo ""

# Step 3: Extract
echo -e "${GREEN}[3/7] Extracting update...${NC}"

rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"

unzip -q /tmp/panel_update.zip -d "$TEMP_DIR"

echo -e "      OK Extracted to $TEMP_DIR"
echo ""

# Step 4: Apply update
echo -e "${GREEN}[4/7] Applying update...${NC}"

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

echo -e "      OK Files updated"
echo ""

# Step 5: Fix permissions
echo -e "${GREEN}[5/7] Fixing permissions...${NC}"

chown -R www-data:www-data "$PROJECT_DIR"
chmod -R 755 "$PROJECT_DIR"

echo -e "      OK Permissions fixed"
echo ""

# Step 6: Database migrations
echo -e "${GREEN}[6/7] Running migrations...${NC}"

PYTHON_PATH="/root/.venv/bin/python"

if [ ! -x "$PYTHON_PATH" ]; then
    PYTHON_PATH=$(which python3)
fi

cd "$PROJECT_DIR"

$PYTHON_PATH manage.py migrate \
2>&1 | grep -E "Applying|Operations|WARNINGS" || echo "No migrations needed"

echo -e "      OK Migrations completed"
echo ""

# Step 7: Restart services
echo -e "${GREEN}[7/7] Restarting services...${NC}"

systemctl restart cp 2>/dev/null || true
sleep 2

/usr/local/lsws/bin/lswsctrl restart 2>/dev/null || true

echo -e "      OK Services restarted"
echo ""

# Cleanup
rm -rf "$TEMP_DIR"
rm -f /tmp/panel_update.zip

NEW_VERSION=$(cat "$PROJECT_DIR/etc/version" 2>/dev/null || echo "unknown")

echo ""
echo -e "${GREEN}=========================================="
echo "Update Completed Successfully"
echo "==========================================${NC}"

echo -e "Version: ${GREEN}$NEW_VERSION${NC}"
echo -e "Backup: ${YELLOW}$BACKUP_DIR/backup_$TIMESTAMP.tar.gz${NC}"
echo ""

exit 0