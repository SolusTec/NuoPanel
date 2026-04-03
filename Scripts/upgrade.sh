#!/bin/bash
# NuoPanel Smart Upgrade Script v2.0
# Reads manifest.json for intelligent updates

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=========================================="
echo "NuoPanel Smart Upgrade Script v2.0"
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
echo -e "${GREEN}Step 1: Creating full backup...${NC}"
mkdir -p "$BACKUP_DIR"
tar -czf "$BACKUP_DIR/full_backup_$TIMESTAMP.tar.gz" \
    -C "$PARENT_DIR" nuopanel/ \
    -C /usr/local/lsws/Example/html phpmyadmin/ 2>/dev/null || true
echo -e "${GREEN}✅ Backup created${NC}"
echo ""

# Step 2: Download update
echo -e "${GREEN}Step 2: Downloading smart update package...${NC}"
UPDATE_URL="https://raw.githubusercontent.com/SolusTec/NuoPanel/main/Assets/panel_update.zip"
DOWNLOAD_PATH="$PARENT_DIR/panel_update.zip"

wget -O "$DOWNLOAD_PATH" "$UPDATE_URL?t=$(date +%s)" --no-cache --no-cookies

if [ ! -f "$DOWNLOAD_PATH" ]; then
    echo -e "${RED}❌ Failed to download update!${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Update downloaded${NC}"
echo ""

# Step 3: Extract update
echo -e "${GREEN}Step 3: Extracting update package...${NC}"
TEMP_DIR="$PARENT_DIR/panel_update_temp"
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"
unzip -o "$DOWNLOAD_PATH" -d "$TEMP_DIR" > /dev/null
echo -e "${GREEN}✅ Package extracted${NC}"
echo ""

# Step 4: Read manifest
echo -e "${GREEN}Step 4: Reading manifest.json...${NC}"
MANIFEST="$TEMP_DIR/panel_update/manifest.json"

if [ ! -f "$MANIFEST" ]; then
    echo -e "${RED}❌ manifest.json not found! Old update format?${NC}"
    exit 1
fi

VERSION=$(jq -r '.version' "$MANIFEST")
echo -e "   Update version: ${GREEN}$VERSION${NC}"
echo -e "${GREEN}✅ Manifest loaded${NC}"
echo ""

# Step 5: Process components from manifest
echo -e "${GREEN}Step 5: Processing components...${NC}"

# Get number of components
COMPONENT_COUNT=$(jq '.components | length' "$MANIFEST")
echo -e "   Found $COMPONENT_COUNT components to update"
echo ""

for i in $(seq 0 $((COMPONENT_COUNT - 1))); do
    COMPONENT=$(jq -r ".components[$i]" "$MANIFEST")
    
    NAME=$(echo "$COMPONENT" | jq -r '.name')
    SOURCE=$(echo "$COMPONENT" | jq -r '.source')
    DEST=$(echo "$COMPONENT" | jq -r '.destination')
    PRESERVE=$(echo "$COMPONENT" | jq -r '.preserve[]' 2>/dev/null || echo "")
    OWNER=$(echo "$COMPONENT" | jq -r '.permissions.owner')
    GROUP=$(echo "$COMPONENT" | jq -r '.permissions.group')
    CHMOD=$(echo "$COMPONENT" | jq -r '.permissions.chmod')
    
    echo -e "${YELLOW}   → Updating: $NAME${NC}"
    
    # Create exclude file for rsync
    EXCLUDE_FILE="/tmp/exclude_${NAME}.txt"
    echo "$PRESERVE" > "$EXCLUDE_FILE"
    
    # Sync files
    rsync -a --exclude-from="$EXCLUDE_FILE" \
        "$TEMP_DIR/panel_update/$SOURCE" "$DEST" 2>/dev/null || true
    
    # Set permissions
    if [ "$OWNER" != "null" ] && [ "$GROUP" != "null" ]; then
        chown -R "$OWNER:$GROUP" "$DEST" 2>/dev/null || true
    fi
    
    if [ "$CHMOD" != "null" ]; then
        chmod -R "$CHMOD" "$DEST" 2>/dev/null || true
    fi
    
    echo -e "     ${GREEN}✓ $NAME updated${NC}"
    
    rm -f "$EXCLUDE_FILE"
done

echo -e "${GREEN}✅ All components updated${NC}"
echo ""

# Step 6: Run database migrations
if [ "$(jq -r '.database_migrations' "$MANIFEST")" = "true" ]; then
    echo -e "${GREEN}Step 6: Running database migrations...${NC}"
    
    PYTHON_PATH="/root/.venv/bin/python"
    if [ ! -x "$PYTHON_PATH" ]; then
        PYTHON_PATH=$(which python3)
    fi
    
    cd "$PROJECT_DIR"
    $PYTHON_PATH manage.py migrate --fake-initial 2>&1 | grep -v "No migrations to apply" || true
    
    echo -e "${GREEN}✅ Migrations completed${NC}"
else
    echo -e "${YELLOW}Step 6: Skipping migrations (not required)${NC}"
fi
echo ""

# Step 7: Update version file
echo -e "${GREEN}Step 7: Updating version file...${NC}"
echo "$VERSION" > "$PROJECT_DIR/etc/version"
echo -e "${GREEN}✅ Version updated to: $VERSION${NC}"
echo ""

# Step 8: Restart services
echo -e "${GREEN}Step 8: Restarting services...${NC}"
systemctl restart cp 2>/dev/null || true
/usr/local/lsws/bin/lswsctrl restart 2>/dev/null || true
echo -e "${GREEN}✅ Services restarted${NC}"
echo ""

# Cleanup
rm -rf "$TEMP_DIR"
rm -f "$DOWNLOAD_PATH"

echo -e "${GREEN}=========================================="
echo "✅ Smart Update Completed Successfully!"
echo "==========================================${NC}"
echo ""
echo -e "New version: ${GREEN}$VERSION${NC}"
echo -e "Backup: ${YELLOW}$BACKUP_DIR/full_backup_$TIMESTAMP.tar.gz${NC}"
echo ""

exit 0
