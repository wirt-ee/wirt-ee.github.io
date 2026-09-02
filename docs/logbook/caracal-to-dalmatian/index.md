---
date: 2026-04-15
tags: [openstack, openstack-ansible, upgrades, rabbitmq, ovn]
description: "Caracal to Dalmatian in place on openstack-ansible 30.1.4, then Ubuntu 22.04 to 24.04 underneath it: the bug list, the RabbitMQ stream-fanout saga, and an OVN split-brain revive."
---

# OpenStack Caracal to Dalmatian

Context: the same production estate as the [LXB to OVN migration](../lxb-to-ovn/index.md) — openstack-ansible, ~950 networks, ironic, octavia, GPFS-backed glance, Ceph. This time the jump was Caracal → Dalmatian (OSA `stable/2024.2`, tag 30.1.4), and afterwards an Ubuntu 22.04 → 24.04 distribution upgrade under the whole thing. In place, no rebuild — like every step of [the trail](../openstack-trail/index.md) back to Ussuri in 2021. The predecessor run — [Bobcat to Caracal](../bobcat-to-caracal/index.md), eight months earlier — dress-rehearsed several of the fixes below. Hostnames, addresses and endpoint names below are genericized; errors and commands are as they happened.

## Preparation

The part that lets you sleep during the rest:

    # deploy host: /etc, /opt, the rc file
    dir=20260415; mkdir $dir; cp -r -p /etc /opt $dir

    # per-database dumps from every galera container
    for i in cinder dash glance heat horizon ironic keystone neutron nova \
             nova_api nova_cell0 placement mysql; do
        mysqldump -u root --opt --add-drop-database ${i} > ${i}_${dir}.sql
    done

    # grants survive upgrades only if you save them explicitly
    # (SELECT CONCAT('SHOW GRANTS FOR ...') loop -> MySQLUserGrants.sql)

    # every container's /etc, plus tftpboot for the ironic api containers
    lxc-ls -f | awk '!/NAM/ {print "mkdir -p "d"/"$1"; cp /var/lib/lxc/"$1"/* "d"/"$1}' | sh

    # computes and OSD hosts: /var/lib/ceph, /etc, interfaces (ip a)
    # endpoint list from the utility container:
    openstack endpoint list > endpoint_list_caracal

## The run

    git clone https://github.com/openstack/openstack-ansible /opt/openstack-ansible
    cd $_ && git checkout stable/2024.2        # 30.1.4
    ${SCRIPTS_PATH}/bootstrap-ansible.sh
    openstack-ansible ${SCRIPTS_PATH}/upgrade-utilities/deploy-config-changes.yml

Galera and rabbit first, everything else excluded; then the excluded pair with restarts disallowed:

    openstack-ansible setup-hosts.yml --limit '!galera_all:!rabbitmq_all' -e package_state=latest
    openstack-ansible setup-hosts.yml -e 'lxc_container_allow_restarts=false' --limit 'galera_all:rabbitmq_all'

Then infrastructure (with `galera_upgrade=true rabbitmq_upgrade=true`), the galera rolling restart, and the per-service installs: keystone, barbican, placement, glance, cinder, nova, neutron, heat, horizon — each with `-e package_state=latest`. At the end, restore the public endpoints from the saved list.

## What broke — quick reference

| The thing you are staring at | Fix | § |
|---|---|---:|
| `lxc_hosts : Build the base image` hangs in debootstrap | disable IPv6 on the deploy host | 1 |
| rsyslog container fails the distro assert (bookworm/jammy/noble) | exclude the container | 2 |
| octavia: `'<' not supported between NoneType and str` in lxc config | disable octavia deployment for the run | 3 |
| rabbit/erlang repo: `no longer has a Release file` | remove the dead apt lists | 4 |
| `bash: mysql: command not found` | new names: `mariadb`, `mariadb-admin` | 5 |
| the Caracal-era bugs (use_quota NULLs, GPFS patch, LDAP CA, doca conflict) | same fixes as the [Bobcat to Caracal run](../bobcat-to-caracal/index.md), new venv paths | 6 |

Notes on a few:

5. The MySQL tools were renamed under the new packaging — `mariadb` and `/usr/bin/mariadb-admin extended-status` are what the old habit types as `mysql`.

## RabbitMQ

The quorum-queue migration and its stream-fanout aftermath belong to the predecessor run — the whole saga, including the per-vhost queue-type audit loop, is in the [Bobcat to Caracal entry](../bobcat-to-caracal/index.md). What Dalmatian itself added: the rabbit/erlang apt lists had gone stale (`no longer has a Release file`), and after the distribution upgrade a node that no longer existed had to be forgotten from the cluster (`rabbitmqctl forget_cluster_node`).

## OVN split-brain revive

