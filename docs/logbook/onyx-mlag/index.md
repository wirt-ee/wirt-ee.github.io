---
date: 2023-11-22
tags: [networking, mellanox, onyx, mlag]
description: "NVIDIA Onyx on MSN3700: the lacp-individual conflict — PXE on one end, a running bond on the other — and the bugs around it. The predecessor OS of Cumulus on the same estate."
---

# Onyx MLAG

Context: NVIDIA Onyx on Mellanox MSN3700 switches, MLAG pairs — the OS that ran the 100G pairs before the estate moved to [Cumulus and NVUE](../cumulus-nvue-mlag/index.md). Same hardware, older school. This entry is the dated bites; the recipes — MLAG port-channel shapes, upgrade procedure, LLDP setup, CLI corners, management-address rollback — are in [Evergreen](../../reports/network/mlag-onyx/index.md). Hostnames, addresses and VLAN layouts genericized; the date is from the log lines in the notes.

## lacp-individual: you cannot have both

`lacp-individual enable force` lets a port-channel member act alone when the host speaks no LACP. Without it, PXE does not work — the boot NIC has no LACP. With it, a running Red Hat 9 bond failover breaks. The notes' wording, translated: hold the beak and the tail comes loose.

The follow-up bug: when acting as individual, the switch picks the member port randomly. The fix pins it:

    # show lacp interfaces ethernet 1/20
    #   Port State: Down, Aggregation State: Aggregation, Defaulted
    interface ethernet 1/20 lacp port-priority 32767

Lowest numerical priority wins — so the *same* member acts individual every time, and PXE becomes deterministic.

## Bugs

1. **`Configuration error, interface Eth1/25 configured as a router port`** when adding an interface to an MLAG channel-group. The port had a leftover `no switchport force`. The fix is not intuitive — clear it by typing the opposite twice:

        interface ethernet 1/25 no switchport force
        interface ethernet 1/25 switchport force
        interface ethernet 1/25 switchport

2. **clusterd restarts on management address change** — `I/F address changed from ... restarting` in the logs. Expected when renumbering mgmt0, alarming if you did not.

---

*This saved you a night? I do this for a living: [info@wirt.ee](mailto:info@wirt.ee).*
