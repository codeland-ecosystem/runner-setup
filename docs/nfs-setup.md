# NFS Share Setup for Persistent Runners

Persistent runners store their writable layer (`delta0`) on a shared NFS
export so they can move between workers. The NFS server can live anywhere;
this document covers several common setups.

## What the workers need

Each worker mounts the same NFS export at a consistent path, e.g.:

```
/nfs/runners
```

The runner scripts expect the persistent runner's writable layer at:

```
/nfs/runners/<runner-name>/delta0
```

## Option 1: LXC container with a bind mount to a ZFS dataset

This is the author's preferred setup: a small LXC container runs the NFS
server, and its data directory is a bind mount from a ZFS dataset on the host.

### On the ZFS host

```bash
# Create a ZFS dataset for runner data
zfs create -o mountpoint=/tank/runners tank/runners

# Create an LXC container to run NFS (e.g. "nfs-server")
lxc-create -n nfs-server -t download -- --dist debian --release trixie --arch amd64
lxc-start -n nfs-server --daemon

# Bind-mount the ZFS dataset into the container
# (add to the container's config)
echo "lxc.mount.entry = /tank/runners var/lib/nfs-runners none bind 0 0" \
    >> /var/lib/lxc/nfs-server/config
lxc-stop -n nfs-server && lxc-start -n nfs-server --daemon
```

### Inside the NFS container

```bash
apt-get update
apt-get install -y nfs-kernel-server

# Export the bind-mounted dataset
echo "/var/lib/nfs-runners 10.0.0.0/24(rw,sync,no_subtree_check,no_root_squash)" \
    > /etc/exports
exportfs -ra
systemctl enable --now nfs-server
```

> **Note on `no_root_squash`:** The runner's writable layer is owned by the
> `virt` user's mapped subuid (165536). Without `no_root_squash`, root on the
> NFS client is squashed to `nobody`, which breaks ownership. If you prefer to
> keep `root_squash`, you must ensure the `virt` user's uid (165536) maps
> correctly on the NFS server instead.

## Option 2: Dedicated NFS host (bare metal or VM)

```bash
# On the NFS server
apt-get update
apt-get install -y nfs-kernel-server

mkdir -p /srv/runners
echo "/srv/runners 10.0.0.0/24(rw,sync,no_subtree_check,no_root_squash)" \
    > /etc/exports
exportfs -ra
systemctl enable --now nfs-server
```

## Option 3: Existing NAS / storage appliance

Most NAS appliances (TrueNAS, Synology, etc.) support NFS exports. Create an
export for runner data and mount it on each worker. The key requirements are:

- **NFSv3 or NFSv4** (either works)
- **`no_root_squash`** (or correct uid mapping for the `virt` subuid)
- **`rw`** access
- Consistent mount path on all workers (`/nfs/runners`)

## Mounting on each worker

Add to `/etc/fstab` on every worker:

```
# NFS server IP or hostname, path, mount point
10.0.0.50:/srv/runners  /nfs/runners  nfs  defaults,noatime  0  0
```

Then mount it:

```bash
mkdir -p /nfs/runners
mount -a
```

## Verifying the share

```bash
# On a worker, confirm the mount
df -h /nfs/runners

# Confirm the virt user can write (adjust uid to your subuid base)
sudo -u virt touch /nfs/runners/.write-test && rm /nfs/runners/.write-test
```

## Security considerations

- Restrict the export to your worker subnet, not `0.0.0.0/0`.
- `no_root_squash` is required for the subuid ownership to work; understand
  the risk before enabling it on a shared network.
- Consider a dedicated VLAN for runner traffic if workers are untrusted.