After the dust settled, the OVN northd cluster split its brain. The revive sequence — wipe all three, seed one fresh 1-node RAFT cluster from the schema, then let the others join:

    # 1. stop: ovn-northd, ovn-ovsdb-server-nb, ovn-ovsdb-server-sb, ovn-central
    # 2. backup + wipe ovnnb_db.db / ovnsb_db.db and their hidden .lock/.snapshot files
    # 3. seed fresh clusters (raft ports 6643 NB / 6644 SB)
    ovsdb-tool create-cluster /var/lib/ovn/ovnnb_db.db /usr/share/ovn/ovn-nb.ovsschema ssl:<node>:6643
    ovsdb-tool create-cluster /var/lib/ovn/ovnsb_db.db /usr/share/ovn/ovn-sb.ovsschema ssl:<node>:6644

    # 4. capture cluster ids — the other nodes join by them
    NB_CID=$(ovsdb-tool db-cid /var/lib/ovn/ovnnb_db.db)

    # 5-6. start the servers; enable the CLIENT listeners with pssl, not ssl
    ovn-nbctl --db=unix:/var/run/ovn/ovnnb_db.sock \
        --private-key=... --certificate=... --ca-cert=... set-connection pssl:6641

Two details that cost hours: the client listeners must be `pssl:` (passive listen), not `ssl:` (active connect) — and SSL options go *before* the command. Then repopulate the northbound DB the same way as during the migration — `neutron-ovn-db-sync-util ... repair` **from a neutron-server container** ([the OVN entry](../lxb-to-ovn/index.md) has why) — start northd, and join the other two nodes with `ovsdb-tool --cid=$NB_CID join-cluster`.

## The distribution upgrade underneath

22.04 → 24.04 under a live OSA cloud, afterwards:

    apt update
    apt dist-upgrade -o APT::Get::Always-Include-Phased-Updates=true
    do-release-upgrade          # "then wait a long long time"

What bit:

- **DNS broke after the release upgrade** — systemd-resolved's config needed hand-fixing before anything name-based worked again.
- **The repo container did not survive** — `lxc-destroy` it, re-run `setup-hosts.yml`, and the collection-style playbooks (`openstack.osa.repo` import in the split infrastructure playbook) needed the import lines edited to match.
- **haproxy config gained an ironic section** the estate did not want — commented out.
- **`Access denied for user 'root'@'localhost'`** in the galera containers — the distro swap lost the client credentials file; restored in `.my.cnf`.
- **Ceph jumped to Squid by accident** — noble ships 19.2.3 and the pinned Reef was gone. Mitigation: follow the ceph upgrade notes deliberately instead of letting apt decide (see the [Ceph entry](../ceph-reef-to-squid/index.md)).
- **cephadm dpkg failure aborts the release upgrade** (`mkdir: cannot create directory '/var/lib/cephadm/.ssh'`). The upgrade still completed; `apt-get remove cephadm` on the affected host afterwards.
- **The OVS bridge config was wiped** on one hypervisor — br-vxlan and the patch ports had to be rebuilt by hand, MTU 9000 included:

        ovs-vsctl add-br br-vxlan
        ovs-vsctl add-port br-vlan patch-to-br-vxlan tag=<vlan> \
          -- set interface patch-to-br-vxlan type=patch options:peer=patch-to-br-vlan mtu_request=9000
        ovs-vsctl add-port br-vxlan patch-to-br-vlan \
          -- set interface patch-to-br-vlan type=patch options:peer=patch-to-br-vxlan mtu_request=9000
        ip link set dev br-vxlan mtu 9000

- **Broken venvs** (`ModuleNotFoundError: No module named 'pip'`): move the poisoned venvs aside and re-run the install playbooks — they rebuild cleanly.
- **A stale rabbit node** that no longer existed: `rabbitmqctl forget_cluster_node`.
- **Project switching broke afterwards** — the note's first diagnostic was the fernet keys, on every keystone host: `sha256sum /etc/keystone/fernet-keys/*`. The trail goes cold there; the check stays because it is the right first question.

## Habits that kept the lights on

- **Neutron upgrades zone by zone**, never all at once — the `--limit` list is generated from the inventory with awk, one availability zone per run, all servers of a zone in the same run.
- **Container MTU preset to 9000** before the neutron run (`eth10.ini` sed), or the agents flap.
- **A keepalived watchdog in screen** while haproxy/keepalived playbooks run:

        while true; do
          test -z "$(systemctl status keepalived | grep running)" && {
            cp /root/backup/etc/keepalived/keepalived.conf /etc/keepalived/;
            systemctl restart keepalived; }
          sleep 1
        done

- **Endpoints are restored from the pre-upgrade list**, not typed from memory — the one-liner reads `endpoint list | grep public` and rewrites IP URLs back to names.

---

*This saved you a night? I do this for a living: [info@wirt.ee](mailto:info@wirt.ee).*
