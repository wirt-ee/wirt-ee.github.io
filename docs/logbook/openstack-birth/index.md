---
date: 2016-03-23
tags: [openstack, devstack, mirantis, fuel, openstack-ansible, neutron]
description: "How the estate's OpenStack was born: devstack in one VM, Liberty by hand, Mirantis Fuel, and the move to openstack-ansible — the new cloud bootstrapped inside the old one."
---

# OpenStack: the birth

Spring 2016. The estate's OpenStack — the one that would later walk [the ten-run upgrade trail](../openstack-trail/index.md) — did not start as a cloud. It started as a single virtual machine learning to be one. The notes span the whole spring; the snapshot is dated 30-08-2016. The first timestamp is 23-03-2016.

## The single VM

Devstack, one host, `stack.sh`:

    stack.sh completed in 3568 seconds.

An hour, and the machine offers Horizon, Keystone on :5000, and the default users admin and demo. That is the whole first lesson: it works, on one box, with four passwords in `local.conf`.

The second lesson came from the images. Building one by hand — cloud-utils, cloud-init, `console=ttyS0` into the grub cmdline — is marked in the notes, in caps, **NOT WORKING**. The prebuilt CentOS GenericCloud qcow2 won. And the third lesson: `scp` of a qcow2 consumes all thin-provisioned space — check what is left before uploading images.

## Liberty, by hand

Three nodes — controller, network, compute — CentOS, RDO Liberty packages, and a configuration management system called `sed`:

    sed -r -i 's|#(servers = localhost:11211)|\1|g' /etc/keystone/keystone.conf
    sed -r -i 's|#driver = sql|driver = memcache|g' /etc/keystone/keystone.conf

The notes say it plainly, translated: *the sql ones were done by hand, with sed.* MariaDB, rabbitmq, keystone, glance — each service un-commented into existence. The scars from that week:

- **glance-api cannot write to /var/lib/glance/images/** — SELinux. The fix was a policy module built from the denial: `audit2allow`, `semodule`. The notes carry no anger, just the module.
- **a 32G disk added for `/var/lib/glance/images/`** — and do not forget the fstab entry.
- **NB! mysql setting: controller must be localhost** — written down because it bit once.
- Neutron's manual has a rhythm the notes record as a warning to self: *"following steps are not concurrent — RTFM."* The order of operations in Neutron is the documentation.
- The first architecture decision worth its own line: **DVR vs L3 HA** — the notes weigh them against the scenario docs and choose with performance in mind, not just redundancy.

## Mirantis & Fuel: cloud 01

Then the estate stopped being a science project and became **cloud 01**: Mirantis OpenStack, Fuel at `:8443`, PXE boots from the management dhcpd, and opinions about where things belong — ceph monitors on the controllers, 60 GB `/var` on computes because nova snapshots land there first.

Fuel 8.0 wore its health as a container count:

    ...wait until ('puppet apply' is over) everything is started up ~15 min after boot
    and (docker ps | wc -l) == 12      # MOS8.0 only

Twelve containers, or something is wrong. Fuel 9.0 deleted the containers entirely — and introduced [a bug](https://bugs.launchpad.net/fuel/+bug/1596622) of its own.

The LDAP story is the emblem of the Fuel era: the estate's users lived in an internal LDAP, so the LDAP plugin went in (`fuel plugins --install ldap-2.0` → `ldap-3.0` for 9.0), and when the fuel-master still could not reach the server, the notes record what they call a *docker prank*: one `ip route add` inside the master, and the containers could see the LDAP. Around it, iptables surgery by line number — find the rule, insert above it, `iptables-save`, because the fuel-master's firewall is real even when the docs pretend otherwise.

And the workarounds that stay with you:

- **swift restarting constantly** ([bug 1587047](https://bugs.launchpad.net/fuel/+bug/1587047)) — fixed by two echo lines adding empty `[container-reconciler]` and `[object-reconstructor]` sections to the swift configs. An upstream packaging bug, patched from a shell.
- **the HA health check failing** — patched in place, in `fuel_health`'s own python: teach `test_mysql_status.py` which nodes are database nodes.
- **autoscaling check timing out** — timeout doubled in the test source, and a `wc_notify --insecure` line adjusted in the wait-condition yaml.

Fuel's own tests lied about Fuel; the estate's notes are the corrections, kept because a green dashboard that is patched to be green is worse than a red one.

The Fuel CLI battery that ran the place: `fuel env`, `fuel node list`, `fuel notifications`, `fuel task` — and, before every change, `fuel --env 1 network download` and `settings download`, because the Fuel database can only be trusted as far as its last backup.

## OpenStack-Ansible: the new cloud inside the old one

The move to openstack-ansible was not a rebuild on new iron. It was stranger and better: **the OSA estate was booted as volumes inside the existing cloud.** Cinder carved the future out of the present:

    cinder create 100 --display-name infra1   --image-id <uuid> --availability-zone nova
    cinder create 200 --display-name compute1 --image-id <uuid> ...
    cinder create 50  --display-name log1 ...
    cinder create 10  --display-name ceph-node1 ... ; cinder create 100 --display-name ceph-osd1 ...

Three infra nodes, two computes, one log host, three ceph nodes and a ceph-admin — all of them `nova boot --boot-volume` with pre-created Neutron ports, one per OSA bridge: `br-vlan`, `br-mgmt`, `br-vxlan`, `br-storage`. The notes carry the whole `boot()` shell function that assembles those `--nic port-id=` lists from `neutron port-list` — infrastructure as a bash loop, and the warning that the OSA networks script is to be run **ONLY once**, because it is not idempotent and neither is regret.

One aio node (`m1.xlarge`, a multi-fixed-IP port) rehearsed the whole play first. Then the estate proper: the cloud that the next ten years of upgrades would happen to, born as tenants of its predecessor, on the predecessor's storage.

Ceph came along the same way — deployed through the OSA roles, runnable tag by tag from the playbooks (`os-glance-install` with `--tags ceph`), with the estate's first cluster exercised separately: one monitor, two OSDs, in the notes before it was ever production.

---

*Ten upgrades later the trail ends at Dalmatian. The birth is this entry — [info@wirt.ee](mailto:info@wirt.ee) if your estate is at the start of its own.*
