---
description: "VyOS HA firewalls: stateful, redundant, conntrack-synced. Ruleset design and software upgrades since 2023."
---

# Firewalls (VyOS HA)

Like it or not, the firewall ruleset will be the most up-to-date documentation about your network. I design it so that stays true, and so that rebooting either node is a non-event.

The sharp edges are documented: [conntrack and firewall](../../reports/network/firewall/index.md), [Linux bridge to OVS](../../reports/network/lxb2ovs/index.md).

## Design

If the firewall ruleset is modest, you will probably get away with linear code. You will likely notice that adding new rules is difficult when the ruleset needed refactoring yesterday. One change will break something else, and a hotfix unexpectedly drops traffic. The worst-case time complexity of an unstructured ruleset is unmanageable O(n).

## Configuration

All installations are different. However, since VyOS configuration is text-based, it makes sense to keep it in Git or any other version control system. Deploying via Ansible reduces errors. Deleting or replacing rules in an ordered manner is still manual labour. Ours, gladly.

## VyOS firewall Minimum Equipment List

If your design has to go metal, you cannot run a production system without hardware. Below you will find Non-negotiable MEL. You can go with less, but you will suffer.

- Two nodes, seven interfaces, high single-core performance
- WAN: 1x 100GbE
- LAN: 2x 100GbE
- HA interconnect: 2x 100GbE
- Port mirror for monitoring: 1x 100GbE
- Remote management: 1GbE

## Redundancy

You can set up firewalls as primary and backup, or load balance between them. The first option is the simplest. The second requires serious mental gymnastics, but your firewall configuration cannot be out of sync or misconfigured, or it simply does not function. It also reduces the risk that when the primary firewall fails, you discover the backup had also failed many months ago.

## Routing

Every host that needs to go somewhere needs to find its next hop. Packets get lifted from one interface to another, masked, filtered, or dropped silently according to the ruleset. Dynamic routing complicates things. Add IPv6 into the blender and you double what needs your attention. Cascade routing from one protocol to another, try to conntrack-sync HA firewalls and fast-path flows: the perfect overheated blend for Friday night.

## Firewall

Commonly, the firewall is blamed for all sorts of computing issues first. A combination of things may cause unimaginable issues. That is why the port mirror is in the MEL.

---

*Two firewalls that only meet on paper? [info@wirt.ee](mailto:info@wirt.ee). I do this for a living. [How to hire](../../hire/index.md).*
