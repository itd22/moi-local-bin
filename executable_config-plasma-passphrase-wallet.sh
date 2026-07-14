#!/bin/bash
set -uo pipefail

echo "== Step 1: ssh-agent.socket =="

if ! systemctl --user is-enabled ssh-agent.socket &>/dev/null; then
    echo "-> Not enabled yet, enabling..."
    systemctl --user enable ssh-agent.socket
else
    echo "-> Already enabled."
fi

if ! systemctl --user is-active ssh-agent.socket &>/dev/null; then
    echo "-> Not active yet, starting..."
    systemctl --user start ssh-agent.socket
else
    echo "-> Already active."
fi

# Confirm the actual socket path this unit uses (don't assume)
SOCK_PATH=$(systemctl --user show ssh-agent.socket -p Listen --value | awk '{print $1}')
if [ -z "$SOCK_PATH" ]; then
    echo "ERROR: could not determine socket path from systemd. Aborting."
    exit 1
fi
echo "-> systemd reports socket path: $SOCK_PATH"

if [ -S "$SOCK_PATH" ]; then
    echo "-> Socket file exists on disk: $SOCK_PATH"
else
    echo "ERROR: socket file does not exist at $SOCK_PATH despite unit being active."
    systemctl --user status ssh-agent.socket --no-pager
    exit 1
fi

echo
echo "== Step 2: environment.d config (for GUI apps / Plasma session) =="

ENV_DIR="$HOME/.config/environment.d"
ENV_FILE="$ENV_DIR/ssh-agent.conf"

if [ ! -d "$ENV_DIR" ]; then
    echo "-> $ENV_DIR does not exist, creating..."
    mkdir -p "$ENV_DIR"
else
    echo "-> $ENV_DIR already exists."
fi

cat > "$ENV_FILE" << EOF
SSH_AUTH_SOCK=${SOCK_PATH}
SSH_ASKPASS=/usr/bin/ksshaskpass
SSH_ASKPASS_REQUIRE=prefer
EOF
echo "-> Wrote $ENV_FILE with SSH_AUTH_SOCK=${SOCK_PATH}"

echo
echo "== Done with system setup. =="
echo
echo "Add the following to your ~/.bashrc so every NEW terminal picks up the agent:"
echo
echo "    export SSH_AUTH_SOCK=\"${SOCK_PATH}\""
echo "    export SSH_ASKPASS=/usr/bin/ksshaskpass"
echo "    export SSH_ASKPASS_REQUIRE=prefer"
echo
echo "Then open a NEW terminal (or 'source ~/.bashrc') and run:"
echo "    ssh-add ~/.ssh/id_ed25519"

