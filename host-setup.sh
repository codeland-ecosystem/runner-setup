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

# Shared NFS export for persistent runners. Set NFS_SERVER to enable (or set
# RUN_NFS_SERVER=1 to make THIS host the NFS server).
NFS_DIR="${NFS_DIR:-/nfs/runners}"
NFS_SERVER="${NFS_SERVER:-}"
NFS_PATH="${NFS_PATH:-/srv/runners}"
RUN_NFS_SERVER="${RUN_NFS_SERVER:-0}"
# Subnet to export the NFS share to (used when RUN_NFS_SERVER=1).
NFS_EXPORT_SUBNET="${NFS_EXPORT_SUBNET:-192.168.1.0/24}"

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

	# Set up subuid/subgid ranges for unprivileged containers. The runner
	# scripts map container uid 0 -> host uid 165536, so give the runner user
	# that range. Only add if not already configured.
	if ! grep -qE "^${RUNNER_USER}:" /etc/subuid; then
		echo "${RUNNER_USER}:165536:65536" >> /etc/subuid
		echo "${RUNNER_USER}:165536:65536" >> /etc/subgid
	fi

	# Create an LXC default config for the runner user so unprivileged
	# lxc-create works (it otherwise fails without uid mappings).
	local lxc_conf_dir="/home/${RUNNER_USER}/.config/lxc"
	mkdir -p "${lxc_conf_dir}"
	cat > "${lxc_conf_dir}/default.conf" <<EOF
lxc.include = /etc/lxc/default.conf
lxc.idmap = u 0 165536 65536
lxc.idmap = g 0 165536 65536
lxc.net.0.type = veth
lxc.net.0.link = lxcbr0
# Unprivileged users cannot create AppArmor namespaces; disable it.
lxc.apparmor.profile = unconfined
EOF
	chown -R "${RUNNER_USER}:${RUNNER_USER}" "/home/${RUNNER_USER}/.config"

	# The mapped container-root uid (165536) must traverse the runner's home
	# to reach the container dirs. Grant x via ACL (needs the acl package).
	apt-get install -y acl
	setfacl -m u:165536:x "/home/${RUNNER_USER}" || warn "Could not set home ACL for container root."

	# Unprivileged users need /etc/lxc/lxc-usernet to attach veth interfaces
	# to the bridge.
	if [[ ! -f /etc/lxc/lxc-usernet ]]; then
		cat > /etc/lxc/lxc-usernet <<EOF
# ${RUNNER_USER}: allow up to 10 veth/vlan/macvlan interfaces on lxcbr0
${RUNNER_USER} veth lxcbr0 10
${RUNNER_USER} vlan lxcbr0 10
${RUNNER_USER} macvlan lxcbr0 10
EOF
	fi

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

	# The manager connects as the runner user and invokes the ephemeral
	# helpers from that user's ~/.local/bin (over SSH, non-login shell). So
	# install them there, not in root's home.
	local run_bin="/home/${RUNNER_USER}/.local/bin"
	mkdir -p "${run_bin}"
	install -m 0755 "${src_dir}/lxc-start-ephemeral" "${run_bin}/lxc-start-ephemeral"
	install -m 0755 "${src_dir}/lxc-destroy-ephemeral" "${run_bin}/lxc-destroy-ephemeral"
	install -m 0755 "${src_dir}/lxc-start" "${run_bin}/lxc-start"
	install -m 0755 "${src_dir}/lxc-copy" "${run_bin}/lxc-copy"
	install -m 0755 "${src_dir}/lxc-attach" "${run_bin}/lxc-attach"
	install -m 0755 "${src_dir}/lxc-start-persistent" "${run_bin}/lxc-start-persistent"
	install -m 0755 "${src_dir}/lxc-stop-persistent" "${run_bin}/lxc-stop-persistent"
	chown -R "${RUNNER_USER}:${RUNNER_USER}" "${run_bin}"

	# The privileged helpers live in /usr/local/bin (they use sudo).
	install -m 0755 "${src_dir}/lxc-mount-hack" /usr/local/bin/lxc-mount-hack
	install -m 0755 "${src_dir}/lxc-mount-persistent" /usr/local/bin/lxc-mount-persistent
	install -m 0755 "${src_dir}/lxc-hack-destroy" /usr/local/bin/lxc-hack-destroy
	install -m 0755 "${src_dir}/lxc-hack-chown" /usr/local/bin/lxc-hack-chown
	install -m 0755 "${src_dir}/clean_crunners.sh" /usr/local/bin/clean_crunners.sh

	# Allow the runner user to run the privileged helpers without a password.
	apt-get install -y sudo
	mkdir -p /etc/sudoers.d
	echo "${RUNNER_USER} ALL=(ALL) NOPASSWD: /usr/local/bin/lxc-mount-hack, /usr/local/bin/lxc-mount-persistent, /usr/local/bin/lxc-hack-destroy, /usr/local/bin/lxc-hack-chown, /usr/local/bin/clean_crunners.sh, /usr/bin/mount, /usr/bin/umount, /bin/mount, /bin/umount" > /etc/sudoers.d/codeland-runner
	chmod 440 /etc/sudoers.d/codeland-runner

	# Unprivileged containers on cgroup v2 need a lingering systemd user
	# session for the runner user.
	loginctl enable-linger "${RUNNER_USER}" || true
}

