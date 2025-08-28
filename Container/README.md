# Hey this is all about how to make container in the Linux without docker (Bare-Bone)


- Must know what is the Virtualization, Virtual Machine , why did they used and how they work (if you  dont know go to this link  )
- container is just like running a process in a isolation of resource (mostly) there is very thin layer separation (for resource's), but yeah with a lot of spec(mainly namespaces like uts, ipc, net, pid, and cgroup)
- it is the same process docker applied , with many extra think including , easy handling ,but on early days docker use linux way to create the container 
- but make it more generalize for mass dev , with documentation to use it , else it was pain for sysadmin to create all stuff and maintain 
- What container concept is just running application in isolated environment at very low thin separation between resource , like process , network, hostname , memory , cpu and other things. 
- container make application believe like it is running in separate environment and there is only one process running which is that container only (which isnt True)
- This help company to run more than one application with using container on the machine(even VM) without  compromising on the resource and other stuff 
- more details will be there ... 

--- 
## Simple Usage : 

just git clone the repo 

``` bash
chmod +x container_setup.sh container_run.sh container_kill.sh
```

- For Fresh start 
```bash
./ container_setup.sh
```

- for everytime to create new container 

```bash
./container_run.sh
```

- For killing/Removing container

```bash
./container_kill.sh
```

---
*REMEMBER THIS IS STILL IN LEARNING PHASE SETUP , THERE A LOT TO GO*
