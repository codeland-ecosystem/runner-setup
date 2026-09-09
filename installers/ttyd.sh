#!/bin/bash
#
# Installs ttyd (web terminal) into a runner container.
#
# ttyd is not packaged for Debian 13, so we install the official static
# release binary. The frontend runs `ttyd -W bash` on port 7681 and connects
# to it over a WebSocket, so this is required for the in-browser terminal.
#
# This is run INSIDE the container (as root) by host-setup.sh.

set -euo pipefail

echo "Installing ttyd..."

TTYD_VERSION="${TTYD_VERSION:-1.7.7}"
TTYD_URL="${TTYD_URL:-https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/ttyd.x86_64}"

# Download the static binary.
curl -fsSL -o /tmp/ttyd "${TTYD_URL}"
chmod 0755 /tmp/ttyd

# Install it.
install -m 0755 /tmp/ttyd /usr/bin/ttyd
rm -f /tmp/ttyd

echo "ttyd installed:"
ttyd --version
