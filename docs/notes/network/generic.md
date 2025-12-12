---
title: Generic 
---
## MACsec
Not ready to trust the airgap between your rack and your other neighbouring rack?  
Want to keep things simple and fast?  
IEEE 802.1AE-2006 to the rescue!  

```
#host A1 MACsec configuration using iproute2
ip link set eth2 down
ip link add link eth2 macsec0 type macsec encrypt on
ip macsec add macsec0 tx sa 0 pn 1 on key A1 F1A2B3C4D5E60718293A4B5C6D7E8F90
#rx from C1
ip macsec add macsec0 rx address 52:54:00:68:13:a4 port 1
ip macsec add macsec0 rx address 52:54:00:68:13:a4 port 1 sa 0 pn 1 on key C1 11223344556677889900AABBCCDDEEFF
#rx from A2
ip macsec add macsec0 rx address 52:54:00:b0:9d:34 port 1
ip macsec add macsec0 rx address 52:54:00:b0:9d:34 port 1 sa 0 pn 1 on key A2 0A1B2C3D4E5F60718293A4B5C6D7E8F9
ip addr add 10.0.0.1/29 dev macsec0
ip link set eth2 up
ip link set macsec0 up
```

```
#host B1 MACsec configuration using iproute2
ip link set eth2 down
ip link add link eth2 macsec0 type macsec encrypt on
ip macsec add macsec0 tx sa 0 pn 1 on key A2 0A1B2C3D4E5F60718293A4B5C6D7E8F9
#rx from C1
ip macsec add macsec0 rx address 52:54:00:68:13:a4 port 1
ip macsec add macsec0 rx address 52:54:00:68:13:a4 port 1 sa 0 pn 1 on key C1 11223344556677889900AABBCCDDEEFF
#rx from A1
ip macsec add macsec0 rx address 52:54:00:27:f3:b5 port 1
ip macsec add macsec0 rx address 52:54:00:27:f3:b5 port 1 sa 0 pn 1 on key A1 F1A2B3C4D5E60718293A4B5C6D7E8F90
ip addr add 10.0.0.2/29 dev macsec0
ip link set eth2 up
ip link set macsec0 up
```

```
#host C1 MACsec configuration using iproute2
root@vpp-test-host3:~# cat macsec
ip link set eth2 down
ip link add link eth2 macsec0 type macsec encrypt on
ip macsec add macsec0 tx sa 0 pn 1 on key B1 11223344556677889900AABBCCDDEEFF
#rx from A1
ip macsec add macsec0 rx address 52:54:00:27:f3:b5 port 1
ip macsec add macsec0 rx address 52:54:00:27:f3:b5 port 1 sa 0 pn 1 on key A1 F1A2B3C4D5E60718293A4B5C6D7E8F90
#rx from B1
ip macsec add macsec0 rx address 52:54:00:b0:9d:34 port 1
ip macsec add macsec0 rx address 52:54:00:b0:9d:34 port 1 sa 0 pn 1 on key B1 0A1B2C3D4E5F60718293A4B5C6D7E8F9
ip addr add 10.0.0.6/29 dev macsec0
ip link set eth2 up
ip link set macsec0 up
```

If more than a handful of hosts are needed, then MKA seems wise.   
Only make sure that EAPOL will pass (virtual homelabs):  
```
ip link set virbr_3 type bridge group_fwd_mask 0x8
```


## iproute2
If you don't know where you're going, you'll never reach your destination.
99% of routing blunders can be explained by a missing default in some table.  
```
ip route list table all
ip route show table custom
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
