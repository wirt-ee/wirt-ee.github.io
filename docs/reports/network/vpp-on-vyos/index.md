# VPP on VyOS

VyOS can hand interfaces to VPP — vector packet processing in userspace — and keep a normal VyOS config on top. The [VyOS VPP docs](https://vpp-docs.vyos.dev/features/) describe the feature; this is the working configuration shape, including the parts that bite.

## Kernel preparation

VPP wants isolated cores and hugepages. Give it both, and take the matching set of kernel knobs:

    set system option kernel memory hugepage-size 2M hugepage-count 4096
    set system option kernel cpu disable-nmi-watchdog
    set system option kernel cpu isolate-cpus '3-7'
    set system option kernel cpu nohz-full '3-7'
    set system option kernel cpu rcu-no-cbs '3-7'

## VPP cores and drivers

    set vpp settings cpu main-core '3'
    set vpp settings cpu corelist-workers '4-7'

The core lists must match the isolated set, or you get connectivity surprises. Then the driver decision, per interface:

    set vpp settings interface eth1 driver dpdk
    set vpp settings interface eth2 driver xdp

Observed: `dpdk: rte_eth_dev_set_mtu failed (mtu 1496, rv -22)` on one NIC; `af_xdp: eth2: set mtu not supported yet` on another; in a VM, the dpdk driver only worked with `<model type='vmxnet3'/>`. And VPP flatly refuses ancient CPUs:

    vpp[3950]: ERROR: This binary requires CPU with SSE4.2 extensions.

## The bridge pattern

The workhorse shape: physical interface into a VPP bridge, a loopback as the BVI, and a kernel-visible TAP so the normal VyOS config (addresses, routes, firewall) keeps working:

    set vpp settings interface eth1 driver dpdk
    set vpp interfaces bridge br1 member interface eth1
    set vpp interfaces bridge br1 member interface lo1 bvi
    set vpp interfaces loopback lo1 kernel-interface 'vpptun1'
    set vpp kernel-interfaces vpptun1 address '192.0.2.11/24'
    set vpp kernel-interfaces vpptun1 mtu '1500'

One bridge per physical interface (br1/lo1/vpptun1 for eth1, br2/lo2/vpptun2 for eth2) — then the kernel side sees ordinary interfaces and `vppctl show interface` shows the VPP side:

    vppctl set interface state eth1 up
    vppctl set interface mtu 1500 eth1
    vppctl set interface ip address eth1 198.51.100.2/30
    vppctl show ip fib
    vppctl show ip neighbors

## Bonding and VLANs

    set vpp interfaces bonding bond1 mode active-backup
    set vpp interfaces bonding bond1 member interface eth1
    set vpp interfaces bonding bond1 kernel-interface vpptun1
    set vpp kernel-interfaces vpptun1 address '192.0.2.11/24'

    set vpp kernel-interfaces vpptun2 vif 2
    set vpp kernel-interfaces vpptun2 vif 2 address '198.51.100.2/30'
    set vpp kernel-interfaces vpptun2 vif 2 description "Management network"

## ACLs

VPP ACLs attach per interface as tagged lists — ingress and egress separately, with an explicit default deny:

    set vpp acl ip interface eth1 input acl-tag 100 tag-name 'INGRESS-100'
    set vpp acl ip tag-name INGRESS-100 rule 101 action 'permit'
    set vpp acl ip tag-name INGRESS-100 rule 101 destination prefix '198.51.100.0/24'

    set vpp acl ip interface eth1 input acl-tag 9999 tag-name 'INGRESS-9999'
    set vpp acl ip tag-name INGRESS-9999 rule 9999 action 'deny'

Egress is the same with `output` and `source prefix`. Verify with:

    vppctl show acl-plugin acl
    vppctl show acl-plugin interface
    vppctl trace add dpdk-input 10

## Restart procedure

VPP grabs the NICs with vfio-pci; a clean restart gives them back to the kernel first:

    systemctl stop vpp
    echo 0000:07:00.0 > /sys/bus/pci/drivers/vfio-pci/unbind
    echo 0000:08:00.0 > /sys/bus/pci/drivers/vfio-pci/unbind
    echo 0000:07:00.0 > /sys/bus/pci/drivers/vmxnet3/bind
    echo 0000:08:00.0 > /sys/bus/pci/drivers/vmxnet3/bind
    /usr/libexec/vyos/conf_mode/vpp.py

---

*This saved you a night? I do this for a living: [info@wirt.ee](mailto:info@wirt.ee).*
