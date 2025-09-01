#!/bin/bash
set -euo pipefail

folder_name="$HOME/Container"
container_name="${1:-default}"
cgrp="${2:-}"

container_dir="$folder_name/$container_name"

# Create overlay structure
mkdir -p "$container_dir"/overlay/{lower,upper,work,merged}

echo_color() { echo -e "\e[1;32m$1\e[0m"; }

# Symlink lowerdir to rootfs
if [ ! -L "$container_dir/overlay/lower" ]; then
  echo_color "Creating symlink to rootfs..."
  ln -fs "$folder_name/rootfs" "$container_dir/overlay/lower"
else
  echo_color "Symlink already exists, skipping..."
fi

# Mount overlay
echo_color "Mounting overlayfs..."
sudo mount -t overlay overlay \
  -o "lowerdir=$folder_name/rootfs,upperdir=$container_dir/overlay/upper,workdir=$container_dir/overlay/work" \
  "$container_dir/overlay/merged"

# Copy DNS
echo_color "Copying resolv.conf..."
sudo cp -L /etc/resolv.conf "$container_dir/overlay/merged/etc/resolv.conf" || true

# Create cgroup if requested
if [ -n "$cgrp" ]; then
  echo_color "Creating cgroup..."
  sudo mkdir -p "/sys/fs/cgroup/$cgrp" || true
  echo "500M" | sudo tee "/sys/fs/cgroup/$cgrp/memory.max" >/dev/null
  echo "50000 100000" | sudo tee "/sys/fs/cgroup/$cgrp/cpu.max" >/dev/null
fi

echo_color "Starting container..."
echo_color "Type 'exit' inside container to stop."

if [ -n "$cgrp" ]; then
  echo $$ | sudo tee "/sys/fs/cgroup/$cgrp/cgroup.procs" >/dev/null
fi

# Run container
sudo unshare --mount --uts --ipc --net --pid --fork --propagation private \
  bash -c "
    mount --bind '$container_dir/overlay/merged' '$container_dir/overlay/merged'
    mount --make-private '$container_dir/overlay/merged'

    mkdir -p '$container_dir/overlay/merged/oldrootfs'
    cd '$container_dir/overlay/merged'

    echo 'Entering pivot_root...'
    pivot_root . ./oldrootfs

    cd /

    # cleanup old root
    umount -l /oldrootfs
    rmdir /oldrootfs || true

    mount -t proc proc /proc
    mount -t sysfs sysfs /sys
    mount -t cgroup2 cgroup2 /sys/fs/cgroup || true
    mount -t tmpfs tmpfs /tmp

    exec /bin/bash
  " &
CONTAINER_PID=$!

wait $CONTAINER_PID

echo_color "Cleaning up..."

if [ -n "$cgrp" ]; then
  sudo rmdir "/sys/fs/cgroup/$cgrp" 2>/dev/null || true
fi

sudo umount -l "$container_dir/overlay/merged" 2>/dev/null || true
[ -L "$container_dir/overlay/lower" ] && rm "$container_dir/overlay/lower"
