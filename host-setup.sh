#!/bin/bash
#
# CodeLand runner host setup for a fresh Debian 13 (trixie) install.
#
# This script prepares a host machine to run CodeLand LXC runners:
#   - Installs LXC (with cgroup v2 support)
#   - Creates the 'virt' user the manager connects to over SSH
#   - Installs the lxc-start-ephemeral / lxc-destroy-ephemeral helpers
#   - Builds the 'crunner0' base container and installs the language runtimes
#
# Usage:
#   sudo bash host-setup.sh
#
# Stop on any error.
set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
RUNNER_USER="${RUNNER_USER:-virt}"
RUNNER_TEMPLATE="${RUNNER_TEMPLATE:-crunner0}"
RUNNER_DISTRO="${RUNNER_DISTRO:-debian}"
RUNNER_RELEASE="${RUNNER_RELEASE:-trixie}"
RUNNER_ARCH="${RUNNER_ARCH:-amd64}"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
LXC_DIR="${LXC_DIR:-$HOME/.local/share/lxc}"

# The manager's public key to authorize for the virt user. Set this to the
# contents of the manager's id_rsa_cl-worker.pub, or pass it via env.
MANAGER_PUBKEY="${MANAGER_PUBKEY:-}"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33mWARN: %s\033[0m\n' "$*"; }

require_root() {
	if [[ "$(id -u)" -ne 0 ]]; then
		echo "This script must be run as root (sudo)." >&2
		exit 1
	fi
}

# ---------------------------------------------------------------------------
# 1. Install LXC
# ---------------------------------------------------------------------------
install_lxc() {
	log "Installing LXC"
	apt-get update
	apt-get install -y lxc lxc-templates debootstrap bridge-utils \
		libvirt-clients qemu-utils curl wget ca-certificates

	# LXC 5.0+ uses cgroup v2 by default. Verify it is available.
	if [[ ! -d /sys/fs/cgroup ]]; then
		warn "cgroup v2 filesystem not found; memory limits may not work."
	fi
}

# ---------------------------------------------------------------------------
# 2. Create the runner user
# ---------------------------------------------------------------------------
create_runner_user() {
	log "Creating runner user '${RUNNER_USER}'"
	if id "${RUNNER_USER}" &>/dev/null; then
		warn "User '${RUNNER_USER}' already exists, skipping creation."
	else
		useradd -m -s /bin/bash "${RUNNER_USER}"
	fi

	# Allow the runner user to manage LXC containers.
	usermod -aG lxc "${RUNNER_USER}" || true

	# Authorize the manager's SSH key so it can drive the worker.
	if [[ -n "${MANAGER_PUBKEY}" ]]; then
		local ssh_dir="/home/${RUNNER_USER}/.ssh"
		mkdir -p "${ssh_dir}"
		chmod 700 "${ssh_dir}"
		echo "${MANAGER_PUBKEY}" >> "${ssh_dir}/authorized_keys"
		chmod 600 "${ssh_dir}/authorized_keys"
		chown -R "${RUNNER_USER}:${RUNNER_USER}" "${ssh_dir}"
		log "Authorized manager SSH key for '${RUNNER_USER}'."
	else
		warn "MANAGER_PUBKEY not set; skipping SSH key authorization."
	fi
}

# ---------------------------------------------------------------------------
# 3. Install the runner host scripts
# ---------------------------------------------------------------------------
install_host_scripts() {
	log "Installing runner host scripts"
	local src_dir="$(dirname "$0")/host-scripts"

	# The manager invokes the ephemeral helpers from ~/.local/bin.
	mkdir -p "${BIN_DIR}"
	install -m 0755 "${src_dir}/lxc-start-ephemeral" "${BIN_DIR}/lxc-start-ephemeral"
	install -m 0755 "${src_dir}/lxc-destroy-ephemeral" "${BIN_DIR}/lxc-destroy-ephemeral"
	install -m 0755 "${src_dir}/lxc-start" "${BIN_DIR}/lxc-start"
	install -m 0755 "${src_dir}/lxc-copy" "${BIN_DIR}/lxc-copy"
	install -m 0755 "${src_dir}/lxc-attach" "${BIN_DIR}/lxc-attach"

	# The privileged helpers live in /usr/local/bin (they use sudo).
	install -m 0755 "${src_dir}/lxc-mount-hack" /usr/local/bin/lxc-mount-hack
	install -m 0755 "${src_dir}/lxc-hack-destroy" /usr/local/bin/lxc-hack-destroy
	install -m 0755 "${src_dir}/lxc-hack-chown" /usr/local/bin/lxc-hack-chown
	install -m 0755 "${src_dir}/clean_crunners.sh" /usr/local/bin/clean_crunners.sh

	# Allow the runner user to run the privileged helpers without a password.
	echo "${RUNNER_USER} ALL=(ALL) NOPASSWD: /usr/local/bin/lxc-mount-hack, /usr/local/bin/lxc-hack-destroy, /usr/local/bin/lxc-hack-chown, /usr/local/bin/clean_crunners.sh" > /etc/sudoers.d/codeland-runner
	chmod 440 /etc/sudoers.d/codeland-runner

	# Unprivileged containers on cgroup v2 need a lingering systemd user
	# session for the runner user.
	loginctl enable-linger "${RUNNER_USER}" || true
}

# ---------------------------------------------------------------------------
# 4. Install OpenResty reverse proxy
# ---------------------------------------------------------------------------
install_openresty() {
	log "Installing OpenResty reverse proxy"
	local src_conf="$(dirname "$0")/host-scripts/nginx.conf"

	# Install OpenResty from the official apt repo.
	apt-get install -y curl gnupg2 ca-certificates lsb-release
	curl -fsSL https://openresty.org/package/pubkey.gpg | gpg --dearmor -o /usr/share/keyrings/openresty.gpg
	echo "deb [signed-by=/usr/share/keyrings/openresty.gpg] http://openresty.org/package/debian $(lsb_release -sc) main" \
		> /etc/apt/sources.list.d/openresty.list
	apt-get update
	apt-get install -y openresty

	# Install the runner proxy config.
	install -m 0644 "${src_conf}" /etc/openresty/nginx.conf

	# Restart OpenResty to pick up the new config.
	systemctl restart openresty
}

# ---------------------------------------------------------------------------
# 5. Build the base runner container
# ---------------------------------------------------------------------------
build_runner_template() {
	log "Building base container '${RUNNER_TEMPLATE}'"
	mkdir -p "${LXC_DIR}"

	if lxc-info -n "${RUNNER_TEMPLATE}" &>/dev/null; then
		warn "Container '${RUNNER_TEMPLATE}' already exists, skipping creation."
		return
	fi

	lxc-create -n "${RUNNER_TEMPLATE}" -t download -- \
		--dist "${RUNNER_DISTRO}" \
		--release "${RUNNER_RELEASE}" \
		--arch "${RUNNER_ARCH}" \
		--force-cache

	# Enable autostart so the template survives reboots.
	echo "lxc.start.auto = 1" >> "${LXC_DIR}/${RUNNER_TEMPLATE}/config"

	log "Starting '${RUNNER_TEMPLATE}' to install language runtimes"
	lxc-start -n "${RUNNER_TEMPLATE}" --daemon

	# Wait for the container to be ready.
	for _ in $(seq 1 30); do
		if lxc-info -n "${RUNNER_TEMPLATE}" | grep -q RUNNING; then
			break
		fi
		sleep 1
	done

	# Install the language runtimes inside the container.
	install_languages_in_container

	lxc-stop -n "${RUNNER_TEMPLATE}"
	log "Base container '${RUNNER_TEMPLATE}' is ready."
}

install_languages_in_container() {
	log "Installing language runtimes inside '${RUNNER_TEMPLATE}'"
	local script_dir="$(dirname "$0")/installers"

	# Concatenate all installer scripts and run them inside the container.
	# Each installer uses `sudo apt`, so ensure sudo is present first.
	lxc-attach -n "${RUNNER_TEMPLATE}" -- bash -c \
		"apt-get update && apt-get install -y sudo"

	for installer in "${script_dir}"/*.sh; do
		log "  Running $(basename "${installer}")"
		lxc-attach -n "${RUNNER_TEMPLATE}" -- bash -s < "${installer}"
	done
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
	require_root
	install_lxc
	create_runner_user
	install_host_scripts
	install_openresty
	build_runner_template

	log "Host setup complete."
	echo
	echo "Next steps:"
	echo "  1. Set MANAGER_PUBKEY and re-run if you skipped SSH key setup."
	echo "  2. Point the manager's conf/ssh.host at this machine."
}

main "$@"
