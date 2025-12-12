---
title: OpenStack 
---
## Benefits of owning an on-prem cloud infrastructure
It's entirely under your control. The entire hardware and software lifecycle depends on your decisions.
OpenStack itself, is set of services: compute, network, storage and controller plane (databases, proxies, identity, caching, UI, MQ).

## Basic on-prem OpenStack cloud bundle
* Server room with adequate power and cooling  
* Network stack  
* Compute, storage and controller nodes  
* OpenStack software installation  
* Plans for upgrade and disaster recovery  

## Fault tolerance
From our point of view, a single piece of hardware is more resilient than a stack of rust. The same applies to software instances. But if it fails, then it's difficult or impossible to recover. On reasonable-sized OpenStack installation, something is always in a failed state or under maintenance. However, you need to know how fault-tolerant your installation is.  

Let's look at two trivial examples. In the first example, the controller plane database is a 3x replica. Losing one replica is not a significant event. However, the split-brain condition can occur like any other quorum-based system. In the second example, the networking interface or switch malfunctions. Losing one network path won't affect installation. However, things would be sad if the design decision was to run a hyper-converged cloud infrastructure on a single interface.

## Timetable
The inertia of decently sized OpenStack-based cloud solutions is quite massive. The fresh deployment timeline mostly depends on the components required. For basic SDN and shared storage upgrades, roughly 70% of the time will go to pre-upgrade test-prepare tasks and 30% to post-upgrade tasks and emerging fixes.   

## Stack of all things
As the name OpenStack suggests, it's a stack of things. We help you to make the correct choices in that stack.  




