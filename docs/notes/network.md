---
title: Network
---
## IP commands
It tends to be universal across Linux systems. If nothing else works, it is a viable option to shut down the local network manager daemon and do the configuration manually. Also, make sure that the default route exists:  
```
ip route list table all
```

## Martians
If traffic to the interface is unexpected, you may get a silent drop. To avoid this drop, some relaxation and breathwork are needed:  
```
echo 1 > /proc/sys/net/ipv4/conf/bond0/log_martians
sysctl -w net.ipv4.conf.bond0.rp_filter=2
```

## Policy based routing
Sometimes machine has more than one interface. Then, it's time to decide what goes where:

```
ip addr add ${ip}/${mask} dev ${dev}
ip link set dev ${dev} up
test -z "$(grep ut_pub /etc/iproute2/rt_tables)" && echo "666 pub" >> /etc/iproute2/rt_tables
ip rule add from ${ip} table pub
ip rule add to ${ip} table pub
ip route add default via ${gw} dev ${dev} table pub
```

## Systemd networkd
Over the years, every new distro upgrade has introduced some new ways to configure your network. 
The situation was so bad that adding ip commands directly to the crontab @reboot line was quite common. 
It was a pleasant surprise that the networkd actually worked and did not cause brain damage when configured. 
```
cat  /etc/systemd/network/bond.network
[Match]
Name=eno3*

[Network]
Bond=bond0

cat /etc/systemd/network/bond0.netdev
[NetDev]
Name=bond0
Description=LAG/Bond to a switch
Kind=bond
MACAddress=aa:aa:aa:aa:aa:aa

[Bond]
Mode=802.3ad
MIIMonitorSec=1
LACPTransmitRate=slow

cat /etc/systemd/network/bond0.network 
[Match]
Name=bond0

[Network]
VLAN=bond0.<vlan tag>

cat /etc/systemd/network/bond0.<vlan tag>.netdev 
[NetDev]
Name=bond0.<vlan tag>
Kind=vlan

[VLAN]
Id=<vlan tag>

cat /etc/systemd/network/bond0.<vlan tag>.network
[Match]
Name=bond0.<vlan tag>

[Network]
DHCP=yes
``` 
## Systemd hooks
Sometimes, you need random scripts to run when the network connection status changes. The tool for the job in systemd world is networkd-dispatcher.
```
#!/bin/bash
#workaroud for issue networkd backed netpaln that drops policy based routing and vlanX carring interface from br-vlan

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

brctl addif br-vlan bond0
if [[ -z "$(ip rule list | grep br-public1)" ]]; then
	ip rule add from xxx.xx.xx.0/24 table br-public1
	ip route add default via xxx.xx.xx.1 dev br-public table br-public1
	ip rule add from yyy.yy.yy.0/24 table br-public2
        ip route add default via yyy.yy.yy.1 dev br-public table br-public2
	ip route flush cache
fi
```
