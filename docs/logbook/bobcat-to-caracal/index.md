---
date: 2025-08-21
tags: [openstack, openstack-ansible, upgrades, rabbitmq]
description: "Bobcat to Caracal on openstack-ansible 29.2.3: quorum queues deferred to keep the downtime sane, the bugs that came anyway, and the stream-fanout aftermath."
---

# OpenStack Bobcat to Caracal

Context: the same estate as the [LXB to OVN migration](../lxb-to-ovn/index.md) (antelope then) — three weeks after [Antelope to Bobcat](../antelope-to-bobcat/index.md), the next step of the same sprint: Bobcat → Caracal, openstack-ansible `stable/2024.1`, tag 29.2.3, in place. Followed by [Caracal to Dalmatian](../caracal-to-dalmatian/index.md) the next spring. The note file also carries Zed-era leftovers from earlier cycles; they are marked as such at the end. Names, addresses and endpoint names genericized.

## The decision before the run

Caracal turns on RabbitMQ quorum queues by default, and the upstream note is blunt about the cost:

> Migration to usage of Quorum Queues results in prolonged downtime for services during upgrade. To reduce downtime you might want to set `oslomsg_rabbit_quorum_queues: false` at this point and migrate to Quorum Queues usage after OpenStack upgrade is done.

That is what we did — quorum queues off for the upgrade, migrated after:

    # /etc/openstack_deploy/user_variables.yml
    oslomsg_rabbit_quorum_queues: false

    # after the upgrade — the migration, not part of it:
    # openstack-ansible openstack.osa.rabbitmq_server --tags rabbitmq-config
    # openstack-ansible openstack.osa.setup_openstack --tags common-mq,post-install

## Preparation

The same discipline as the Dalmatian entry: dated directory, `/etc` and venv configs, per-database dumps from every galera container, the grants export, per-container `/etc` (plus tftpboot for the ironic api containers), `/var/lib/ceph` on OSD hosts, and the endpoint list from the utility container.

## The run

    git checkout 29.2.3
    ${SCRIPTS_PATH}/bootstrap-ansible.sh
    openstack-ansible ${SCRIPTS_PATH}/upgrade-utilities/deploy-config-changes.yml

Two local deviations before the playbooks: security-hardening commented out of `setup-hosts.yml`, and the dead Ubuntu Cloud Archive list removed from every host (`rm /etc/apt/sources.list.d/uca.list`). Then galera and rabbit first, the rest excluded, infrastructure split into per-play runs (`unbound`, `haproxy`, `repo`, `memcached`, `galera`, `rabbitmq`, `utility` — each with the upgrade flags), the galera rolling restart, and the per-service installs.

## What bit — quick reference

| The thing you are staring at | Fix | § |
|---|---|---:|
| stale rabbit/erlang apt pins survive the upgrade | sed the versions in `rabbitmq.pref` | 1 |
| haproxy: `rabbitmq_mgmt-back has no server available` | transient — the play completes | 2 |
| galera connection limit | `max_connections = 9600` | 3 |
| cinder `db sync` dies on `use_quota BOOL NOT NULL` | two UPDATEs, NULL → 0 | 4 |
| GPFS cinder-volume down after venv swap | comment `SUPPORTS_ACTIVE_ACTIVE`, extend rootwrap | 5 |
| nova-scheduler: `AvailabilityZoneFilter could not be found` | config, then re-run | 6 |
| `python3-doca-openvswitch : Conflicts: python3-openvswitch` | remove the doca package | 7 |
| OVN gateway agents appear on controllers | del bridges, disable ovs/ovn services, delete agents | 8 |
| neutron containers keep the *old* keepalived | restart the containers | 9 |

Three bugs that look like they belong here — the keystone LDAP 500 (`set tls_cacertfile or tls_cacertdir`), the endpoint `www.` SAN mistake, the horizon swift `Unauthorized` — happened three weeks earlier, during the [Antelope to Bobcat run](../antelope-to-bobcat/index.md) right before this one. The note files carry them in both piles; the log timestamps (2025-08-01, Aug 04) settle it.

Notes on a few:

