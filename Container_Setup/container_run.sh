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
# 4 starting container
echo "Starting container (this will be namespace-isolated)..."
# Start unshare in the background and capture its PID ON THE HOST
sudo unshare --mount --uts --ipc --net --pid --fork \
  bash -c "
    # First, mount the host's resources into the container's future root
    mount --rbind /sys '$folder_name/overlay/merged/sys'
    mount --rbind /dev '$folder_name/overlay/merged/dev'
    mount --rbind /run '$folder_name/overlay/merged/run'

    # NOW, change root into the container
    chroot '$folder_name/overlay/merged' /bin/bash -c '
        # This command runs INSIDE the chroot AND the PID namespace
        # Now mount a new procfs for this PID namespace
        mount -t proc proc /proc
        # Now run sleep as PID 1
        exec sleep infinity
    '
  " &
CONTAINER_PID=$! # This is the host PID of the unshare process
sleep 1          # Give it a second to startecho_color "Cleaning up , Please wait...."

echo_color "Found host PID of container: $CONTAINER_PID"

#5 adding the PID to the cgroup
echo_color "Adding container PID $CONTAINER_PID to the cgroup.procs for management"
if [ -d /sys/fs/cgroup/mycontainer ]; then
  echo "$CONTAINER_PID" | sudo tee /sys/fs/cgroup/mycontainer/cgroup.procs >/dev/null || true
fi

echo "Entering container shell (nsenter). Type 'exit' to leave and cleanup will run."
# Now we use the HOST PID to enter the namespaces
sudo nsenter --target "$CONTAINER_PID" --all --wd="$folder_name/overlay/merged" /bin/bash
bash Scripts/Container_Setup/container_kill.sh
