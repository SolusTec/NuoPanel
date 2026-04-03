#!/bin/bash

# NuoPanel Upgrade Script
# This script updates the panel to the latest version

set -e  # Exit on error

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=========================================="
echo "NuoPanel Upgrade Script"
echo "==========================================${NC}"

# Detect project directory
HOME_PATH_FILE="/etc/nuopanel/base_dir"
if [ -f "$HOME_PATH_FILE" ]; then
    PROJECT_DIR="$(cat "$HOME_PATH_FILE")"
else
    PROJECT_DIR="/usr/local/lsws/Example/html/nuopanel"
fi

PARENT_DIR="${PROJECT_DIR%/*}"
BACKUP_DIR="/root/nuopanel_backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo -e "${YELLOW}Project directory: $PROJECT_DIR${NC}"
echo ""

# Step 1: Create backup
echo -e "${GREEN}Step 1: Creating backup...${NC}"
mkdir -p "$BACKUP_DIR"
tar -czf "$BACKUP_DIR/nuopanel_backup_$TIMESTAMP.tar.gz" -C "$PARENT_DIR" nuopanel/ 2>/dev/null || true
echo -e "${GREEN}✅ Backup created: $BACKUP_DIR/nuopanel_backup_$TIMESTAMP.tar.gz${NC}"
echo ""

# Step 2: Download update
echo -e "${GREEN}Step 2: Downloading update...${NC}"
UPDATE_URL="https://raw.githubusercontent.com/SolusTec/NuoPanel/main/Assets/panel_setup.zip"
DOWNLOAD_PATH="$PARENT_DIR/panel_setup_update.zip"

wget -O "$DOWNLOAD_PATH" "$UPDATE_URL?t=$(date +%s)" --no-cache --no-cookies

if [ ! -f "$DOWNLOAD_PATH" ]; then
    echo -e "${RED}❌ Failed to download update file!${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Update downloaded${NC}"
echo ""

# Step 3: Extract update (preserve database and config)
echo -e "${GREEN}Step 3: Extracting update...${NC}"

# Create temp extraction directory
TEMP_DIR="$PARENT_DIR/panel_update_temp"
mkdir -p "$TEMP_DIR"
unzip -o "$DOWNLOAD_PATH" -d "$TEMP_DIR" > /dev/null

# Move extracted content to project directory (preserve sensitive files)
echo -e "${YELLOW}Updating files (preserving database and configs)...${NC}"

# Preserve these files/dirs
PRESERVE=(
    "db.sqlite3"
    "etc/mysqlPassword"
    "etc/version"
    "etc/ip"
    "etc/osName"
    "etc/osVersion"
    "etc/conf.ini"
    "media/uploads"
    "logs"
)

# Copy all files from temp to project, then restore preserved files
rsync -a --exclude-from=<(printf '%s\n' "${PRESERVE[@]}") "$TEMP_DIR/nuopanel/" "$PROJECT_DIR/"

# Cleanup temp
rm -rf "$TEMP_DIR"
rm -f "$DOWNLOAD_PATH"

echo -e "${GREEN}✅ Files updated${NC}"
echo ""

# Step 4: Run Django migrations
echo -e "${GREEN}Step 4: Running database migrations...${NC}"

PYTHON_PATH="/root/.venv/bin/python"
if [ ! -x "$PYTHON_PATH" ]; then
    PYTHON_PATH=$(which python3)
fi

cd "$PROJECT_DIR"
$PYTHON_PATH manage.py migrate --fake-initial 2>&1 | grep -v "No migrations to apply" || true
echo -e "${GREEN}✅ Migrations completed${NC}"
echo ""

# Step 5: Run database_update.sh
echo -e "${GREEN}Step 5: Running database updates...${NC}"
curl -sSL https://raw.githubusercontent.com/SolusTec/NuoPanel/main/Scripts/database_update.sh | bash
echo ""

# Step 6: Update version file
echo -e "${GREEN}Step 6: Fetching latest version...${NC}"
LATEST_VERSION=$(curl -s https://raw.githubusercontent.com/SolusTec/NuoPanel/main/version.txt)
if [ -n "$LATEST_VERSION" ]; then
    echo "$LATEST_VERSION" > "$PROJECT_DIR/etc/version"
    echo -e "${GREEN}✅ Version updated to: $LATEST_VERSION${NC}"
else
    echo -e "${YELLOW}⚠️  Could not fetch version, keeping current${NC}"
fi
echo ""

# Step 7: Set permissions
echo -e "${GREEN}Step 7: Setting permissions...${NC}"
chown -R www-data:www-data "$PROJECT_DIR"
chmod -R 755 "$PROJECT_DIR"
echo -e "${GREEN}✅ Permissions set${NC}"
echo ""

# Step 8: Restart services
echo -e "${GREEN}Step 8: Restarting services...${NC}"
systemctl restart cp 2>/dev/null || true
/usr/local/lsws/bin/lswsctrl restart 2>/dev/null || true
echo -e "${GREEN}✅ Services restarted${NC}"
echo ""

echo -e "${GREEN}=========================================="
echo "✅ NuoPanel upgrade completed successfully!"
echo "==========================================${NC}"
echo ""
echo -e "Backup location: ${YELLOW}$BACKUP_DIR/nuopanel_backup_$TIMESTAMP.tar.gz${NC}"
echo ""

exit 0
