---
title: Ceph 
---
##Local vs distributed storage
Local NVMe offers the lowest latency and highest throughput. The issue is that the available space is limited to a single chassis.  
Ceph distributed software defined storage takes a different approach. It pools block devices across storage nodes into a distributed object store, presenting a unified storage pool to hypervisors. The tradeoff is increased latency.

##Ceph storage Minimum Equipment List
You cannot run a production system without hardware. Below you will find Non-negotiable MEL. Avoid RAID, LUN and consumer grade SSD'd.  

* Three controller nodes with dual Ethernet interfaces  
* Three storage nodes with dual Ethernet interfaces  
* Two VLAN-capable MC-LAG switches  

##Placement
Ceph fault tolerance depends on its disk's physical location. It is essential to figure out what fault tolerance assumptions are. Then, you can decide what you can lose (datacenter, rack, host, disk). It has to be a conscious decision.  

##Replicated vs. erasure encoded
Replicated is what the name says: "Replicated X times." Generally, 3x is fine. Erasure encoding is an entirely different setup. On its basic level, a decision is needed on how many coding junks and data junks are required.  
Let's use **K** data junks and **M** coding junks. You need to use one coding junk for two data junks to set up a minimal supported EC pool. In literature, it is called the "k=2 m=1" schema.  

##Fault tolerance
Let's take a trivial example. Cloud storage is 3x replicated. Losing one disk is not a significant event. Losing two disks prioritizes maximum recovery IOPS. Losing three disks means downtime and restoring from backup.

##Block vs. file vs. object
Under the hood, it's an object storage. However, the translation layer allows it to present as a block, file or object. For OpenStack VM, it's a block device. For the journal log collector, it is a file. For S3 and Swift, it is an object.

