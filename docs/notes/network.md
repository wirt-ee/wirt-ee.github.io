---
title: Network
---
## IP commands
It tends to be universal across Linux systems. If nothing else works, it is a viable option to shut down the local network manager daemon and do the configuration manually.  


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

## Martians
If traffic to the interface is unexpected, you may get a silent drop. To avoid this drop, some relaxation and breathwork are needed:  
```
echo 1 > /proc/sys/net/ipv4/conf/bond0/log_martians
sysctl -w net.ipv4.conf.bond0.rp_filter=2
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
