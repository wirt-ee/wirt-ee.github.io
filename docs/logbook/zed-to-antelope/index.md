---
date: 2024-10-10
tags: [openstack, openstack-ansible, upgrades, keystone, systemd-networkd]
description: "Zed to Antelope on openstack-ansible 27.x: the upgrade that took public routing off the controllers, the inventory that would not generate, and the _member_ deprecation."
---

# OpenStack Zed to Antelope

Context: the same estate, one run earlier than everything else in this trail. Zed → antelope, openstack-ansible `stable/2023.1` — checked out 27.5.1, moved to 27.6.0 mid-run for a neutron SHA fix. Backup directory dated 2024-10-10; a second dated pass over the compute hosts in December (reason not recorded in the notes). What followed is already filed: the [LXB to OVN migration](../lxb-to-ovn/index.md) on the antelope estate, then [Antelope to Bobcat](../antelope-to-bobcat/index.md) and the rest. Names, addresses and subnets genericized.

## Preparation — with one thing done before, not after

Ceph was upgraded manually, pacific → quincy, *before* the run — so that the playbooks could not "upgrade" it backwards. Otherwise the same discipline as every entry in this trail: dated directories, venvs (`*26.*`), per-container `/etc`, per-database dumps, grants, endpoint list.

## The run

New in 2023.1, two upgrade utilities that did not exist in earlier cycles:

    openstack-ansible "${SCRIPTS_PATH}/upgrade-utilities/define-neutron-plugin.yml"
    openstack-ansible certificate-ssh-authority.yml

The env.d halt from the later entries appeared here first, and this time the diff was worth reading — `env.d/neutron.yml`, one line: `is_metal: false` (ours) against `is_metal: true` (upstream). That line decides whether neutron runs in containers or on metal, and everything downstream of it. `SKIP_CUSTOM_ENVD_CHECK=true` and on.

## What bit — quick reference

| The thing you are staring at | Fix | § |
|---|---|---:|
| prod controllers lose public routing and bond0 | networkd-dispatcher ifup hook | 1 |
| `Specified hosts and/or --limit does not match any hosts` + `KeyError: 'address'` | fix `openstack_user_config.yml` networks, re-generate | 2 |
| mariadb repo: `no longer has a Release file` | switch to a mirror, strip the role's repo tasks | 3 |
| `lxc_hosts : Build the base image` hangs in debootstrap | disable IPv6 | 4 |
| `'dict object' has no attribute 'distribution'` | re-gather facts | 5 |
| haproxy: `inconsistencies between private key and certificate loaded` | reorder the pem so key and cert moduli match | 6 |
| no public IP after haproxy-install | restore the keepalived config | 7 |
| galera: `The 'changed' test expects a dictionary` | comment out the `Update Apt cache` task | 8 |
| galera: `Fail if cluster is out of sync` | `-e galera_ignore_cluster_state=true` | 9 |
| GPFS cinder-volume down after venv swap | the usual two moves | 10 |

Notes on a few:

1. The worst moment of the run: a systemd-networkd reload on the prod controllers dropped **policy-based routing for both public subnets and the bond0 slave out of `br-vlan`**. The host is still up, the cloud is unreachable from outside. The repair is a hook that re-adds both on every routable transition — `/etc/networkd-dispatcher/routable.d/50-ifup-hooks`:

        #!/bin/bash
        # workaround: drops policy based routing and vlan-carrying interface from br-vlan
        export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
        brctl addif br-vlan bond0
        if [[ -z "$(ip rule list | grep br-public-<id>)" ]]; then
          ip rule add from <public-subnet-a> table br-public-<id>
          ip route add default via <gateway-a> dev br-public-<id> table br-public-<id>
          ip rule add from <public-subnet-b> table br-public
          ip route add default via <gateway-b> dev br-public table br-public
          ip route flush cache
        fi

   The bond itself is plain systemd-networkd: `10-bond0.netdev` (802.3ad, LACP slow), member `.network` with `MTUBytes=9000`.

2. The OSA inventory would not generate at all — the traceback ends in `osa_toolkit/generate.py`, `_add_additional_networks`, `KeyError: 'address'`, and the `--limit` groups (`rabbitmq_all`, `galera_all`) simply do not exist because the inventory is empty. Three things untangled it: the debug flag in `dynamic_inventory.py` (log to file), two stale network entries in `openstack_user_config.yml` (`vlan 501 eth11`, `flat eth12`) commented out, and the leftover `ironic*` host references removed by hand from `openstack_hostnames_ips.yml` and `openstack_inventory.json`. The `is_metal` line from the env.d halt is the same thread — this is one breakage wearing three hats.

3. `http://downloads.mariadb.com/MariaDB/mariadb-10.6.10/repo/ubuntu jammy Release` went away, so galera could not even fetch packages. The role got a working mirror, the `Add galera repo` and `Update Apt cache` tasks commented out so ansible could not re-add the dead one — which is also what §8 trips over next.

4. Debootstrap hangs with IPv6 on, silently, forever:

        /bin/sh /usr/sbin/debootstrap --variant minbase jammy /var/lib/machines/ubuntu-22-amd64 http://archive.ubuntu.com/ubuntu

        net.ipv6.conf.all.disable_ipv6 = 1
        net.ipv6.conf.default.disable_ipv6 = 1
        net.ipv6.conf.lo.disable_ipv6 = 1

5. A facts problem dressed as a playbook problem — `ansible all -m setup --tree /tmp/factsetup` and re-run.

## `_member_` is deprecated, your projects still use it

Antelope's policies deprecate the `_member_` role. Ours still relied on it: 170 production projects with `_member_`, 426 with `member`, test the reverse shape. The upgrade utility builds the role inference rule so the old assignments keep meaning something:

    openstack "${SCRIPTS_PATH}/upgrade-utilities/implied_member_role.yml"

Count your own before you run it: `openstack role assignment list | grep <role-id> | wc -l`.

## After the run, dated

- **2024-11-04** — a controller's agent exits on boot: `Interface eth11 for physical network vlan does not exist. Agent terminated!` The mapping line was the fix, same as the blackout prevention in the [Caracal entry](../bobcat-to-caracal/index.md#keeping-the-network-alive-during-the-neutron-run); the controllers map the vlan network to the interface, the hypervisors to the bridge.

The rest of the protections — MTU 9000, one zone per neutron run, the old keepalived restart — are the same habits, filed once with the Caracal entry.

## Older leftovers in the same note

The tail of this file is the Zed-era pile born in the [Yoga to Zed run](../yoga-to-zed/index.md#the-aftermath-december-to-february) — the rabbit/erlang history, the nova libvirt symlinks, the ironic walls, the radosgw unit fix. It appears in every upgrade note in this trail; it is filed once.

---

*This saved you a night? I do this for a living: [info@wirt.ee](mailto:info@wirt.ee).*