# ---------------------------------------------------------------------------
# 4. Run the NFS server on THIS host (optional)
# ---------------------------------------------------------------------------
run_nfs_server() {
	if [[ "${RUN_NFS_SERVER}" != "1" ]]; then
		return
	fi

	log "Configuring THIS host as the NFS server for persistent runners"
	apt-get install -y nfs-kernel-server

	mkdir -p "${NFS_PATH}"
	chown -R "${RUNNER_USER}:${RUNNER_USER}" "${NFS_PATH}"

	# Export the share. no_root_squash is required so the runner's mapped
	# subuid ownership (165536) survives over NFS.
	if [[ -f /etc/exports ]] && ! grep -q "${NFS_PATH}" /etc/exports; then
		echo "${NFS_PATH} ${NFS_EXPORT_SUBNET}(rw,sync,no_subtree_check,no_root_squash)" >> /etc/exports
		exportfs -ra
	fi

	systemctl enable --now nfs-server

	# Point the local worker at the share it just exported.
	NFS_SERVER="${NFS_SERVER:-$(hostname -I | awk '{print $1}')}"
}

# ---------------------------------------------------------------------------
# 4. Mount the shared NFS export for persistent runners
# ---------------------------------------------------------------------------
mount_nfs() {
	log "Mounting shared NFS export for persistent runners"
	mkdir -p "${NFS_DIR}"

	if [[ -z "${NFS_SERVER}" ]]; then
		warn "NFS_SERVER not set; skipping NFS mount. Persistent runners will not work until it is mounted."
		return
	fi

	local nfs_path="${NFS_PATH:-/srv/runners}"

	# Mount if not already mounted.
	if ! mountpoint -q "${NFS_DIR}"; then
		mount -t nfs "${NFS_SERVER}:${nfs_path}" "${NFS_DIR}"
	fi

	# Persist across reboots.
	if ! grep -q "${NFS_DIR}" /etc/fstab; then
		echo "${NFS_SERVER}:${nfs_path}  ${NFS_DIR}  nfs  defaults,noatime  0  0" >> /etc/fstab
	fi
}

# ---------------------------------------------------------------------------
# 4. Install OpenResty reverse proxy
# ---------------------------------------------------------------------------
install_openresty() {
	log "Installing OpenResty reverse proxy"
	local src_conf="$(dirname "$0")/host-scripts/nginx.conf"

	# Install OpenResty from the official apt repo.
	apt-get install -y curl gnupg2 ca-certificates lsb-release

	# OpenResty only publishes Debian repos up to bookworm. On newer releases
	# (e.g. trixie) fall back to bookworm; the package installs fine.
	# Note: OpenResty's signing key still uses SHA1, which Debian 13 apt
	# rejects, so we mark the repo as [trusted=yes]. It is fetched over plain
	# http, so pin this to an internal/trusted network only.
	local dist="$(lsb_release -sc)"
	if [[ "${dist}" != "bookworm" && "${dist}" != "bullseye" && "${dist}" != "buster" ]]; then
		warn "OpenResty has no ${dist} repo; using bookworm instead."
		dist="bookworm"
	fi

	echo "deb [trusted=yes] http://openresty.org/package/debian ${dist} openresty" \
		> /etc/apt/sources.list.d/openresty.list
	apt-get update
	apt-get install -y openresty

	# Install the runner proxy config.
	install -m 0644 "${src_conf}" /etc/openresty/nginx.conf

	# The proxy config writes to these log paths; ensure they exist.
	mkdir -p /var/log/nginx /usr/local/openresty/nginx/logs

	# Restart OpenResty to pick up the new config.
	systemctl restart openresty
}

