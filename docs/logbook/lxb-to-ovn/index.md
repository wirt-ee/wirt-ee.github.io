---
date: 2025-02-07
tags: [openstack, neutron, ovn, networking]
description: "Migrating ~950 production OpenStack networks from linuxbridge to OVN on openstack-ansible antelope 27.5.1: what broke, nine times, and the fixes."
---

# Linux bridge to OVN

Context: production OpenStack on openstack-ansible "antelope" 27.5.1 — put there by the [Zed to Antelope upgrade](../zed-to-antelope/index.md) the autumn before — neutron ML2 with linuxbridge agents, migrated in place to OVN. About 950 networks, 370 routers, 5400 ports. Hostnames below are genericized; everything else is what I ran and what it printed. The related, older write-up — linux bridge to Open vSwitch on the same estate — is in [Evergreen](../../reports/network/lxb2ovs/index.md). The same estate's later [Caracal to Dalmatian upgrade](../caracal-to-dalmatian/index.md) hit OVN again — a split-brain revive, with the sync rule from bug 3 confirmed once more.

## Preparation

    # deploy host: full /etc and /opt backup
    dir=20250207
    mkdir $dir
    cp -r -p /etc $dir
    cp /usr/local/bin/openstack-ansible.rc $dir
    cp -r -p /opt $dir

    # galera containers: stopped and archived on all three infra hosts
    lxc-stop -n infra3_galera_container-<suffix>
    lxc-stop -n infra2_galera_container-<suffix>
    lxc-stop -n infra1_galera_container-<suffix>
    tar czf infra1_galera_container-<suffix>_${dir}.tar.gz /var/lib/lxc/infra1_galera_container-<suffix>

    # neutron venv configs on controllers and hypervisors
    mkdir -p ${dir}/openstack/venvs/27
    cp -r -p /openstack/venvs/*27.*/etc ${dir}/openstack/venvs/27/

    # keepalived, haproxy, endpoint list
    cp /etc/keepalived/keepalived.conf /etc/keepalived/keepalived.conf_28062025
    cp /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg_28062025
    openstack endpoint list > openstack_endpoint_list_28062025

## The switch

    # remove the neutron agent container inventory
    /opt/openstack-ansible/scripts/inventory-manage.py -G | awk -F '|' '/neutron_agents_cont/ {print $3}' | while read l; do /opt/openstack-ansible/scripts/inventory-manage.py --remove-item "${l}"; done

    # remove neutron config overrides; comment out tunnel_bridge and
    # the neutron_linuxbridge_agent group_binds in openstack_user_config.yml
    vim /etc/openstack_deploy/user_variables.yml
    vim /etc/openstack_deploy/openstack_user_config.yml
    mkdir /etc/openstack_deploy/group_vars
    vim /etc/openstack_deploy/group_vars/network_hosts      # OVN variables

    # deviation from the guides: northd runs in a container here, so
    rm /etc/openstack_deploy/env.d/*

    # stop and disable all neutron agent containers
    lxc-ls -f | grep neutron_agent | awk '{print $1}' | while read l; do lxc-stop -n $l; done
    sed -r -i 's|(lxc.start.auto)|#\1|g'      /var/lib/lxc/*_neutron_agents_container-*/config
    sed -r -i 's|(lxc.start.delay)|#\1|g'     /var/lib/lxc/*_neutron_agents_container-*/config
    sed -r -i 's|(lxc.group = onboot)|#\1|g'  /var/lib/lxc/*_neutron_agents_container-*/config

    # stop the host services
    for i in neutron-linuxbridge-agent neutron-l3-agent neutron-dhcp-agent neutron-metadata-agent; do
        systemctl stop $i; systemctl disable $i
    done

    # delete the unneeded interfaces
    for i in $(ip -br link show | grep brq | awk '{print $1}'); do ip link delete $i; done
    for i in $(ip -br link show | grep vxlan- | awk '{print $1}'); do ip link delete $i; done
    ip -br link show | grep "br-vlan\." | awk '{print $1}' | sed 's/@.*//g' | while read l; do ip link del $l; done

    # delete the agent entries from neutron (XXX = your host pattern)
    for i in $(openstack network agent list | grep XXX | awk '{print $2}'); do openstack network agent delete $i; done

    # playbooks (ironic computes excluded)
    openstack-ansible setup-hosts.yml      --limit '!ironic-compute_all'
    openstack-ansible os-nova-install.yml  --limit '!ironic-compute_all'
    openstack-ansible os-neutron-install.yml --limit '!ironic-compute_all'

## What broke, nine times — quick reference

| The error you are staring at | Fix | No.
|---|---|---:
| `ValueError: :6642: bad peer name format` | add `network-northd_hosts` stanza to `openstack_user_config.yml` | 1
| northbound DB empty after install | `neutron-ovn-db-sync-util ... repair` from the neutron-server container | 2, 3
| `ovn-nbctl: database connection failed` | not dead — run sync from the cluster leader, inside the neutron-server container | 3
| ports bound as `bridge`, segments still `vxlan` | two SQL updates: `vif_type`, `network_type` | 4
| leftover `br-provider`, `eth12` | `ovs-vsctl del-br`, rerun `neutron-install.yml` | 5
| gateway port `binding_failed`, traffic fine | heals on `openvswitch-switch` restart; SQL update for stuck records | 6
| HA gateway ping stops with `ovs-vswitchd` | where the gateway actually lives | 7
| `No tunnel endpoint found for HA chassis` (cr-lrp port) | HA port cleanup | 8
| OVN agents on the wrong hosts | stale `network_hosts` in config — remove, stop, disable | 9
| `NeutronDbObjectDuplicateEntry: ProviderResourceAssociation` | `UPDATE ... SET provider_name = 'ovn' WHERE provider_name = 'ha'` | cleanup

