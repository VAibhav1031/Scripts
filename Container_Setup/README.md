# Hey this is all about how to make container in the Linux without docker (Bare-Bone)


- Must know what is the Virtualization, Virtual Machine , why did they used and how they work
- contianer is just like another process running with some extra around it running along  making it special , and making the process running inside the container feel isolated  even thought isolataion of resources (mostly thin) .
  container process  run on `OverLayFs` ,use `namespace` isolation (uts,ipc, net, pid, and cgroup) , Different `rootfs` is being used to make your main root directory clean rather cluttering with the containers package  bianries ,
  Containers syscall are pretty much differently treated for extra protection  even though there are  `rootless`  way is also there
  Cgroup is there for resource capping usage for example if we want that this container cant use more than 20% of total CPU  or Memory and simlar config in the I/O also.  Cgroup help in the management of that
  And at last in this container intro i can say  they run on same host Kernel not any other kernel is being used 
- Pivot Root , Chroot would be also helpful to know which heelp in using the rootfs and all thing , and how `pivot_root` it more efficiently ..
- Docker and OCI made it more general , with fix specification  , else it was pain for sysadmin's to create all stuff and maintain 
- What container concept is just running application in isolated environment at very low thin separation between resource , like process , network, hostname , memory , cpu and other things. 
  Container make application believe like it is running in separate environment and there is only one process running which is that container only (which isnt True).This help company to run more than one
  application with using container on the machine(even VM) without  compromising on the resource and other stuff 

### Refrence's :
  - [Liz Rice's Container From Scratch](https://youtu.be/8fi7uSYlOdc?si=p4kyfz_VIS1fOKTQ)                   
  - [Build Your Container Runtime](https://youtu.be/JOsWB50LmwQ?si=AFhh3iPInvKwHzMJ)
  - [Detailed Contianer in Linux Explaination by Micheal Kerrisk](https://youtu.be/4RUiVAlJE2w?si=3sYVOE5v_-dPN7j6)
--- 
## Simple Usage : 

- just git clone the repo 

``` bash
sudo chmod +x container_setup.sh container_run.sh container_kill.sh
```

- For Fresh start 
```bash
./container_setup.sh
```

- for everytime to create new container 

```bash
./container_run.sh 'container_name' 'cgroup_directory' 
```

- For killing/Removing container

```bash
./container_kill.sh
```
  NOTE:
  > Daemon part is under development , plus for that i am thinking to add some kind of custom init process which  can reap the zombie processes...
 
---
IF YOU CAN HAVE ANY IDEA OR ANY RESOURCE YOU CAN RAISE PR OR A ISSUE   
*REMEMBER THIS IS STILL IN LEARNING PHASE SETUP (USE IN VM) , THERE A LOT TO GO*
