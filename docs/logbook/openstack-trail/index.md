---
date: 2026-04-15
tags: [openstack, openstack-ansible, upgrades]
description: "One estate, upgraded in place since 2016. Ten documented runs from Ussuri to Dalmatian: the trail, and the index of bugs that repeat themselves from version to version."
---

# The OpenStack upgrade trail

One production estate, openstack-ansible, upgraded in place, release by release, never rebuilt, **since 2016, Mitaka onward**. The latest ten runs, all documented, span 2021 to 2026. Each run has its own note file, and each file ends with the previous cycle's bugs copied forward. The entries below carry only what was native to their run; what repeats is indexed here. Where the estate came from (devstack, Fuel, and a cloud booted inside its predecessor) is [the birth, 2016](../openstack-birth/index.md).

## Before the trail: the takeover

The first upgrades of this estate were not mine to orchestrate. They were **openstack-ansible's**. Its playbooks ran the releases and, with them, the package state: repositories, versions, what gets installed next. That arrangement ended the day the playbooks attempted a **ceph downgrade nobody had asked for**. It is recorded in the [Wallaby to Xena](../wallaby-to-xena/index.md) notes as their own "wtf": cinder packages going in, ceph versions coming down. The fix was a pin (`ceph_stable_release: pacific` in `user_variables.yml`) and a permanent change of ownership: from that run on, repos and versions were decided by hand, and the trail's discipline (dated backup directories, per-service checks, everything written down) is the takeover made routine. Writing things down started to matter at Ussuri→Victoria, and the habit has not broken since.

| Step | Run | The one-line story |
|---|---|---:|
| 2021-07 | [Ussuri to Victoria](../ussuri-to-victoria/index.md) | the first note, and the birthplace of most rituals |
| 2022-06 | [Victoria to Wallaby](../victoria-to-wallaby/index.md) | keystone's non-existent dev versions, galera checks its own name |
| 2022-07 | [Wallaby to Xena](../wallaby-to-xena/index.md) | a stray tmp dir poses as a database, cinder's ghost services |
| 2023-06 | [Xena to Yoga](../xena-to-yoga/index.md) | RabbitMQ refuses to boot, the erlang dance begins |
| 2023-12 | [Yoga to Zed](../yoga-to-zed/index.md) | facts problems dressed as playbook problems |
| 2024-10 | [Zed to Antelope](../zed-to-antelope/index.md) | public routing dropped, the inventory that would not generate |
| 2025-02 | [LXB to OVN](../lxb-to-ovn/index.md) | ~950 networks migrated from linuxbridge to OVN in place |
| 2025-07 | [Antelope to Bobcat](../antelope-to-bobcat/index.md) | first of three upgrades in twelve months |
| 2025-08 | [Bobcat to Caracal](../bobcat-to-caracal/index.md) | quorum queues deferred, the stream-fanout aftermath |
| 2026-04 | [Caracal to Dalmatian](../caracal-to-dalmatian/index.md) | two majors plus a distro swap underneath |

## Bugs that repeat

Bugs on this estate had a tendency to repeat themselves from version to version. Each one below is filed in full at its first appearance; the repeats are one-line pointers.

| The bug | First | Seen again |
|---|---|---|
| GPFS cinder-volume down after every venv swap: `Active-Active configuration is not currently supported` | [Ussuri 2021](../ussuri-to-victoria/index.md) | every single run since, py3.6 through py3.10. A tax, not an incident |
| env.d halt: `env.d files which override the default inventory layout` | [Ussuri 2021](../ussuri-to-victoria/index.md) | every run; the answer evolves from `rm` to `SKIP_CUSTOM_ENVD_CHECK=true` to actually reading the diff |
| `ceph-defaults ... check_socket_container.yml` breaks the infrastructure play | [Ussuri 2021](../ussuri-to-victoria/index.md) | every run: one sed, every time |
| keystone venv pip dies on a **non-existent dev version** in the constraints file | [Wallaby 2022](../victoria-to-wallaby/index.md) | [Xena](../wallaby-to-xena/index.md), one version number later, same sed |
| galera state assertions: `galera_cluster_name does not match` / `Fail if cluster is out of sync` | [Wallaby 2022](../victoria-to-wallaby/index.md) | [Zed to Antelope](../zed-to-antelope/index.md), with `galera_ignore_cluster_state=true` |
| RabbitMQ/erlang version skew: `BOOT FAILED`, cuttlefish, feature flags | [Xena to Yoga 2023](../xena-to-yoga/index.md) | pin seds in [Zed to Antelope](../zed-to-antelope/index.md), stale pins in [Antelope to Bobcat](../antelope-to-bobcat/index.md), dead repos in [Caracal to Dalmatian](../caracal-to-dalmatian/index.md) |
| nova-compute down after the ironic driver left: libvirt symlinks into the venv | [Xena to Yoga 2023](../xena-to-yoga/index.md) | [Yoga to Zed](../yoga-to-zed/index.md), [Zed to Antelope](../zed-to-antelope/index.md), four links, then five |
| glance-style `PermissionError ... GAME OVER` on cache ownership | [Wallaby 2022](../victoria-to-wallaby/index.md) | cinder-flavoured in [Xena](../wallaby-to-xena/index.md) |
| galera connection limits: `(1040, 'Too many connections')` | [Ussuri 2021](../ussuri-to-victoria/index.md) | `my.cnf` bumps until `max_connections = 9600` in [Caracal](../bobcat-to-caracal/index.md) |
| external repos dying mid-run: `no longer has a Release file` | [Xena 2022](../wallaby-to-xena/index.md) (ceph), [Zed to Antelope](../zed-to-antelope/index.md) (mariadb), [Dalmatian](../caracal-to-dalmatian/index.md) (rabbit/erlang) |
| keystone against LDAP over TLS wants the CA explicitly | [Antelope to Bobcat 2025](../antelope-to-bobcat/index.md) | prepared for in every later run |
| resolver in the blast radius: systemd-resolved breaks container DNS/tasks | [Ussuri 2021](../ussuri-to-victoria/index.md) | unmasked again in [Zed to Antelope](../zed-to-antelope/index.md) |

## The rituals

Written down once, in 2021, and re-run every cycle since: the dated backup directories per host class; per-container `/etc` plus tftpboot for the ironic containers; the all-databases dump and the grants export; the endpoint list saved before anything; **one neutron zone per run** with the rest excluded; **MTU 9000 in the agent containers** before the neutron run; the custom CPU model check after every nova install; the keepalived watchdog in screen; the ironic upgrade with every libvirt compute excluded; the post-run restore list: haproxy backends, public endpoints, radosgw, enabled_filters, GPU flavors.

## What evolved

The checkout discipline: individual playbook files restored by hand (2021) → `stable/` branches that ship broken dev packages (2022) → release tags only, with the neutron SHA bump mid-run when needed ([Zed to Antelope](../zed-to-antelope/index.md)). The env.d answer: delete the file, then learn to keep it and read the diff. The infra plays: one blob with upgrade flags (`--skip-tags haproxy-config`) → per-play runs with explicit limits. The neutron blackout protection: born as `--limit` exclusion lists typed by hand, matured into inventory-generated limit strings. The rabbit story: a boot failure in 2023 → pins managed by ansible → quorum queues deferred during the Caracal upgrade, migrated after, with the [stream-fanout aftermath](../bobcat-to-caracal/index.md#the-quorum-migration-and-the-stream-fanout-aftermath) as the closing chapter.

---

*This saved you a night? I do this for a living: [info@wirt.ee](mailto:info@wirt.ee).*
