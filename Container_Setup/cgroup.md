#  Crgoup's

- One of the most important topics in the linux, Containers why? because of this containers are able to run  in the separation/isolation it needs 

- **Cgroup** (contoll group) is the feature provided by the linux kernel to control the processes from  memory , i/o, network to the cpu and etc 
    you can limit/ or put the restriction to the process .  
    or kernel feature to organize processes into groups and apply resource controls to them.
    Each group can have rules like:

- CPU: “this group can only use 20% of a CPU”
- Memory: “this group gets 512 MB RAM, if exceeded → OOM kill inside group”
    IO: “this group’s disk writes limited to 10 MB/s”
    PIDs: “this group can spawn max 100 processes”
    Think of them as a per-process resource firewall.


- Cgroups helps in creation of those thin line separation of containers frmo host machine 
- Crgoups are there of  v1 and v2 ,so v1 is old  and v2 is new and better

---
## Crgoup V1

So in this you may see (if you have older system) , *ls /sys/fs/cgroup* , this command will list the all controllers(subsystem ealier used to say)

like this 

```
/sys/fs/cgroup
├── blkio
├── cpu
├── cpuacct
├── cpu,cpuacct
├── cpuset
├── devices
├── freezer
├── hugetlb
├── memory
├── net_cls
├── net_prio
├── net_cls,net_prio
├── perf_event
├── pids
└── systemd
```

here you are seeing all controller's in the cgroup, these are also filesystem on their own (idk why they were ), so to make any process control 
you have to make the  folder in one of these controller and  there is heirarchy system (the reason v1  was bad)

🏗️ In v1 — Hierarchies & Controllers

Each controller (CPU, memory, blkio, devices, etc.) is like a plugin that applies some resource policy.

A hierarchy is a tree of cgroups (directories).

Example:
```
/sys/fs/cgroup/cpu/        (hierarchy for cpu controller)
/sys/fs/cgroup/memory/     (hierarchy for memory controller)
/sys/fs/cgroup/blkio/      (hierarchy for block I/O controller)
```

```
/sys/fs/cgroup/cpu/teamA/
/sys/fs/cgroup/cpu/teamB/

/sys/fs/cgroup/memory/teamA/
/sys/fs/cgroup/memory/teamB/

```
So:
cpu has its own hierarchy tree (teamA, teamB)
memory has its own, separate hierarchy tree (teamA, teamB)
They look similar, but they are completely independent.


## What does “hierarchical” mean here?
Parent → Child relationship
If you limit a parent cgroup, children inherit constraints.
Example: if /sys/fs/cgroup/memory/teamA/ has memory.limit_in_bytes=500M, then teamA/web/ inside it can’t exceed 500M total (it must split that quota).
One process = many hierarchies
A process can belong to different cgroups across different hierarchies.
Example:
```
PID 1234 is in:
  /sys/fs/cgroup/cpu/teamA/
  /sys/fs/cgroup/memory/teamB/
  /sys/fs/cgroup/blkio/teamA/
```
So CPU rules come from one tree, memory rules from another, blkio from yet another.

## Why this was messy in v1
The kernel had to track multiple trees per process → hard to reason about.
So Docker, systemd, etc. had to do a lot of bookkeeping to make sure processes ended up in the “right” cgroups across controllers.


# Cgroup V2

/sys/fs/cgroup/mycontainer/
   cpu.max
   memory.max
   pids.max
   io.max
   ...
   cgroup.procs
   cgroup.controllers
   
There’s one unified hierarchy:
You create /sys/fs/cgroup/mycontainer.
Inside, all controllers (CPU, memory, pids, io, etc.) are available.
You just write rules in the same directory (e.g., memory.max, cpu.max) and drop PIDs into cgroup.procs.
A process can belong to only one place in the tree, so all controllers apply consistently.




##  Difference from namespaces
Namespaces = who you can see (process isolation, network isolation).
cgroups = how much you can use (resource quotas, limits, priorities).

**So in the analogy:**
Namespaces = blinders on a horse (it only sees its world).
cgroups = reins + feeding rules (how far it can go and how much hay it eats).


**Without cgroups -> your container could hog all CPU, memory, or spawn unlimited processes and crash the host.**
