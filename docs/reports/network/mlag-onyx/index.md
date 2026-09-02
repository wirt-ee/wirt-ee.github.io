# MLAG on NVIDIA Onyx

NVIDIA Onyx on Mellanox MSN3700 switches, MLAG pairs — the OS that ran the estate's 100G pairs before the move to [Cumulus and NVUE](../mlag-cumulus/index.md). Same hardware, older school: a Cisco-like CLI on Mellanox silicon. The dated bites — the lacp-individual/PXE conflict among them — live in the [logbook entry](../../../logbook/onyx-mlag/index.md). Hostnames, addresses and VLAN layouts below are genericized.

## MLAG port-channel, the recipe

    enable
    configure terminal
    interface mlag-port-channel 10
      mtu 9216 force
      lacp-individual enable force
      switchport mode trunk
      switchport trunk allowed-vlan 10
      switchport trunk allowed-vlan add 20-23
      description node-a
      exit
    interface ethernet 1/10 mlag-channel-group 10 mode active
    no interface mlag-port-channel 10 shutdown
    write memory

Run on both switches of the pair. One VLAN only is simpler:

    interface mlag-port-channel 53
      mtu 9216 force
      lacp-individual enable force
      switchport mode access
      switchport access vlan 10
      exit
    interface ethernet 1/53 channel-group 53 mode active
    interface mlag-port-channel 53 spanning-tree port type edge
    write memory

And the hybrid trick — one untagged VLAN plus tagged ones on the same port-channel:

    interface mlag-port-channel 21
      switchport mode hybrid
      switchport access vlan 10
      switchport hybrid allowed-vlan 20

Validate what landed:

    show interface mlag-port-channel 17 switchport
    Interface   Mode    Access vlan   Allowed vlans
    Mpo17       trunk   N/A           <vlans>

    show interface mlag-port-channel summary
    show lacp interfaces ethernet 1/3      # current LACP rate

## Upgrade procedure

    show images
    image fetch vrf mgmt scp://<user>@<server>/path/onyx-X86_64-3.9.3220.img
    image install onyx-X86_64-3.9.3220.img
    configure terminal
    image boot next
    exit
    write memory
    reload

Two rules that save the evening:

- **Always upgrade the standby switch of the MLAG pair first.** ([Upgrading HA groups](https://docs.nvidia.com/networking/display/onyxv3102002/upgrading+ha+groups))
- If you are many versions behind, the NVIDIA support portal has a "calculator" that works out the recommended upgrade path through the intermediate releases. Use it; jumping is how HA pairs die.

## Making the switch show what hangs on it

Switches only know host names if the hosts speak LLDP. On every attached host (lldpad):

    systemctl enable lldpad.service
    systemctl start lldpad.service
    for i in $(ls /sys/class/net/ | egrep 'eth|ens|eno|enp'); do
      lldptool set-lldp -i $i adminStatus=rxtx
      lldptool -T -i $i -V sysName enableTx=yes
      lldptool -T -i $i -V portDesc enableTx=yes
      lldptool -T -i $i -V sysDesc enableTx=yes
      lldptool -T -i $i -V sysCap enableTx=yes
      lldptool -T -i $i -V mngAddr enableTx=yes
    done

Then `show interfaces ethernet 1/27 transceiver` names optics by vendor, part number and serial — the inventory view that answers "which module is in which port".

## CLI corners

    no cli session paging enable        # the pager stops stealing your log
    show log continuous                 # tail -f
    show what-just-happened             # exactly what it says

## Static management, with rollback

    # no interface mgmt0 dhcp
    interface mgmt0 ip address <ip> <mask>
    ip route 0.0.0.0/0 <gw>
    ip name-server <dns>

Rollback is the mirror image: `interface mgmt0 dhcp` and the commented-out `no` lines. Write the rollback down before you type the change — mgmt0 is the interface you are typing on.

For support tickets:

    debug generate dump
    file debug-dump upload latest scp://<user>@<server>/path/

---

*This saved you a night? I do this for a living: [info@wirt.ee](mailto:info@wirt.ee).*
