---
title: VyOS
---
##What can a firewall do for me?
In its simplest form, it is a discriminator.  
If knocking comes from a bad neighbourhood or to the wrong door, you can ignore it - no need to be polite.  

For illustration purposes, let's take a typical request from the person who wants to publish its service.  
"Please open 172.16.42.42 TCP 9090 from 172.16.1.0/24."  

or  

"Please open 172.16.1.0/24 TCP 9090 from 172.16.42.42."  

From a firewall perspective, it is important to distinguish who initializes the connection. Requests from above mean very different things. The first case represents one specific hole for a single IP from a private range. However, in the second case, the entire /24 is open only from a single initiator. In conclusion, thinking through your source and destination is essential since it defines holes in your wall.

##About routing  
Every host that needs to go somewhere needs to go its next hop. For that purpose, in 99% of cases, one IP from the network is reserved as the default gateway. It's a golden door to wild-wild-west, usually IP of the firewall itself. If a network packet from the host enters the firewall, it will be lifted from one interface to another, masked, filtered, or even dropped silently. Actions taken are entirely under the firewall administrator's will.  
Another essential thing may be the outgoing IP or interface from the firewall (SNAT) or DNAT if the public-facing IP serves some private IP.  

##About redundancy  
From the previous chapter, readers can recall that the gateway is one single IP. It's obvious if it is single, then it is not replicated. For highly available services, avoiding a single point of failure is critical. Virtual Router Redundancy Protocol (VRRP) allows IP to move from a failed router to a live router. Usually, the hardest part is figuring out what alive or dead means.

##About VyOS configuration
All installations are different. However, since the VyOS configuration is text-based, it seems reasonable to keep it in Git or some other versioning system. Deploying code via Ansible makes it less error-prone. Here is a trivial example snippet:   

```
- name: Global options
  vyos_config:
    lines:
      - set firewall global-options all-ping enable
```

