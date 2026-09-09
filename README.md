# runner-setup

Setup scripts for CodeLand runners.

## Host setup (fresh Debian 13)

Prepares a host machine to run CodeLand LXC runners: installs LXC, creates the
`virt` user, installs the ephemeral helper scripts, installs the OpenResty
reverse proxy, and builds the `crunner0` base container with all language
runtimes.

```bash
sudo MANAGER_PUBKEY="$(cat ~/.ssh/id_rsa_cl-worker.pub)" bash host-setup.sh
```

The runner host scripts live in `host-scripts/` and are installed by the setup
script:

- `lxc-start-ephemeral` / `lxc-destroy-ephemeral` — create/tear down overlay
  runners (installed to `~/.local/bin`)
- `lxc-start-persistent` / `lxc-stop-persistent` — create/stop persistent
  runners whose writable layer lives on shared NFS
- `lxc-start` / `lxc-copy` / `lxc-attach` — cgroup v2 systemd-run wrappers
- `lxc-mount-hack` / `lxc-mount-persistent` / `lxc-hack-destroy` /
  `lxc-hack-chown` — privileged helpers (installed to `/usr/local/bin`)
- `clean_crunners.sh` — zombie runner cleanup
- `nginx.conf` — OpenResty reverse proxy that routes `port_container` host
  headers to the runner's crunner API

## Persistent runners (NFS)

Persistent runners keep their writable layer on a shared NFS export so they can
move between workers. See [docs/nfs-setup.md](docs/nfs-setup.md) for how to set
up the NFS share. Set `NFS_SERVER` when running `host-setup.sh` to mount it
automatically.

## Language installers

Each `installers/*.sh` installs a single language runtime inside a runner
container. To build a custom installer for a runner:

```bash
cat {java,ruby,typescript,csharp}.sh > ~/installer.sh
```
