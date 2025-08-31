#!/bin/bash

set -e

folder_name="$HOME/Container"
container_name="${1:-default}"
cgrp="${2:-}"

container_dir="$folder_name/$container_name" # cause inside the Container there will be already rootfs
mkdir -p "$container_dir"/{lower,upper,work,merged}

echo_color() { echo -e "\e[1;32m$1\e[0m"; }

if [ ! -L "$container_dir/overlay/lower" ]; then
  ln -s "$folder_name/rootfs" "$container_dir/overlay/lower"
fi

# 1  Mount the overlay Fs so container can use it and it would be nice for this
echo_color "Mounting the overlaysFs for container : $container_name"
sudo mount -t overlay -o "lowerdir=$folder_name/rootfs/,upperdir=$container_dir/overlay/upper,workdir=$container_dir/overlay/work" \
  overlay "$container_dir"/merged/
echo_color ""

echo_color "Copying resolv.conf..." # from the root /etc/ so it iwill be easy for the connection and all stuff
sudo cp -L /etc/resolv.conf "$folder_name/overlay/merged/etc/resolv.conf" || true

# 3 LETS CREATE THE cgroup for the resource control/limitation
# We have to use this in the container_run.sh because it is (ephemeral) Virtual fs on reboot it will get destroyed, same for all other even in overlaysFs mounting
# it is  bit straight with creation
#
#
# Current problem is more definite i would say we are creating the crgoup but dont know why we are
# giving the

if [ "X$cgrp" != "X"]; then
  echo_color "Creating cgroup..."
  if [ -d /sys/fs/cgroup/ ]; then
    sudo mkdir -p "/sys/fs/cgroup/$cgrp" || true

    # this make a container can only run application under the 200MB only
    echo "500M" | sudo tee "/sys/fs/cgroup/$cgrp/memory.max" >/dev/null || true
    # this make like  the container will only able to use 50% of cpu
    echo "50000 100000" | sudo tee "/sys/fs/cgroup/$cgrp/cpu.max" >/dev/null || true

    # will check in future
    # sudo bash -c "cd '/sys/fs/cgroup/$cgrp'
    # digit_files=$(ls $(cat /sys/kernel/cgroup/delegate) 2>/dev/null)
    # chown '$(id -u):$(id -g)' . $digit_files 2>/dev/null"
  fi
fi

# DELEGATE THE CGROUP TO THE USER INVOKING THIS SCRIPT / For the changing of the ownereship of managing the subheirarchy of the cgroup

#see it is not pure resource isolation like Virtualization do but still it is kindaa , thing separation

# 4 starting container ......druuuuhh...., the problem is most recommend use  "\" for separation bigger command for use but i dont like it
# 4 starting container
echo_color "Starting container..."
# Start unshare in the background and capture its PID ON THE HOST
echo "Type 'exit' to leave and cleanup will run."
sudo unshare --mount --uts --ipc --net --pid --fork --propagation private \
  bash -c"
mount --bind '$container_dir/merged" "$container_dir/merged'
mount --make-private '$container_dir/merged'

mkdir -p '$container_dir/merged/oldrootfs'
cd '$container_dir/merged'
pivot_root '$container_dir/merged' '$container_dir/rootfs/oldrootfs'

cd /
umount -l /oldrootfs
rmdir /oldrootfs

mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t cgroup2 cgroup2 /sys/fs/cgroup
mount -t tmpfs tmpfs /tmp

if [ 'X$cgrp' != 'X' ]; then
  echo \$\$ > '/sys/fs/$cgrp/cgroup.procs'

#starting the shell , [exec replaces the current process with following ..]
exec /bin/bash
" &

CONTAINER_PID=$! # This is the host PID of the unshare process
wait $CONTAINER_PID

# sleep 1          # Give it a second to startecho_color "Cleaning up , Please wait...."
#
# echo_color "Found host PID of container: $CONTAINER_PID"
#
# #5 adding the PID to the cgroup
# echo_color "Adding container PID $CONTAINER_PID to the cgroup.procs for management"
# if [ -d /sys/fs/cgroup/mycontainer ]; then
#   echo "$CONTAINER_PID" | sudo tee /sys/fs/cgroup/mycontainer/cgroup.procs >/dev/null || true
# fi

echo_color "Cleaning up..."

if [ "X$cgrp" != "X" ]; then
  sudo rmdir "/sys/fs/cgroup/$cgrp" 2>/dev/null || true
fi

sudo umount -l "$container_dir/merged" 2>/dev/null || true

#for safe other cleanups like unsahre process and
# yeah i think if i umount the root fs container_dir/merged then why to umount other stuff
#bash Scripts/Container_Setup/container_kill.sh
