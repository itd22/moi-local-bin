#!/bin/bash
set -e

echo "=== 1. Detecting Desktop Environment ==="
# Normalize desktop string to lower case
DESKTOP=$(echo "${XDG_CURRENT_DESKTOP:-$DESKTOP_SESSION}" | tr '[:upper:]' '[:lower:]')
ASKPASS_BIN=""

if [[ "$DESKTOP" == *"kde"* || "$DESKTOP" == *"plasma"* ]]; then
    echo "Detected: KDE Plasma"
    ASKPASS_PACKAGE="ksshaskpass"
    ASKPASS_BIN="/usr/bin/ksshaskpass"

else
    echo "Deskto is not plasma desktop."
    exit 1
fi

echo "Installing KDE Askpass Utility ==="
if ! command -v ksshaskpass &> /dev/null; then
    echo "ksshaskpass is not installed, exiting."
    exit 1
fi

echo "Configuring ~/.bashrc"
# Scan for the actual variable assignment string inside .bashrc
if grep -q "export GIT_ASKPASS=" "\$HOME/.bashrc" 2>/dev/null; then
    echo "GIT_ASKPASS variable already found in ~/.bashrc. Skipping file modification."
else
    echo "Adding KWallet environment variables to ~/.bashrc..."
    cat << 'EOF' >> ~/.bashrc

# Route SSH and Git passphrase requests through KDE KWallet
export SSH_ASKPASS=/usr/bin/ksshaskpass
export GIT_ASKPASS=/usr/bin/ksshaskpass
EOF
fi

echo "Configuring ~/.ssh/config ==="

# Scan for the standard configuration hook inside the SSH config
if grep -q "AddKeysToAgent" "\$HOME/.ssh/config" 2>/dev/null; then
    echo "SSH config rules already exist. Skipping file modification."
else
    echo "Adding automated key rules to ~/.ssh/config..."
    cat << 'EOF' >> ~/.ssh/config

Host *
    AddKeysToAgent yes
    IdentityFile ~/.ssh/id_ed25519
    IdentityFile ~/.ssh/id_rsa
EOF
    chmod 600 ~/.ssh/config
fi

echo "=== Configuration Complete! ==="
echo "Please restart your terminal or run: source ~/.bashrc"

echo "run :ssh-add ~/.ssh/id_ed25519 2>/dev/null || ssh-add ~/.ssh/id_rsa"
