---
date: 2021-07-07
tags: [openstack, openstack-ansible, upgrades, ironic]
description: "Ussuri to Victoria on openstack-ansible 22.1.4: the first upgrade note in the trail — and the birthplace of most of its rituals."
---

# OpenStack Ussuri to Victoria

Context: the oldest note in the estate's upgrade trail — ussuri → victoria, openstack-ansible tag 22.1.4, backup directories dated 2021-07-07. Nine more release steps followed on the same estate, [up to Dalmatian and beyond](../openstack-trail/index.md); most of the rituals those later runs lean on were written down here first. Names, addresses and endpoint names genericized; errors and commands as they happened.

## Preparation

The discipline in its original shape: dated directories per host class, per-container `/etc` plus tftpboot for the ironic api containers, `/var/lib/ceph` on the OSD hosts, the all-databases dump, the grants export, the endpoint list (`endpoint_list_ussuri`). What later runs added — per-database dumps, venv copies, the nightly backup script — came later.

## The run

The checkout style is 2021-vintage: individual playbook files restored with `git checkout` one by one before the tag itself. The env.d halt appeared on its very first day, and the answer then was blunter than later runs':

    rm /etc/openstack_deploy/env.d/neutron.yml
    openstack-ansible "${SCRIPTS_PATH}/upgrade-utilities/deploy-config-changes.yml"

(The later runs keep the file and answer with `SKIP_CUSTOM_ENVD_CHECK=true` — [Zed to Antelope](../zed-to-antelope/index.md) shows why the file was worth keeping.)

## What bit — quick reference

| The thing you are staring at | Fix | § |
|---|---|---:|
| `delta_rsyslog_container` fails on DNS | systemd-resolved off, manual `resolv.conf` | 1 |
| `ceph-defaults ... check_socket_container.yml` fails the infrastructure play | sed the ceph stanzas out of `setup-infrastructure.yml` | 2 |
| keystone `credential_rotate` exits rc=1 mid-play | run the keystone role separately | 3 |
| cinder db sync: `all volumes have been migrated to the __DEFAULT__ volume type` | `online_data_migrations`, then SQL on the deleted rows | 4 |
| heat: `EntityNotFound: The Service (<id>) could not be found` | reboot the host | 5 |
| rsyslog: `action 'action 0' suspended (module 'builtin:omfile')` | remove rsyslog — the journal exists | 6 |
| nova: `SchedulerHostFilterNotFound: ... RetryFilter, AggregateCoreFilter, AggregateDiskFilter` | trim `enabled_filters` | 7 |
| `(1040, 'Too many connections')` | raise the limit in `my.cnf` | 8 |
| GPFS: `Active-Active configuration is not currently supported` (cinder-22.1.4, py3.6) | comment `SUPPORTS_ACTIVE_ACTIVE`, extend rootwrap | 9 |
| novnc: `Error code explanation: HTTPStatus.NOT_FOUND` | `novncproxy_base_url` with `vnc_lite.html` | 10 |
| ironic: nova-compute `[api_database]/connection` — `DBNotAllowed` | comment the api_database connection and glance `api_servers` | 11 |
| ironic role: `list object has no element 0` | patch the role's `main.yml` | 12 |
| IPMI: `IPMI call failed: power status` | `processutils.py`, `attempts = 10` | 13 |
| deploy validation: `Missing are: ['image_source', 'kernel', 'ramdisk']` | `time.sleep(30)` before the deploy check in the nova ironic driver | 14 |
| neutron: `Requested MTU is too big, maximum is 1500` | patch `_get_network_mtu` validation in the venv | 15 |

Notes on a few:

1. The `delta_rrsyslog` container failure had no clean solution — the workaround is the whole fix: stop and disable `systemd-resolved`, unlink `/etc/resolv.conf`, write a manual nameserver line. The pattern returned in [Zed to Antelope](../zed-to-antelope/index.md), where `systemd-resolved` needed unmasking instead — the resolver is always in the blast radius.

2. First appearance of a ritual: the `ceph-defaults` role's socket check breaks the infrastructure play on estates that run ceph outside OSA's view. The sed (`'s/(.*ceph.*)/#\1/g'` over `setup-infrastructure.yml`) outlived the estate's ceph integration changes — it appears in every note file after this one.

4. The cinder schema wanted every volume typed; history had left deleted rows with `volume_type_id` NULL. `cinder-manage db online_data_migrations` reports zero needed — the check counts only live rows — so the SQL does the rest:

        MariaDB [cinder]> update volumes set volume_type_id="notnull" where status='deleted' and volume_type_id is NULL;
        MariaDB [cinder]> update snapshots set volume_type_id="notnull" where status='deleted' and volume_type_id is NULL;

9. First appearance of the GPFS tax, documented in full in the [Bobcat to Caracal entry](../bobcat-to-caracal/index.md). This run paid it against python3.6 venvs; the last runs paid it against python3.10 — same two moves.

## The rituals that started here

Beyond the table: MTU 9000 in the agent containers (`eth10.ini`) before the neutron run; **one neutron zone per run, the rest excluded with `--limit`** — the blackout-prevention core that every later entry refers back to; the **custom CPU model check** (`EPYC-IBPB,SandyBridge-IBRS,Skylake-Server-IBRS`) after every nova install; "don't forget placement"; the **keepalived watchdog in screen**, in its original form — restart from a sed'd config (`br-vlan` → `br-hpc`), later runs restart from the pre-run backup instead. And the ironic upgrade run with every libvirt compute host excluded from the limit list.

## The aftermath, dated

The note keeps collecting after "UPGRADE DONE" — the same shape every later file inherits:

- **2021-07-20** — the ironic compute container's nova-compute refuses to start (`DBNotAllowed`, §11 above).
- **2021-08-02** — `Could not load 'oslo_cache.etcd3gw': No module named 'etcd3gw'` in nova-metadata: `pip install etcd3gw` into the venv.
- **2021-08-03** — `AMQP server ... is unreachable: Server unexpectedly closed connection`: `rabbit_interval_max = 10` under `[oslo_messaging_rabbit]`.
- **2021-10-09** — `grub-install: not found` from the ironic conductor mid-deploy: the IPA images were older than the nodes deserved — new `ipa-centos8-stable-ussuri` kernel/initramfs uploaded, every node's `deploy_kernel`/`deploy_ramdisk` updated.
- **2021-12-28** — `AMQP server ... is unreachable: <RecoverableConnectionError: unknown error>`: a commented-out `import nova.monkey_patch` in the venv's api `__init__.py` — the note calls it a workaround and does not pretend to know why it works.
- undated, same era — an ironic compute container left without `/etc/nova/nova.conf` after a run: `os-nova-install` re-run with `--limit` on the ironic compute containers; the `instance_info` volume-metadata awk on the utility container rewritten (`$2` → `$4`) after the upgrade changed the volume list output; and the rbd volume type gone public on its own: `cinder type-update --is-public False`.

## Older leftovers in the same note

None — this is where the pile begins. Everything after this file's run that recurs in later notes was born here or in the runs between; the [upgrade trail page](../openstack-trail/index.md) maps which is which.

---

*This saved you a night? I do this for a living: [info@wirt.ee](mailto:info@wirt.ee).*
