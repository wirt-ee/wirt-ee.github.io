---
title: OpenStack SDN
---
##OpenStack ML2/LXB 
In 2016, the most mature way to get a self-service network up was a Linux-bridge-based agent-driven setup on top of V(X)LAN with HA provided by VRRP. Initially, the tenant network behaved nicely. SDN boot time started to look concerning when around 1000 ports needed configuration. Things got desperate when the port count rose to 6000 with SDN 40-hour boot time. Luckily, we found a simple workaround. Just add more agents in parallel and split VXLAN multicast group.   
But the customer base keeps growing, and we had to buy the fastest cores under the sun with an unhealthy amount of RAM. Then we hit 18k port count. Common sense called us when we spent 32 cores and 256 GB of RAM per network controller to keep SDN up, free of charge, of course. It was time to migrate the Neutron mechanism driver!  
After careful consideration, the decision was to move directly to OVN. So the decision was to move from ML2/LXB to ML2/OVN. Easy, start the migration tool and take a cup of coffee. Unfortunately, no such path or tool existed for online migration. Our technical readiness to support the new SND at scale was rough at best, and all customers needed notification, especially those with stricter SLA's. So all this preliminary prep work took more than half of the year. Not to mention the initial testing, failing and re-testing phases.  
 
##OpenStack ML2/LXB to ML2/OVN migration
Anyway, when the stage was set up, the following steps played out within 16 hours:

1. Back up all the configuration and databases.  
2. Remove all network agents from inventory. **Stop and disable** running network agents like neutron-linuxbridge-agent, neutron-l3-agent, neutron-dhcp-agent and neutron-metadata-agent.
3. Delete all unneeded bridges, VXLAN interfaces, and network namespaces lingering tap interfaces.
4. Delete all unneeded iptables/nftables rules.
5. Deploy OVN with your tool of choice!
6. Since the database is the source of truth and doesn't care what cloud management system is pulling from it, you can refill (repair) the northbound database from it with neutron-ovn-db-sync-util
7. It depends on your environment, but you may need to move the Geneve carrying interface to OVS and do some patching and VLAN tagging.
8. Then lastly, update ports to reflect the new reality that vif_type is now ovs, not a bridge:
```
DB [(neutron)]> update ml2_port_bindings set vif_type='ovs' where vif_type='bridge';
DB [(neutron)]> update networksegments set network_type='geneve' where network_type='vxlan';
```

##Results and conclutions
Looks easy? Handful of steps and done? Guess again! If it blows up, it's spectacular. You can keep all the pieces. Let's assume that you are still employed or the proud business owner and need to roll back. It takes around a week, but you and your dog just ended a 16-hour shift.
If rollaback is not an option, you may need to clean the southbound database line by line, comparing and hunting for UUID spaghetti with wrong values. Tracing veth pairs in OVS that, by design, don't show all traffic jumping between userspace and kernelspace, checking and rechecking MTUs on all hypervisors, and trying to ignore ever-louder customers' complaints about broken networking.


But if it ends well, your network controllers are not [hogged](https://drive.google.com/file/d/1xhRPwDqUR597eoD1g_nRLYc3McpZTPlI/view?usp=drive_link) up anymore, boot times are acceptable, and you can silently watch how someone else's weekend (non-LAN) party final stages are played out on your way home.

