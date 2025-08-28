#!/bin/bash

set -e

folder_name="$HOME/Container"

echo_color() { echo -e "\e[1;32m$1\e[0m"; }

# 1  Mount the overlay Fs so container can use it and it would be nice for this
echo_color "Mounting the overlaysFs (union filesystem) it has lower , upper ,work ,merged, lower will be same rootfs"
sudo mount -t overlay overlay -o lowerdir=~/"$folder_name"/rootfs/, \
  upperdir=~/"$folder_name"/overlay/upper, \
  workdir=~/"$folder_name"/overlay/work \
  ~/"$folder_name"/overlay/merged/

echo_color "\n"

echo_color "copying resolv.conf..." # from the root /etc/ so it iwill be easy for the connection and all stuff
sudo cp -r /etc/resolv.conf "$folder_in_need/overlay/merged/etc/resolv.conf"

# 2 Mounting Virtual filesystem , it is just for sake the rootfs can use some command esaily , but when the container is initialized most of it is not used caus we run separate process
# and other namespace
echo_color "Mounting the necessary filesystem"
mount -t proc /proc "$folder_name"/overlay/merged/proc
mount --rbind /sys "$folder_name"/overlay/merged/sys
mount --rbind /run "$folder_name"/overlay/merged/run
mount --rbind /dev "$folder_name"/overlay/merged/dev

# 3 LETS CREATE THE cgroup for the resource control/limitation
# We have to use this in the container_run.sh because it is (ephemeral) Virtual fs on reboot it will get destroyed, same for all other even in overlaysFs mounting
mkdir /sys/fs/cgroup/mycontainer/
# this make a container can only run application under the 200MB only
echo 200M | sudo tee /sys/fs/cgroup/mycontainer/memory.max
# this make like  the container will only able to use 50% of cpu
echo 50000 | sudo tee /sys/fs/cgroup/mycontainer/cpu.max

#see it is not pure resource isolation like Virtualization do but still it is kindaa , thing separation

# 4 starting container ......druuuuhh...., the problem is most recommend use  "\" for separation bigger command for use but i dont like it
sudo unshare --mount --uts --ipc --net --fork --pid \
  --mount-proc=$HOME/"$folder_name/overlay/merged/proc" \
  chroot ~/"$folder_name/overlay/merged"sleep infinity &
CONTAINER_PID=$!

#5 adding the PID to the
echo_color "Adding container PID $CONTAINER_PID to the cgroup.procs for management"
echo $CONTAINER_PID | sudo tee /sys/fs/cgroup/mycontainer/cgroup.procs >dev/null
# basically sys provide details about the device and hardware which is running from everything like driver and all stuff , where proc is something
# like live running processes with the commands also running alongside , without this there is bad communication betwween things
#

#6 Enter CONTAINER
echo_color "Entering Container "
sudo nsenter --target $CONTAINER_PID -all /bin/bash

#
echo_color "Cleaning up , Please wait...."
container_kill.sh
