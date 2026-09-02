---
date: 2023-12-05
tags: [openstack, openstack-ansible, upgrades, ironic, rabbitmq]
description: "Yoga to Zed on openstack-ansible 26.5.0: the oldest upgrade note in the trail, and the birthplace of the habits every later run inherited."
---

# OpenStack Yoga to Zed

Context: the oldest note in the estate's upgrade trail — yoga → zed, openstack-ansible `stable/2023.1`'s predecessor, tag 26.5.0, backup directories dated 2023-12-05. Everything filed after this — [Zed to Antelope](../zed-to-antelope/index.md), the [LXB to OVN migration](../lxb-to-ovn/index.md), three more upgrades — inherited habits that were formed here. Names, addresses and endpoint names genericized; errors and commands as they happened.

## Preparation

The discipline already in its final shape: dated directories, `/etc` and the yoga venvs (`*25.*`), per-container `/etc` plus tftpboot for the ironic api containers, `/var/lib/ceph` on the OSD hosts, per-database dumps and the grants export from every galera container, the endpoint list (`endpoint_list_yoga`) from the utility container, the nightly backup script on the backup host.

## The run

Two deviations before the playbooks, same as every later entry: security-hardening commented out of `setup-hosts.yml`, the env.d halt answered with `SKIP_CUSTOM_ENVD_CHECK=true` — the diff, again, one line, `is_metal: false` against upstream's `true`. Plus two things new in zed:

    openstack-ansible "${SCRIPTS_PATH}/upgrade-utilities/define-neutron-plugin.yml"
    openstack-ansible certificate-ssh-authority.yml

A **new certificate for prod before the run** — the rabbitmq constraints demanded it; test continued on the old one. An ancient **octopus ceph apt repo** commented out on prod (`eu_ceph_com_debian_octopus.list`), `systemd-resolved` unmasked. And the infrastructure plays all ran with the upgrade flags and haproxy config skipped — a shape the later runs would abandon for per-play control:

    openstack-ansible unbound-install.yml -e 'galera_upgrade=true' -e 'rabbitmq_upgrade=true' \
        -e 'package_state=latest' --skip-tags haproxy-config

## What bit — quick reference

| The thing you are staring at | Fix | § |
|---|---|---:|
| `'dict object' has no attribute 'distribution'` in container create | re-gather facts | 1 |
| `No file was found when using first_found` | same fix | 1 |
| `lxc_hosts : Build the base image` hangs in debootstrap | disable IPv6 | 2 |
| repo container `systemd_mount : Set the state of the mount` fails | ignore — `Invalid option remount` | 3 |
| GPFS cinder-volume down after venv swap (cinder-26.4.0, py3.8) | the usual two moves | 4 |
| haproxy-install: the cloud is not accessible | restore keepalived from the pre-run backup | 5 |

Notes on a few:

1. Both errors are facts problems dressed as playbook problems — the notes tag them `@yoga` and `@zed`, they hit both cycles. The container-create traceback dies inside `lxc_container_create_dir.yml`, resolving `hostvars[physical_host]['ansible_facts']['distribution']` against a host that has none:

        fatal: [<host>_neutron_agents_container-<suffix> -> {{ physical_host }}]: FAILED! => {"msg": "The task includes an option with an undefined variable. The error was: ... 'dict object' has no attribute 'distribution'"}

   The fix is one line and it fixes both: `ansible all -m setup --tree /tmp/factsetup`, then re-run.

2. Debootstrap hangs with IPv6 on, silently, forever — the process sits there doing nothing:

        /bin/sh /usr/sbin/debootstrap --variant minbase jammy /var/lib/machines/ubuntu-22-amd64 http://archive.ubuntu.com/ubuntu

        net.ipv6.conf.all.disable_ipv6 = 1
        net.ipv6.conf.default.disable_ipv6 = 1
        net.ipv6.conf.lo.disable_ipv6 = 1

3. Dated 2023-12-06, one day into the run: the repo container's mount unit refuses (`Job failed. See "journalctl -xe" for details.`). The journal says `Invalid option remount` — a systemd version quirk, not a real mount problem. Ignored, nothing broke.

## The aftermath: December to February

The note keeps collecting after the run — its last position marker is dated 2024-02-21. Some of the walls below started in earlier runs (the [trail page](../openstack-trail/index.md) maps which); the ones dated here are this run's own.

**RabbitMQ refused to boot at all** — a story that starts in June, during the [Xena to Yoga run](../xena-to-yoga/index.md); what these notes add is the closing lesson: **manual version upgrades break feature flags**, and after every step, `rabbitmqctl --quiet enable_feature_flag all`. End state pinned: erlang 1:26.1.2-1, rabbitmq-server 3.12.10-1.

**nova-compute in `MessagingTimeout`** after the rabbit work — stop/start all rabbitmq and nova-api containers and the nova-compute services.

**nova-compute down after the ironic driver left** — the same fix as the [Xena to Yoga run](../xena-to-yoga/index.md), against nova-26.4.0 this time: `compute_driver = libvirt.LibvirtDriver`, then the module symlinks into the venv.

**`neutron-db-manage` missing mid-play** (`No such file or directory` during the DB contract) — re-run the playbook.

**Ironic, four ways** (dated 2023-12-27):

- tftpd-hpa dies on the config-copy task — comment the task in `ironic_conductor_post_install.yml`;
- `PXE-E79: NBP is too big to fit in free base memory` — `boot_mode:bios` on the node;
- every release change wants the nodes' `deploy_kernel`/`deploy_ramdisk` updated to the new images — yoga UUIDs out, zed UUIDs in, via `openstack baremetal node set --driver-info`;
- the inspector 403 (`Request forbidden by administrative rules`) and `EndpointNotFound` for `baremetal-introspection` — the `ironic_inspector` user created with `_member_`, the sample policy checked.

**radosgw refuses to start** — the packaged unit drops the ceph user flags: `systemctl edit --full radosgw.service`, `ExecStart=... --setuser ceph --setgroup ceph`.

**Post-upgrade checks that earn their minute**, a ritual since 2021: the hypervisor `custom` CPU model list, the nova `enabled_filters` line, GPU flavors and PCI passthrough restored.

And the **keepalived watchdog in screen** — by now restoring from this run's own pre-run backup, the form every later run keeps. The watchdog itself is older: it starts in the [Ussuri to Victoria run](../ussuri-to-victoria/index.md), sed'ing `br-vlan` to `br-hpc` on every restart.

---

*This saved you a night? I do this for a living: [info@wirt.ee](mailto:info@wirt.ee).*
