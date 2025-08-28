#!/bin/bash 
set -e 

folder="$HOME/Container/"

each_color() {
  echo -e "\e[1;32m$1\e[0m";
}

# searching the pid (means process id dummmb) through various i know and i get to know from my friend joker 
CONTAINER_PID = $(ps aux | grep "sleep infinity" | grep "unshare" | awk {'print $2'} |  head -n 1)


if [ -n "$CONTAINER_PID" ]; then 
  each_color "Killing the container process $CONTAINER_PID  :.."
  sudo kill -9 "$CONTAINER_PID"

else
  each_color "There is no container process found"

# umount everything i used 
sudo umount -l  "$folder"/overlay/merged/sys 2>dev/null || true  
sudo umount -l "$folder"/overlay/merged/dev 2>dev/null || true  
sudo umount -l "$folder"/overlay/merged/proc 2>dev/null || true  
sudo umount -l "$folder"/overlay/merged/run 2>dev/null || true  
sudo umount -l "$folder"/overlay/merged 2>dev/null || true    


each_color "Container stopped :)...)"
