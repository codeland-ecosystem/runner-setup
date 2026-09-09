#!/bin/bash
#
# Installs the crunner API server into a runner container.
#
# crunner is a small C HTTP server that receives POSTed code, executes it, and
# returns the output. It listens on the port in $runnerPort (default 1500) so
# the manager/nginx proxy can route to it.
#
# This is run INSIDE the container (as root) by host-setup.sh.

set -euo pipefail

echo "Installing crunner..."

# Build dependencies.
apt-get install -y gcc make git libc6-dev

CRUNNER_SRC="${CRUNNER_SRC:-https://github.com/codeland-ecosystem/crunner.git}"
CRUNNER_DIR="${CRUNNER_DIR:-/tmp/crunner-build}"
RUNNER_PORT="${RUNNER_PORT:-1500}"

rm -rf "${CRUNNER_DIR}"
git clone --depth 1 "${CRUNNER_SRC}" "${CRUNNER_DIR}"
cd "${CRUNNER_DIR}"

# Build the crunner binary.
gcc -c cJSON/cJSON.c server.c
gcc cJSON.o server.o -o crunner -lm

# Install the binary.
install -m 0755 crunner /usr/local/bin/crunner

# Set the port crunner binds to (the manager proxies to this port).
echo "runnerPort=${RUNNER_PORT}" > /etc/environment

# Create a non-root runner user to run the service (matches reference setup).
if ! id runner &>/dev/null; then
	useradd -m -s /bin/bash runner
fi

# Install the systemd service.
cat > /etc/systemd/system/crunner.service <<'EOF'
[Unit]
Description=crunner API service
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
Restart=always
User=runner
EnvironmentFile=/etc/environment
WorkingDirectory=/home/runner
ExecStart=/usr/local/bin/crunner

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable crunner.service
systemctl start crunner.service

echo "crunner installed on port ${RUNNER_PORT}"
/usr/local/bin/crunner --version 2>/dev/null || crunner 2>&1 | head -1 || true
