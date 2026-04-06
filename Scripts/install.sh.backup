#!/bin/bash

HOME_PATH_FILE="/etc/nuopanel/base_dir"
if [ -f "$HOME_PATH_FILE" ]; then
    # Read value from file
    PROJECT_DIR="$(cat "$HOME_PATH_FILE")"
else
    # Extract from systemd service
    PROJECT_DIR="/usr/local/lsws/Example/html/nuopanel"
fi


# Detect OS info
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_NAME=$ID
    OS_VERSION=${VERSION_ID%%.*}
elif [ -f /etc/centos-release ]; then
    OS_NAME="centos"
    OS_VERSION=$(awk '{print $4}' /etc/centos-release | cut -d. -f1)
fi


run_py() {
    # SEMPRE usar venv do root, independente do OS
    local PYTHON_CMD="/root/.venv/bin/python"
    
    # Se não existir, tentar python3
    if [ ! -x "$PYTHON_CMD" ]; then
        PYTHON_CMD="/root/.venv/bin/python3"
    fi
    
    # Se ainda não existir, tentar python3.12
    if [ ! -x "$PYTHON_CMD" ]; then
        PYTHON_CMD="/root/.venv/bin/python3.12"
    fi

    echo "Trying $PYTHON_CMD $PROJECT_DIR/manage.py install_olsapp"
    $PYTHON_CMD $PROJECT_DIR/manage.py install_olsapp
    local STATUS=$?

    if [[ $STATUS -ne 0 ]]; then
        echo "First attempt failed, trying fallback Python interpreters..."

        # Fallback Python interpreters to try if the first fails
        local FALLBACKS=(
            "/root/.venv/bin/python"
            "/root/.venv/bin/python3"
            "/root/.venv/bin/python3.12"
        )

        for alt_python in "${FALLBACKS[@]}"; do
            if [[ -x "$alt_python" ]]; then
                echo "Trying fallback: $alt_python $PROJECT_DIR/manage.py install_olsapp"
                $alt_python $PROJECT_DIR/manage.py install_olsapp
                STATUS=$?
                if [[ $STATUS -eq 0 ]]; then
                    echo "Succeeded with fallback: $alt_python"
                    return 0
                fi
            else
                echo "Fallback interpreter not executable or not found: $alt_python"
            fi
        done

        echo "All fallback attempts failed."
        return 1
    fi
}


create_nuopanel_conf() {
    CONF_DIR="/usr/local/nuopanel/nuopanel/plugin"
    CONF_FILE="$CONF_DIR/nuopanel-app.conf"

    echo "Creating nuopanel-app plugin config..."

    mkdir -p "$CONF_DIR"

    cat > "$CONF_FILE" <<'CONFEOF'
# The Displayname.
name=NuoPanelApp

# The application's service.
service=both

url=/3rdparty/nuopanel-app/index.php 

header[HTTP_AUTOLOGINUSER]=%dbusername%
header[HTTP_AUTOLOGINPASS]=%dbuserpass% 

# System user and group to run process as
user=root
group=root 

# Features required
features=nuopanel-app

# Media  required
icon=/media/icon/nuopanel-app.png 

#short
sorder=99

#hide from display
display_hide = true
CONFEOF

    echo "Config created at: $CONF_FILE"
}

install_olsapp() {
    ZIP_URL="https://raw.githubusercontent.com/SolusTec/NuoPanel/main/Assets/olsapp.zip?ts=$(date +%s)"

    # If project is default nuopanel path
    if [ "$PROJECT_DIR" = "/usr/local/nuopanel/nuopanel" ]; then
        DEST_DIR="/usr/local/nuopanel/nuopanel/3rdparty/nuopanel-app"
        ZIP_FILE="/usr/local/nuopanel/nuopanel/3rdparty/nuopanel-app.zip"
        
    else
        DEST_DIR="${PROJECT_DIR%/*}/nuopanel-app"
        ZIP_FILE="${PROJECT_DIR%/*}/nuopanel-app.zip"
    fi

    echo "Downloading nuopanel-app..."
    wget -O "$ZIP_FILE" "$ZIP_URL" --no-cache --no-cookies

    echo "Extracting nuopanel-app..."
    mkdir -p "$DEST_DIR"
    unzip -o "$ZIP_FILE" -d "$DEST_DIR"
    rm -f "$ZIP_FILE"
    
if [ "$PROJECT_DIR" = "/usr/local/nuopanel/nuopanel" ]; then
    create_nuopanel_conf
    wget -O "$DEST_DIR/conf.php" "https://raw.githubusercontent.com/SolusTec/NuoPanel/main/Scripts/conf_for_bin.ph" --no-cache --no-cookies
    chown -R nuopanel:nuopanel $DEST_DIR
else
    chown -R nuopanel:nuopanel ${PROJECT_DIR%/*}/nuopanel-app
fi
    echo "nuopanel-app installed at: $DEST_DIR"
}



# Run installer
install_olsapp
if [ "$PROJECT_DIR" != "/usr/local/nuopanel/nuopanel" ]; then
    run_py
else
    echo "Using default nuopanel path, skipping run_py"
fi


chown -R nuopanel:nuopanel /usr/local/lsws/Example/html/nuopanel-app 2>/dev/null || true