# ---------------------------------------------------------------------------
# 5. Build the base runner container
# ---------------------------------------------------------------------------
# Run a command as the runner user with a working systemd user session, so
# unprivileged LXC operations work on a cgroup v2 host.
as_runner() {
	sudo -u "${RUNNER_USER}" \
		XDG_RUNTIME_DIR="/run/user/$(id -u "${RUNNER_USER}")" \
		DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u "${RUNNER_USER}")/bus" \
		"$@"
}

build_runner_template() {
	log "Building base container '${RUNNER_TEMPLATE}' as user '${RUNNER_USER}'"
	local lxc_dir="/home/${RUNNER_USER}/.local/share/lxc"
	mkdir -p "${lxc_dir}"
	chown -R "${RUNNER_USER}:${RUNNER_USER}" "${lxc_dir}"

	if as_runner lxc-info -n "${RUNNER_TEMPLATE}" &>/dev/null; then
		warn "Container '${RUNNER_TEMPLATE}' already exists, skipping creation."
		return
	fi

	as_runner lxc-create -n "${RUNNER_TEMPLATE}" -t download -- \
		--dist "${RUNNER_DISTRO}" \
		--release "${RUNNER_RELEASE}" \
		--arch "${RUNNER_ARCH}" \
		--force-cache

	# Enable autostart so the template survives reboots.
	echo "lxc.start.auto = 1" >> "${lxc_dir}/${RUNNER_TEMPLATE}/config"

	log "Starting '${RUNNER_TEMPLATE}' to install language runtimes"
	as_runner lxc-start -n "${RUNNER_TEMPLATE}" --daemon

	# Wait for the container to be ready.
	for _ in $(seq 1 30); do
		if as_runner lxc-info -n "${RUNNER_TEMPLATE}" | grep -q RUNNING; then
			break
		fi
		sleep 1
	done

	# Install the language runtimes inside the container.
	install_languages_in_container

	as_runner lxc-stop -n "${RUNNER_TEMPLATE}"
	log "Base container '${RUNNER_TEMPLATE}' is ready."
}

install_languages_in_container() {
	log "Installing language runtimes inside '${RUNNER_TEMPLATE}'"
	local script_dir="$(dirname "$0")/installers"

	# Each installer uses `sudo apt`, so ensure sudo is present first.
	as_runner lxc-attach -n "${RUNNER_TEMPLATE}" -- bash -c \
		"apt-get update && apt-get install -y sudo"

	local failed=0
	for installer in "${script_dir}"/*.sh; do
		log "  Running $(basename "${installer}")"
		# Run each installer independently so one failure does not abort the
		# whole base-container build (e.g. an interpreter not packaged on
		# this distro).
		if ! as_runner lxc-attach -n "${RUNNER_TEMPLATE}" -- bash -s < "${installer}"; then
			warn "  $(basename "${installer}") failed; continuing."
			failed=$((failed+1))
		fi
	done

	if [[ "${failed}" -gt 0 ]]; then
		warn "${failed} installer(s) failed. The base container may be missing some runtimes."
	fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
	require_root
	install_lxc
	create_runner_user
	install_host_scripts
	run_nfs_server
	mount_nfs
	install_openresty
	build_runner_template

	log "Host setup complete."
	echo
	echo "Next steps:"
	echo "  1. Set MANAGER_PUBKEY and re-run if you skipped SSH key setup."
	echo "  2. Point the manager's conf/ssh.host at this machine."
}

main "$@"
