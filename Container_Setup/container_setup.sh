#!/bin/bash

# so this is what i am trying to do
#
set -e # this helps in early exit if any commmand fails also know as errexit
folder_in_need="$HOME/Container"

echo_color() {
  echo -e "\e[1;32m$1\e[0m"
}

# if ! command -v debootstrap > /dev/null 2>&1; then
# in new version of the bash we can do this  &>/dev/null ( this is same as the >/dev/null 2>&1 (FD[file descriptor's] 0(stdin),1(stdout),2(stderr)))

if [ -d "$folder_in_need/rootfs" ] && [ "$(ls -A "$folder_in_need/rootfs")" ]; then
  echo_color "Found an existing rootfs in the $folder_in_need"
  echo_color "Skipping debootstrap to avoid overwriting"
  echo_color "if you want a fresh setup, please run:"
  echo_color "sudo rm -rf $folder_in_need/"
  echo_color "and Run this script again.. :)"

else
  echo_color "No existing rootfs found. Creating directory structure..."
  mkdir -p "$folder_in_need"
  mkdir -p $folder_in_need/overlay/{lower,upper,work,merged}
  cd "$folder_in_need"

  if ! command -v debootstrap &>/dev/null; then
    echo_color "debootstrap not installed"
    sleep 2s
    echo_color "installing..."
    echo_color "..."

    if command -v dnf &>/dev/null; then
      sudo dnf install debootstrap -y
    elif command -v apt &>/dev/null; then
      sudo apt update && sudo apt install debootstrap -y
    elif command -v pacman &>/dev/null; then
      sudo pacmand -S debootstrap --noconfirm
    else
      echo_color "No compatible package manager found. Please install the required packages manually."
      exit 1
    fi
  fi

  echo "debootstrap is already present :...:"
  echo "installing the rootfs file for this "

  #2 Moost important to have the rootfs where you can play the container as isolation thingg
  echo_color "Building the Debian rootfs with debootstrap (This will take a time, take some coffee)..."
  sudo debootstrap --variant=minbase bookworm "$folder_in_need/rootfs" http://deb.debian.org/debian

  echo_color "Setup complete! Rootfs is in $folder_in_need/rootfs"
  echo_color "Now you can use './container_run.sh' to start the container."

fi
# Please understand what it is all about which i have written in the README file and it is important , (it is not boring)
