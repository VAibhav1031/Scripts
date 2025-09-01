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

sudo unshare --mount --uts --ipc --net --pid --fork --propagation private \
  bash -c "
    # Prepare mount
    mount --bind '$container_dir/overlay/merged' '$container_dir/overlay/merged'
    mount --make-private '$container_dir/overlay/merged'

    mkdir -p '$container_dir/overlay/merged/oldrootfs'

    echo '>>> Entering pivot_root...'
    pivot_root '$container_dir/overlay/merged' '$container_dir/overlay/merged/oldrootfs' || {
        echo 'pivot_root failed'
        exec bash
    }

    # Now in container root
    cd /

    # Mount pseudo filesystems
    mount -t proc proc /proc
    mount -t sysfs sysfs /sys
    mount -t cgroup2 cgroup2 /sys/fs/cgroup
    mkdir -p /dev/mqueue
    mount -t mqueue mqueue /dev/mqueue

    # Bind essential devices from oldroot
    for name in null full random tty urandom zero; do
        mount --bind /oldrootfs/dev/\$name /dev/\$name || true
    done

    # Unmount old root (must be after /proc mount!)
    umount -l /oldrootfs || echo 'umount failed'
    rmdir /oldrootfs 2>/dev/null || true

    echo '>>> Container ready. Type exit to quit.'
    exec /bin/bash
  " &
CONTAINER_PID=$!

# Assign correct PID to cgroup
if [ -n "$cgrp" ]; then
  echo $CONTAINER_PID | sudo tee "/sys/fs/cgroup/$cgrp/cgroup.procs" >/dev/null
fi

wait $CONTAINER_PID

echo_color "Cleaning up..."

if [ -n "$cgrp" ]; then
  sudo rmdir "/sys/fs/cgroup/$cgrp" 2>/dev/null || true
fi

sudo umount -l "$container_dir/overlay/merged" 2>/dev/null || true
[ -L "$container_dir/overlay/lower" ] && rm "$container_dir/overlay/lower"
