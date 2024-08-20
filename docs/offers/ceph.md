---
title: Ceph 
---
##Shared vs. local storage
Local NVME storage is fast and finite in size.  
Shared storage allows moderate speedy space aggregation from all storage nodes, with the cost of events in one shared storage node, affecting the entire cluster. However, with shared storage, you can migrate VM online from one hypervisor to another.  

##Placement
Ceph fault tolerance depends on its disk's physical location. It is essential to figure out what fault tolerance assumptions are. Then, you can decide what you can lose (datacenter, rack, host, disk). It has to be a conscious decision.  

##Replicated vs. erasure encoded
Replicated is what the name says: "Replicated X times." Generally, 3x is fine. Erasure encoding is an entirely different setup. On its basic level, a decision is needed on how many coding junks and data junks are required.  
Let's use **K** data junks and **M** coding junks. You need to use one coding junk for two data junks to set up a minimal supported EC pool. In literature, it is called the "k=2 m=1" schema.  

##Fault tolerance
Let's take a trivial example. Cloud storage is 3x replicated. Losing one disk is not a significant event. Losing two disks prioritizes maximum recovery IOPS. Losing three disks means downtime and restoring from backup.

##Block vs. file vs. object
Under the hood, it's an object storage. However, the translation layer allows it to present as a block, file or object. For OpenStack VM, it's a block device. For the journal log collector, it is a file. For S3 and Swift, it is an object.

