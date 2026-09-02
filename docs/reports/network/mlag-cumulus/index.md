# MLAG on Cumulus NVUE

Cumulus Linux on Mellanox Spectrum switches (MSN3700, 32×200G QSFP56; Spectrum-4 400G), configured with NVUE, in MLAG pairs. The working shapes — the dated bites live in the [logbook entry](../../../logbook/cumulus-nvue-mlag/index.md). Hostnames, addresses and VLAN layouts below are genericized.

## MLAG essentials

    # both switches: bonds with MLAG ids, then the peerlink
    nv set interface bond1 bond member swp1
    nv set interface bond1 bond mlag id 1
    nv set interface bond1 bridge domain br_default
    nv set interface peerlink bond member swp31-32
    nv set mlag enable on
    nv set mlag peer-ip linklocal
    nv set mlag backup <peer-mgmt-ip> vrf mgmt
    nv set mlag mac-address <shared-mac>
    nv config apply

Verify the pair is sane:

    # clagctl status
    The peer is alive
         Our Priority, ID, and Role: 32768 <mac> secondary
        Peer Priority, ID, and Role: 32768 <mac> primary
              Peer Interface and IP: peerlink.4094 fe80::<ll> (linklocal)

    nv show mlag consistency-check    # config conflicts between the pair
    nv show interface mlag-cc

## A port config you can reuse

The parameterized shape for one more node — one bond, one MLAG id, tagged VLANs:

    port=11; id=110; host=node-a
    nv set interface swp${port} description ${host}
    nv set interface bond${id} bond member swp${port}
    nv set interface bond${id} bond mlag id ${id}
    nv set interface bond${id} bond mlag state enabled
    nv set interface bond${id} type bond
    nv set interface bond${id} bridge domain br_default vlan <your-vlan-list>
    nv set interface bond${id} description ${host}

Validate what actually landed:

    nv show interface description
    nv show bridge domain br_default vlan
    nv show interface bond${id} bridge domain br_default
    bridge fdb show
    nv show bridge domain br_default mac

## Breakouts

A 200G port splits into two 100G (QSFP56: four lanes at 53.125G — [the breakout types explained](https://atgbics.com/blogs/tech-talk/different-types-of-200g-qsfp-technology)):

    nv set interface swp1 link breakout 2x lanes-per-port 2
    nv config apply
    nv show interface | grep swp1s     # swp1s0, swp1s1

    # undo
    nv unset interface swp1 link breakout
    nv unset interface swp1,swp1s0-1

## Install via ONIE from a USB stick

When the switch has no reachable network path worth trusting:

    # grub menu -> ONIE -> "ONIE: Install os"
    # at the console: onie-stop   (cancel install scanning)
    ONIE:/ # fsck -y /dev/sdb1
    ONIE:/ # mkdir /mnt/tmpusb && mount /dev/sdb1 /mnt/tmpusb
    ONIE:/ # cd /mnt/tmpusb
    ONIE:/ # onie-nos-install cumulus-linux-5.10.0-mlx-amd64.bin

And when you need a full picture for a vendor: `sudo cl-support` generates the debug dump.

---

*This saved you a night? I do this for a living: [info@wirt.ee](mailto:info@wirt.ee).*
