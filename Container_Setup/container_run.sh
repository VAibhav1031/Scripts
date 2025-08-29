#!/bin/bash

set -e

folder_name="$HOME/Container"

echo_color() { echo -e "\e[1;32m$1\e[0m"; }

echo "Preparing overlay dirs..."
mkdir -p "$folder_name/overlay"/{lower,upper,work,merged}
# populate lower if empty
if [ -z "$(ls -A "$folder_name/overlay/lower" 2>/dev/null)" ]; then
  echo "Copying rootfs into lower (this may take a while)..."
  sudo cp -a "$folder_name/rootfs/." "$folder_name/overlay/lower/"
fi

# 1  Mount the overlay Fs so container can use it and it would be nice for this
echo_color "Mounting the overlaysFs (union filesystem) it has lower , upper ,work ,merged, lower will be same rootfs"
sudo mount -t overlay overlay -o "lowerdir=$folder_name/rootfs/,upperdir=$folder_name/overlay/upper,workdir=$folder_name/overlay/work" \
  "$folder_name"/overlay/merged/
echo_color ""

echo_color "Copying resolv.conf..." # from the root /etc/ so it iwill be easy for the connection and all stuff
sudo cp -L /etc/resolv.conf "$folder_name/overlay/merged/etc/resolv.conf" || true

# 3 LETS CREATE THE cgroup for the resource control/limitation
# We have to use this in the container_run.sh because it is (ephemeral) Virtual fs on reboot it will get destroyed, same for all other even in overlaysFs mounting
echo_color "Creating cgroup..."
if [ -d /sys/fs/cgroup/ ]; then
  sudo mkdir -p /sys/fs/cgroup/mycontainer/ || true
  # this make a container can only run application under the 200MB only
  echo "200M" | sudo tee /sys/fs/cgroup/mycontainer/memory.max >/dev/null || true
  # this make like  the container will only able to use 50% of cpu
  echo "50000" | sudo tee /sys/fs/cgroup/mycontainer/cpu.max >/dev/null || true
fi

#see it is not pure resource isolation like Virtualization do but still it is kindaa , thing separation

# 4 starting container ......druuuuhh...., the problem is most recommend use  "\" for separation bigger command for use but i dont like it
echo "Starting container (this will be namespace-isolated)..."
sudo unshare --mount --uts --ipc --net --pid --fork \
  bash -c "
    set -euo pipefail

    # make mounts private inside the new mount namespace
    mount --make-rprivate /

    # bind mounts (done inside new mount namespace so they are local to it)
    mount --rbind /sys '$folder_name/overlay/merged/sys'
    mount --rbind /dev '$folder_name/overlay/merged/dev'
    mount --rbind /run '$folder_name/overlay/merged/run'

    # mount proc inside the NEW PID namespace at the container's /proc
    mount -t proc proc '$folder_name/overlay/merged/proc'

    # chroot and run sleep as PID 1
    chroot '$folder_name/overlay/merged' /bin/bash -c \"exec sleep infinity\" &
    sleep_pid=\$!
    # print PID to stdout so caller can see it (optional)
    echo \$sleep_pid > /tmp/mini_container_pid
    # keep this helper waiting so unshare child stays alive (the sleep is PID 1 inside chroot)
    wait \$sleep_pid
  " &

# Give the background process a moment to start and write the PID file
sleep 1

# Try to get the sleep PID written by the helper
if [ -f /tmp/mini_container_pid ]; then
  CONTAINER_PID=$(cat /tmp/mini_container_pid)
  sudo rm -f /tmp/mini_container_pid
  echo_color "Found container PID: $CONTAINER_PID"
else
  # fallback: find the sleep process in the system (more fragile)
  echo_color "Could not find PID file, trying fallback method..."
  CONTAINER_PID=$(pgrep -f "sleep infinity" | head -n 1 || true)
  if [ -z "$CONTAINER_PID" ]; then
    echo_color "ERROR: Could not find the container process. It may have failed to start."
    exit 1
  fi
fi

#5 adding the PID to the
echo_color "Adding container PID $CONTAINER_PID to the cgroup.procs for management"
# attach that PID to cgroup (best-effort)
if [ -d /sys/fs/cgroup/mycontainer ]; then
  echo "$CONTAINER_PID" | sudo tee /sys/fs/cgroup/mycontainer/cgroup.procs >/dev/null || true
fi

echo "Entering container shell (nsenter). Type 'exit' to leave and cleanup will run."
# Open an interactive shell inside all namespaces of the container process
# Use the container's root as the working directory
sudo nsenter --target "$CONTAINER_PID" --all --wd="$folder_name/overlay/merged" /bin/bash#
echo_color "Cleaning up , Please wait...."
bash Scripts/Container_Setup/container_kill.sh
