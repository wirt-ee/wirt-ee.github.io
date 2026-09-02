---
date: 2025-07-31
tags: [openstack, openstack-ansible, upgrades, keystone]
description: "Antelope to Bobcat on openstack-ansible 28.4.2: the first of three upgrades in twelve months — LDAP CA, GPFS for the third release running, and the endpoint SAN mistake."
---

# OpenStack Antelope to Bobcat

Context: the same estate as the [LXB to OVN migration](../lxb-to-ovn/index.md), which had just landed on antelope. Five months later this was the first of three upgrades in twelve months: antelope → bobcat, openstack-ansible `stable/2023.2`, tag 28.4.2 — followed by [Bobcat to Caracal](../bobcat-to-caracal/index.md) three weeks later and [Caracal to Dalmatian](../caracal-to-dalmatian/index.md) the next spring. Names, addresses and endpoint names genericized.

## Preparation

The same discipline as the later entries: dated directory per host class, `/etc` and the antelope venvs (`*27.*`), per-container `/etc` (plus tftpboot for the ironic api containers), `/var/lib/ceph` on OSD hosts, per-database dumps from every galera container, the grants export, the endpoint list. Two additions worth keeping:

- The **nightly backup script** on the backup host runs separate DB dumps — no overlapping-lock constraints with the manual ones.
- A **fresh organization certificate** before the run — the old one was near expiry, and renewing it mid-upgrade is a worse afternoon than either half. (The Ceph on the deploy host also moved 17.2.7 → 17.2.9 first; quincy stays quincy.)

## The run

    git checkout 28.4.2
    ${SCRIPTS_PATH}/bootstrap-ansible.sh
    openstack-ansible "${SCRIPTS_PATH}/upgrade-utilities/deploy-config-changes.yml"

Local deviations, same as every later run: security-hardening commented out of `setup-hosts.yml`, the dead Ubuntu Cloud Archive list removed from every host, `setup-infrastructure.yml` copied to a split variant for per-play runs.

## What bit — quick reference

| The thing you are staring at | Fix | § |
|---|---|---:|
| upgrade halts: `env.d files which override the default inventory layout` | `rm /etc/openstack_deploy/env.d/*` or `SKIP_CUSTOM_ENVD_CHECK=true` | 1 |
| `404 Not Found ... gnupg2` inside containers | `apt-get clean && apt-get update` in every container, one awk loop | 2 |
| galera/rabbit hosts restart mid-run | `--limit` plus `lxc_container_allow_restarts=false` | 3 |
| stale rabbit/erlang pins (3.11.13 / 25.2.3) | sed the versions in `rabbitmq.pref`, re-run | 4 |
| keystone 500: `You need to set tls_cacertfile or tls_cacertdir` | install the LDAP CA, point the domain config at it | 5 |
| cinder: `value of state must be one of: absent, build-dep, fixed, latest, present, got: latest[A` | re-run | 6 |
| GPFS cinder-volume down after venv swap | comment `SUPPORTS_ACTIVE_ACTIVE`, extend rootwrap | 7 |
| nova-scheduler: `AvailabilityZoneFilter could not be found` | config, then re-run | 8 |
| endpoint cert missing the SAN (`www.` prefix mistake) | `openstack endpoint set` per endpoint | 9 |
| horizon `Unauthorized: /api/swift/containers/` | reboot the horizon container | 10 |
| haproxy-install: public IP disappears | restore keepalived config | 11 |

Notes on a few:

2. One loop, all containers — the stale package lists are everywhere, not only where the playbook noticed:

        lxc-ls -f | awk '{print $1}' | grep -v ns_con | grep -v tsm_con | grep -v ubunt \
          | while read l; do lxc-attach -n $l -- apt-get clean; lxc-attach -n $l -- apt-get update; done

5. Keystone against LDAP over TLS fails as a 500 with a `ValueError` in the log — not an auth failure, and it takes the whole CLI with it (`InternalServerError (HTTP 500)`). The domain config (`/etc/keystone/domains/keystone.<domain>.conf`) needs the CA the LDAP server presents:

        [ldap]
        use_tls = True
        tls_cacertfile = /etc/keystone/ssl/ca-bundle.pem
        url = ldap://<ldap-server>

   The cert chain was pulled with `openssl s_client -connect <ldap-server>:636 --showcerts`.

6. The strangest one: cinder's package install dies with `value of state must be one of: absent, build-dep, fixed, latest, present, got: latest[A` — a corrupted `package_state` variable reaching ansible, five retries, then fatal. It never reproduced on the re-run.

7. GPFS after every venv bump — the same two moves as in the [Caracal entry](../bobcat-to-caracal/index.md), by then routine: comment out the active-active block in `cinder/volume/manager.py`, append `,/usr/lpp/mmfs/bin` to rootwrap's `exec_dirs`, restart cinder-volume. The note carries the sed applied to three consecutive venvs (`27.5.1`, `27.6.0`, `28.4.2`) — it is a tax, not an incident.

9.–10. One afternoon, in order: the swift public endpoint got written with an accidental `www.` subdomain the certificate had no SAN for; horizon's swift panel answered `Unauthorized: /api/swift/containers/` with radosgw's `AccessDenied` in the apache log. Per-endpoint `openstack endpoint set` with the correct URL, then a horizon container reboot to clear the stale state.

## What the nova run wants remembered

- **The instances path** lives on GPFS, not `/var/lib/nova/instances` — the config fix is one sed, forgetting it is an outage:

        sed -i 's|/var/lib/nova/instances|/gpfs/cloud/openstack/nova/instances/|g' /etc/nova/nova.conf

- The **custom CPU model** list, or live migration breaks on the first heterogeneous host.
- **GPU flavors and PCI passthrough** restored afterwards — the same post-run check as in the Caracal entry.

## Keeping the network alive

The same three protections as the [Caracal run](../bobcat-to-caracal/index.md#keeping-the-network-alive-during-the-neutron-run), already habit by then: interface mappings preset in every agent container (or the router gateways come up `binding_failed` and the estate blacks out), container MTU to 9000, one availability zone per neutron run — plus the old keepalived still running in the neutron containers until they are restarted (`lxc-stop`/`lxc-start` over `lxc-ls | awk '/neutron/'`).

## Older leftovers in the same note

The tail of the note file is the Zed-era pile born in the [Yoga to Zed run](../yoga-to-zed/index.md#the-aftermath-december-to-february) — the rabbit/erlang history, the nova libvirt symlinks, the ironic walls, the radosgw unit fix, the haproxy-install outage with the keepalived watchdog. It appears in every upgrade note in this trail; it is filed once, there.

---

*This saved you a night? I do this for a living: [info@wirt.ee](mailto:info@wirt.ee).*
