# VyOS firewall

## VyOS 1.5.x ISO using Docker
You can run the HA production cluster with this if you are brave (and experienced).  

```
git clone -b current --single-branch https://github.com/vyos/vyos-build
cd vyos-build/
docker run --rm -it --privileged -v $(pwd):/vyos -w /vyos vyos/vyos-build:current bash
sudo make clean
sudo ./build-vyos-image generic --architecture amd64 --build-by "<your-name>"
```

Same flow with `--build-type release` for sagitta, or the equuleus branch with `./configure --version 1.3.2` when a customer-of-one needs a pinned release.

How that holds up in production: [three years of the same HA pair, never rebuilt](../../../logbook/vyos-three-years/index.md).

## IPv6 link-local and VRRPv3

VyOS 1.5 defaulted `addr_gen_mode` to 1. The symptom: after an interface down → up cycle, the IPv6 link-local address is gone, and VRRPv3 does not work. The fix, default and per interface:

```
set system sysctl parameter net.ipv6.conf.default.addr_gen_mode value 0
set system sysctl parameter net.ipv6.conf.eth3.addr_gen_mode value 0
```

## Conntrack forensics

Under SYN flood suspicion, first ask who is connecting and to whom. The op-mode table plus awk answers both:

```
# top SYN_SENT sources
show conntrack table ipv4 | grep SYN_SENT | awk 'NR>2 {split($2,a,":"); print a[1]}' | sort | uniq -c | sort -rn | head -20

# for a specific IP, see what it is connecting to
for IP in $(show conntrack table ipv4 | grep SYN_SENT | awk 'NR>2 {split($2,a,":"); print a[1]}' | sort | uniq -c | sort -rn | head -4 | awk '{print $2}'); do
  echo "=== $IP ==="
  show conntrack table ipv4 | grep SYN_SENT | awk -v ip="$IP" 'NR>2 && $2 ~ "^"ip":" {print $3}' | sort | uniq -c | sort -rn | head -10
done
```

Counting, evicting, watching:

```
conntrack -L | grep -oP 'src=\K[0-9.]+' | sort | uniq -c | sort -rn | head -10   # top talkers
conntrack -C && cat /proc/sys/net/netfilter/nf_conntrack_max                    # how full
conntrack -S | grep invalid                                                      # is it increasing?
conntrack -D -s <ip>                                                             # evict one host
watch sudo nft list set vyos_filter <set-name>                                   # watch the blocklist
renice -n -20 -p $(pidof conntrackd)                                             # conntrackd deserves the front row
```

On an HA pair, the states are only half the story. The other half is whether they sync:

```
show conntrack-sync statistics          # <- the important one
show conntrack-sync cache internal
show conntrack-sync cache external
show conntrack-sync status
conntrackd -C /run/conntrackd/conntrackd.conf -e    # dump the external cache: the foreign states
run restart conntrack-sync              # restarting the service also resets the statistics
```

## One core for conntrackd and the NIC IRQ

Throughput and latency first, then keep two housekeeping jobs off the general CPUs:

```
set system option performance network-throughput
set system option kernel disable-power-saving            # C states
# reserve one physical core for conntrackd and the NIC IRQ
set system option kernel cpu isolate-cpus '15,31'
set system option kernel cpu nohz-full '15,31'
```

Check the pinning took, and pin conntrackd to the reserved core through systemd:

```
ps -eLo pid,tid,psr,comm | grep -E "^\s*[0-9]+\s+[0-9]+\s+(15|31)"
sed -r -i 's|(\[Service\])|\1\nCPUAffinity="15"|g' /etc/systemd/system/conntrackd.service.d/override.conf
```

Then pin the NIC interrupts to the second reserved core. Find the IRQs through the PCI slot of the interface:

```
grep PCI_SLOT_NAME /sys/class/net/*/device/uevent | grep eth5
cat /proc/interrupts | grep 0000:41:00.1 | awk '{print $1}' | tr -d ':' \
  | while read l; do echo 31 > /proc/irq/${l}/smp_affinity_list; done
```

Measured on the bench, for honesty: `ethtool -C eth5 rx-usecs 0 tx-usecs 0 rx-frames 16 tx-frames 16` (coalescing off) was a minor improvement. `ethtool -G eth5 rx 64 tx 64` (ring buffer shrink) changed nothing.

---

*This saved you a night? I do this for a living: [info@wirt.ee](mailto:info@wirt.ee).*