4. Old rows have `use_quota` NULL; the Caracal schema wants it set:

        UPDATE volumes SET use_quota = 0 WHERE use_quota IS NULL;      -- 2076 rows
        UPDATE snapshots SET use_quota = 0 WHERE use_quota IS NULL;    -- 16 rows

5. GPFS (Spectrum Scale) after every venv bump — comment out the active-active block in `cinder/volume/manager.py`, let rootwrap find the mmfs binaries (`,/usr/lpp/mmfs/bin` appended to `exec_dirs`), restart cinder-volume.

8. The controllers should not run OVN gateway agents at all — an inventory legacy. On each: delete `br-vlan`/`br-int`, stop and disable `openvswitch-switch`, `ovs-vswitchd`, `ovsdb-server`, `ovn-controller`, `neutron-ovn-metadata-agent`, `neutron-bgp-dragent`, then `openstack network agent delete` the strays.

## The quorum migration and the stream-fanout aftermath

After the upgrade, the flip to quorum queues — and then fanout queues stopped being consumed, cinder first, then nova. What actually fixed it, in order of discovery:

1. **Nova had a full rabbit section override** in `user_variables.yml` — removed it, along with every `nova_rabbitmq_port` line and a stale `ssl: False`.
2. **Unused vhosts deleted** — `/keystone`, `/glance` had no business existing.
3. **`rabbit_stream_fanout = True` was the poison.** Stream fanouts starve consumers without a local replica; pinned off in the api containers' configs, the leftover queues deleted:

        [oslo_messaging_rabbit]
        rabbit_stream_fanout = False

        rabbitmqctl delete_queue cinder-scheduler_fanout -p cinder
        rabbitmqctl delete_queue cinder-volume_fanout -p cinder

4. **Missing replicas starve whole pools** — every consumer routed to a node without a replica tears its pool down. Find them, add them:

        for v in nova octavia neutron heat magnum cinder; do
          for q in $(rabbitmqctl list_queues -p $v name type --no-table-headers | awk '$2=="stream"{print $1}'); do
            rabbitmq-streams stream_status --vhost "$v" "$q" | awk '/writer|replica/{print $2, $4}'
          done
        done
        rabbitmq-streams add_replica "$queue" <node> --vhost "$vhost"

5. **The leftovers got swept** — durable fanout exchanges and stream queues deleted with `rabbitmqctl eval` one-liners, one vhost purged straight from the mnesia directory with the containers stopped (a temporary admin user via the HTTP API helped; it was deleted afterwards).

And the habit that closes the loop — audit what type every queue *actually* is, per vhost:

    for v in $(rabbitmqctl list_vhosts --no-table-headers); do
      rabbitmqctl list_queues -p $v name type --no-table-headers --timeout 60 2>/dev/null \
      | awk -v v="$v" '{c[$2]++} END{printf "%-10s quorum=%s stream=%s classic=%s\n", v, c["quorum"]+0, c["stream"]+0, c["classic"]+0}'
    done

## Keeping the network alive during the neutron run

- **Interface mappings preset**, or the router gateways come up `binding_failed` and the estate blacks out — total, because it is an inventory-generation issue, not a config one:

        # hypervisors
        physical_interface_mappings = flat:<port>,vlan:br-vlan
        # in every neutron agent container's linuxbridge_agent.ini

- **Container MTU to 9000 before the run** (`eth10.ini` sed), or the agents flap.
- **One availability zone per `os-neutron-install.yml` run**, all servers of a zone in the same run; the `--limit` list is generated from the inventory with awk.
- **The "Too many levels of symbolic links" fix is avoided, not applied** — disable the `Add bind mount configuration to container` task instead.
- **A keepalived watchdog in screen** while haproxy/keepalived playbooks run (the loop from the [Dalmatian entry](../caracal-to-dalmatian/index.md)).

## Older leftovers in the same note (Zed era, 2023–2024)

The note file accumulates: these blocks were born in the [Yoga to Zed run](../yoga-to-zed/index.md#the-aftermath-december-to-february) — the rabbit/erlang version history, the nova libvirt symlinks, the four ironic walls, the radosgw unit fix, the post-upgrade checks — and got copied into every upgrade note after it. They are filed once, there.

---

*This saved you a night? I do this for a living: [info@wirt.ee](mailto:info@wirt.ee).*
