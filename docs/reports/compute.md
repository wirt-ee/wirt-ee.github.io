---
title: Compute
---
## Hyperconverged infrastructure
Everyone wants their cake and wants to eat it too. Expecialy when you have around 100 cores per multisocet socet machine with few TB of RAM loaded with tens of TB NVMEs. Request to get a shared cluster of everything is not so uncommon.  

## NUMA
To avoid interfering with different services, it seems plausible to sort the running process.  
It also disciplines rouge clients and helps service providers with QOS management.  
Also, if it's overcommitted, it's much easier to communicate why things are slow.  

```
ps aux  | grep libvirt  | grep -v grep | awk '{print$2}' | while read line; do 
	echo taskset -cp "${vm0}-${numa0_end},${vm1}-${numa1_end},${vm2}-${numa2_end},${vm3}-${numa3_end}" "${line}"; done | sh 1>/dev/null

virsh list  | awk '/inst/ {print $2}' | while read l;do 
	for i in $(seq 0 $(virsh dominfo $l |awk '/CPU\(/ {print$2-1}')); do 
		virsh vcpupin $l $i "${vm0}-${numa0_end},${vm1}-${numa1_end},${vm2}-${numa2_end},${vm3}-${numa3_end}" 1>/dev/null
		#virsh vcpupin $l $i "1-255" 1>/dev/null
	done 
done
```

## Be not so nice
If it waits behind storage, then the system slows down. Prioritize shared storage proceses.
```
ps -e -o pid,uid,ppid,pri,ni,cmd | awk '/ceph-osd/  &&  !/-20/ && !/awk/ {print "renice -n -20 -g",$1,";ionice -c 1 -n 1 -p",$1}'  | sh
```
