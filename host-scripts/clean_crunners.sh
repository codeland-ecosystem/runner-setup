#!/bin/bash
#
# CodeLand zombie runner cleanup.
#
# Usage:
#   clean_crunners.sh [prefix]
#
# Deletes all runner containers matching "crunner0-<prefix>*" (excluding the
# base template). Any still-mounted runner is unmounted first so no stale
# mounts are left behind.

set -euo pipefail

directory="${LXC_DIR:-/home/virt/.local/share/lxc}"
exclude_folder="crunner0"
prefix="${1:-}"

if [ ! -d "$directory" ]; then
  echo "Directory $directory does not exist."
  exit 1
fi

cd "$directory" || exit 1

for folder in crunner0-"$prefix"*; do
  if [ "$folder" != "$exclude_folder" ] && [ -d "$folder" ]; then
    echo "Deleting: $folder"

    # Unmount any leftover overlay/tmpfs mounts before removing the dir.
    if mount | grep -q "$directory/$folder/rootfs/"; then
      umount -l -A "$directory/$folder/rootfs/"
    fi
    if mount | grep -q "$directory/$folder/tmpfs"; then
      umount -l "$directory/$folder/tmpfs"
    fi

    rm -rf "$folder"
  fi
done

echo "Deletion completed."
