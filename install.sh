#!/bin/sh

echo -e "\nNuoPanel installation is now starting, please wait...\n"

# Detect OS version
OUTPUT=$(cat /etc/*release)

if echo "$OUTPUT" | grep -q "Ubuntu 18.04"; then
    SERVER_OS="Ubuntu"
    sudo apt update -qq && sudo apt install -y -qq wget curl
elif echo "$OUTPUT" | grep -q "Ubuntu 20.04"; then
    SERVER_OS="Ubuntu"
    sudo apt update -qq && sudo apt install -y -qq wget curl
elif echo "$OUTPUT" | grep -q "Ubuntu 22.04"; then
    SERVER_OS="Ubuntu"
    sudo apt update -qq && sudo apt install -y -qq wget curl
elif echo "$OUTPUT" | grep -q "Ubuntu 24.04"; then
    SERVER_OS="Ubuntu"
    sudo apt update -qq && sudo apt install -y -qq wget curl
elif echo "$OUTPUT" | grep -q "Debian"; then
    SERVER_OS="Debian"
    sudo apt update -qq && sudo apt install -y -qq wget curl
elif echo "$OUTPUT" | grep -q "AlmaLinux 8"; then
    SERVER_OS="Centos"
    sudo dnf update -y -q && sudo dnf install -y -q wget curl
elif echo "$OUTPUT" | grep -q "AlmaLinux 9"; then
    SERVER_OS="Centos"
    sudo dnf update -y -q && sudo dnf install -y -q wget curl
elif echo "$OUTPUT" | grep -q "CentOS Linux 8" || echo "$OUTPUT" | grep -q "CentOS Stream 8"; then
    SERVER_OS="Centos"
    sudo dnf update -y -q && sudo dnf install -y -q wget curl
elif echo "$OUTPUT" | grep -q "CentOS Stream 9"; then
    SERVER_OS="Centos"
    sudo dnf update -y -q && sudo dnf install -y -q wget curl
elif echo "$OUTPUT" | grep -q "Rocky Linux 8"; then
    SERVER_OS="Centos"
    sudo dnf update -y -q && sudo dnf install -y -q wget curl
elif echo "$OUTPUT" | grep -q "Rocky Linux 9"; then
    SERVER_OS="Centos"
    sudo dnf update -y -q && sudo dnf install -y -q wget curl
else
    echo -e "\nNuoPanel is supported only on:"
    echo "  - Ubuntu 18.04, 20.04, 22.04, 24.04"
    echo "  - Debian 11, 12"
    echo "  - AlmaLinux 8, 9"
    echo "  - CentOS Stream 8, 9"
    echo "  - Rocky Linux 8, 9"
    echo ""
    echo "Other OS support coming soon.\n"
    exit 1
fi

echo -e "\n✅ Detected OS: $SERVER_OS\n"

# Download installation script
echo "Downloading NuoPanel installer..."
wget -O panel.sh "https://raw.githubusercontent.com/SolusTec/NuoPanel/main/Server-OS/$SERVER_OS/panel.sh" --no-cache --no-cookies

if [ ! -f panel.sh ]; then
    echo "❌ Failed to download panel.sh. Exiting."
    exit 1
fi

# Ensure the script is executable
chmod +x panel.sh
sed -i 's/\r$//' panel.sh

echo "Starting NuoPanel installation..."
echo ""

# Run the installer
sh panel.sh
