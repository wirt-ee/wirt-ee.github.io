---
title: Overview
---
## Four pillars for IT sadness! 
This section contains opinionated notes extracted from /dev/random.  
Warning - nerd content! 

## Compute nodes
If it breaks or gets its upgrade, it is used and abused over and over to get out of as many ticks per cycle as possible. It is not a pet, even if it paid your kid's kindergarten and schooling and your own leisure time. And if it is worked many times over its expected lifetime, you try to sell its parts to recover some utilization costs. Totally underrated piece of everything that ships with cardboard coffins.

## Networks and overlays
In the good old days, there was a VLAN. And that's it. 
Now, everything is on top of every other thing. Everyone expects excellent dual-stack performance, and MTU keeps shrinking. 
Networking is so SDN that we tend to separate networks into "hard" and "soft". Soft networking is generated, and a hard network is something you type in with your fingertips to the switch console. Luckily, the physical network is still what it was. Only high-speed optic power consumption has blown through the roof. 

## Storage tiers
A not long time ago, there were local storage, RAID and NAS/SAN boxes for LUNs you hacked together with LVM to get perf numbers for your DBA, who hates you.
Now, it's shared erasure encoded multiprotocol mesh with online upgrades and failure domains. And if it explodes, you can keep all the pieces. And DBA still complains about service time.
Regarding storage tearing and archival: "King Tape is dead. Long live the King Tape." Sometimes, if you need to Petabyte your backyard, vendor lock is not a bad thing.
Speaking about open source, it's worth mentioning that things are complicated, and sometimes, support contracts or wise men from the mountaintop are needed. 
On a bad day, You take a half-block size 4M object and go on a pilgrimage. If it's a bad day on steroids, you can consult with your system administrator, e.g. with yourself.

## Chaos monkeys (e.g. system administrators/DevOps)
We, I, are still the same. Old busted hardware, biased problem assessments, gut-based technology selections behind L1 support and paywall, and no repo-based CI.
But this gut-based decision process still beats state-of-the-art language models. Of course, this "Thing" is a good company for a man who was brick-walled in with IBM's mainframe.

