#!/bin/bash
set -euo pipefail

folder_name="$HOME/Container"
container_name="${1:-default}"
cgrp="${2:-}"
mode="${3:-interactive}"

container_dir="$folder_name/$container_name"

mkdir -p "$container_dir"/overlay/{lower,upper,work,merged}

echo_color() { echo -e "\e[1;32m$1\e[0m"; }

cleanup() {
  echo_color "Cleaning up..."
  if [ -n "$cgrp" ] && [ -d "/sys/fs/cgroup/$cgrp" ]; then
    sudo rmdir "/sys/fs/cgroup/$cgrp" 2>/dev/null || true
  fi

  sudo umount -l "$container_dir/overlay/merged" 2>/dev/null || true
  # Cleaning the symlink
  [ -L "$container_dir/overlay/lower" ] && rm "$container_dir/overlay/lower"

}

trap cleanup EXIT

# Symlink lowerdir to the rootfs
if [ ! -L "$container_dir/overlay/lower" ]; then
  echo_color "Creating symlink to rootfs..."
  ln -fs "$folder_name/rootfs" "$container_dir/overlay/lower"
else
  echo_color "Symlink already exists, skipping..."
fi

echo_color "Mounting overlayfs..."
sudo mount -t overlay overlay \
  -o "lowerdir=$folder_name/rootfs,upperdir=$container_dir/overlay/upper,workdir=$container_dir/overlay/work" \
  "$container_dir/overlay/merged"
# overlayfs  is  the fs the container used to follow , they usually go with lower ,upper , work (CoW), merged . lower doesnt touch , any changes like new file or dirsctory are made in the upper
# that copy and  write in the merged by the merged
# Copy DNS
echo_color "Copying resolv.conf..."
sudo cp -L /etc/resolv.conf "$container_dir/overlay/merged/etc/resolv.conf" || true

# Cgroup , the most important person in this game i would say , there is also somekind of option related to the delegation usage , i dont know what it make
if [ -n "$cgrp" ]; then
  echo_color "Creating cgroup..."
  sudo mkdir -p "/sys/fs/cgroup/$cgrp" || true
  echo "500M" | sudo tee "/sys/fs/cgroup/$cgrp/memory.max" >/dev/null
  echo "50000 100000" | sudo tee "/sys/fs/cgroup/$cgrp/cpu.max" >/dev/null
fi

echo_color "Starting container..."
echo_color "Type 'exit' inside container to stop."

# starting the  container witht namespaces isolation , we make propagation private for this namespaces  ,means any namespaces for this process
# will not propagate to the  other process .
#
if [ "$mode" = "daemon" ]; then

  sudo unshare --mount --uts --ipc --net --pid --fork --propagation private \
    bash -c "
      # Prepare mount
      mount --bind '$container_dir/overlay/merged' '$container_dir/overlay/merged'
      mount --make-private '$container_dir/overlay/merged'

      mkdir -p '$container_dir/overlay/merged/oldrootfs'

      echo 'Entering pivot_root...'
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
      mkdir -p /dev/pts 
      mount -t devpts devpts /dev/pts

      # Bind essential devices from oldroot
      for name in null full random tty urandom zero; do
          mount --bind /oldrootfs/dev/\$name /dev/\$name || true
      done

      # Unmount old root (must be after /proc mount!)
      umount -l /oldrootfs || echo 'umount failed'
      rmdir /oldrootfs 2>/dev/null || true

      # exec command helps in replacing current process with the following
      echo 'Type exit to quit.'
  
      exec /bin/bash
    " &
  # I removed & which was for the running the  command in background
  CONTAINER_PID=$! # immediate capture of the pid of the process

  # Assign correct PID to cgroup, else BOOOM!!!!!!!
  if [ -n "$cgrp" ]; then
    echo $CONTAINER_PID | sudo tee "/sys/fs/cgroup/$cgrp/cgroup.procs" >/dev/null
  fi

  echo_color "Container started in as  the daemon (background process) $CONTAINER_PID"
  echo_color "use 'nsenter -t $CONTAINER_PID -a' to attach"

else
  if [ -n "$cgrp" ] && [ -d "/sys/fs/cgroup/$cgrp" ]; then
    echo $$ | sudo tee "/sys/fs/cgroup/$cgrp/cgroup.procs" >/dev/null
  fi
  sudo unshare --mount --uts --ipc --net --pid --fork --propagation private \
    bash -c "
      # Prepare mount
      mount --bind '$container_dir/overlay/merged' '$container_dir/overlay/merged'
      mount --make-private '$container_dir/overlay/merged'

      mkdir -p '$container_dir/overlay/merged/oldrootfs'

      echo 'Entering pivot_root...'
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
      mkdir -p /dev/pts 
      mount -t devpts devpts /dev/pts 

      # Bind essential devices from oldroot
      for name in null full random tty urandom zero; do
          mount --bind /oldrootfs/dev/\$name /dev/\$name || true
      done

      # Unmount old root (must be after /proc mount!)
      umount -l /oldrootfs || echo 'umount failed'
      rmdir /oldrootfs 2>/dev/null || true

      # exec command helps in replacing current process with the following
      echo 'Type exit to quit.'
      exec /bin/bash
    "

fi
