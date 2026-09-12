---
description: "VyOS HA firewalls: stateful, redundant, conntrack-synced. In production since 2023."
---

# Firewalls (VyOS HA)

Two-node VyOS HA firewalls: stateful, redundant, conntrack-synced. In production since 2023. One pair, upgraded in place from 1.2.9 to the current release, never rebuilt: [the logbook](../../logbook/vyos-three-years/index.md).

VyOS configuration is text. Keep it in version control; deploying via Ansible reduces errors. The sharp edges are documented: [conntrack and firewall](../../reports/network/firewall/index.md), [Linux bridge to OVS](../../reports/network/lxb2ovs/index.md).

## Minimum Equipment List

- Two nodes, seven interfaces, high single-core performance
- WAN: 1x 100GbE
- LAN: 2x 100GbE
- HA interconnect: 2x 100GbE
- Port mirror for monitoring: 1x 100GbE
- Remote management: 1GbE

The port mirror is in the MEL because when something breaks, the firewall gets blamed first and the real cause is usually several factors combined.

## Redundancy

Primary/backup is the simple option. Load balancing requires both configurations to stay in sync at all times, and it hides the case where the backup failed months before the primary.

## Routing and IPv6

Every host needs its next hop. Dynamic routing complicates things. IPv6 doubles what needs attention. Cascading routing protocols into conntrack-synced HA firewalls multiplies the failure modes.

Questions, quotes: [info@wirt.ee](mailto:info@wirt.ee). [How to hire](../../hire/index.md).