## What broke, nine times

1. **neutron-server would not start.** `ValueError: :6642: bad peer name format`. The `network-northd_hosts` stanza was missing from `openstack_user_config.yml`. Add it.

2. **Northbound DB empty after install.** Sync from the neutron-server container:

        neutron-ovn-db-sync-util --config-file /etc/neutron/neutron.conf \
            --config-file /etc/neutron/plugins/ml2/ml2_conf.ini --ovn-neutron_sync_mode repair

3. **`ovn-nbctl show` claimed the databases were dead.** They were not. The sync only works from the cluster leader, and it has to run inside the neutron-server container — not from a controller shell. neutron-server runs the same repair code itself ([launchpad 1689880](https://bugs.launchpad.net/neutron/+bug/1689880)).

4. **Old port bindings.** Two updates on the cluster database:

        update ml2_port_bindings set vif_type='ovs' where vif_type='bridge';
        update networksegments set network_type='geneve' where network_type='vxlan';

5. **Leftover bridges `br-provider` and `eth12`.** `ovs-vsctl del-br` both, rerun `neutron-install.yml`.

6. **Router gateways: `binding_vif_type | binding_failed` — but traffic worked.** OVN implements the gateway as flows; the binding record heals itself when `openvswitch-switch` restarts on the port's host. For a port that stays stuck, the same update as in (4) with the full `vif_details` JSON for that `port_id` fixes the record.

7. **A router HA gateway stopped answering ping** while `ovs-vswitchd` was stopped on its `binding_host_id`. Observation, not a fix — but it tells you where the gateway actually lives.

8. **`ovn-controller: No tunnel endpoint found for HA chassis in HA chassis group of port cr-lrp-<uuid>`** in the controller logs, 12 February. Related to (7); resolved with the HA port cleanup below.

9. **OVN agents came up on controllers** that should not run them — a leftover `network_hosts` definition in `openstack_user_config.yml`. Fix: remove the stale definition, then on those hosts stop and disable `ovn-controller`, `neutron-ovn-metadata-agent`, `ovn-host`, `neutron-bgp-dragent`, `openvswitch-switch`, `ovs-vswitchd`, `ovsdb-server`, and delete their `br-vlan` and `br-int`.

## Cleanup

The linuxbridge HA routers left 1092 `router_ha_interface` ports behind:

    openstack port list --device-owner network:router_ha_interface | grep 169.254 | awk -F '|' '{print $2}' | while read l; do openstack port delete $l; done

Halfway through, neutron refused:

    NeutronDbObjectDuplicateEntry: Failed to create a duplicate
    ProviderResourceAssociation: for attribute(s) ['resource_id']

The records still pointed at the `ha` provider:

    UPDATE neutron.providerresourceassociations SET provider_name = 'ovn' WHERE provider_name = 'ha';
    Query OK, 582 rows affected (0.027 sec)

After that, the deletions went through.

## Verify

    echo "Neutron networks: $(openstack network list --format value | wc -l)"        947
    echo "Neutron routers: $(openstack router list --format value | wc -l)"          373
    echo "Neutron ports: $(openstack port list --format value | wc -l)"             5454
    echo "Security Groups: $(openstack security group list --format value | wc -l)" 2551
    echo "Security Group Rules: $(openstack security group rule list --format value | wc -l)"  6936

    echo "Logical Switches: $(ovn-nbctl list Logical_Switch | grep '^_uuid' | wc -l)"           947
    echo "Logical Switch Ports: $(ovn-nbctl list Logical_Switch_Port | grep '^_uuid' | wc -l)" 4975
    echo "Logical Routers: $(ovn-nbctl list Logical_Router | grep '^_uuid' | wc -l)"            373
    echo "Logical Router Ports: $(ovn-nbctl list Logical_Router_Port | grep '^_uuid' | wc -l)" 1836
    echo "Port Groups: $(ovn-nbctl list Port_Group | grep '^_uuid' | wc -l)"                   2552

Networks map to logical switches one to one, routers to logical routers. After cleanup:

    ovn-nbctl list acl | wc -l        111285
    ovn-sbctl lflow-list | wc -l      149752

## References

- [OSA OVN configuration](https://docs.openstack.org/openstack-ansible-os_neutron/latest/app-ovn.html)
- [Migrating linuxbridge to OVN — Jim Denton](https://www.jimmdenton.com/migrating-lxb-to-ovn/)
- [What is OVN — Ubuntu](https://ubuntu.com/blog/data-centre-networking-what-is-ovn)

---

*This saved you a night? I do this for a living: [info@wirt.ee](mailto:info@wirt.ee).*
