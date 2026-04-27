---
title: VyOS
---

##Design  
Like it or not, the firewall/router ruleset will be the most up-to-date documentation about your network configuration. If the firewall ruleset is modest, you will probably get away with linear code. You will likely notice that adding new rules is difficult when the ruleset needed refactoring yesterday. One change will break something else, and a hotfix unexpectedly drops traffic. The worst-case time complexity of the unstructured rule is unmanageable O(n).  

##Configuration  
All installations are different. However, since VyOS configuration is text-based, it makes sense to keep it in Git or any other version control system. Deploying code via Ansible reduces errors. Unfortunately, deleting or replacing rules in an ordered manner is still manual labour.  


##VyOS firewall Minimum Equipment List  
If your design has to go metal, then you cannot run a production system without hardware. Below you will find Non-negotiable MEL. You can go with less, but you will suffer.

- Two nodes, seven interfaces, high single-core performance  
    * WAN: 1x 100GbE  
    * LAN: 2x 100GbE  
    * HA interconnect: 2x 100GbE  
    * Port mirror for monitoring: 1x 100GbE  
    * Remote management: 1GbE  

##Redundancy  
You can set up firewalls as primary and backup or load balance between firewalls. The first option is the simplest to set up. The second option requires serious mental gymnastics from network administration, but your firewall configuration can not be out of sync or misconfigured, or it simply does not function. It also reduces the risk that when the primary firewall fails, you will discover that the backup had also failed many months ago.  

##Routing  
Every host that needs to go somewhere needs to find its next hop. Network packets will be lifted from one interface to another, masked, filtered, or even dropped silently according to the ruleset. When you have dynamic routing, things will get more complicated. Add IPv6 into the blender, and you double things that need your attention. Cascade routing from one protocol to another, tray to conntrack HA firewalls state and fast path flows to get the perfect overheated blend for Friday night.

##Firewall  
Commonly, the firewall is blamed for all sorts of computing issues first. Unfortunately, a combination of things may cause unimaginable issues. 
