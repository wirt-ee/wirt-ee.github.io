---
date: 2022-07-19
tags: [openstack, openstack-ansible, upgrades, cinder, keystone]
description: "Wallaby to Xena on openstack-ansible 24.3.0: a stray tmp directory poses as a database, cinder's dead rbd services block the api, and galera_use_ssl gets sacrificed."
---

# OpenStack Wallaby to Xena

Context: the third step of the estate's upgrade trail — wallaby → xena, one year after [Victoria to Wallaby](../victoria-to-wallaby/index.md). Backup directories dated 2022-07-19. The checkout lesson lands in this note: `stable/xena` delivered "some non-existent keystone dev6 package", and the run went ahead from the 24.3.0 tag instead. Names genericized.

## Preparation

Same discipline — plus one new wall during the dumps themselves (§1 below): the all-databases `mysqldump` of the galera container failed on a stray directory inside the datadir.

## What bit — quick reference

| The thing you are staring at | Fix | § |
|---|---|---:|
| mysqldump: `Incorrect database name '#mysql50#tmp.9g7ImAkk8C'` | stop mysql, remove the stray tmp dir, start | 1 |
| keepalived: `Truncating auth_pass to 8 characters` — validation fails | comment out the validate task in the role | 2 |
| keystone venv: `ResolutionImpossible` on `keystone==20.0.1.dev8` | sed the dev version in the constraints file — again | 3 |
| keystone `db_sync --check` exits rc=1 after 1:44 | `galera_use_ssl: false` | 4 |
| cinder apt: `eu.ceph.com/debian-pacific ... no longer has a Release file` + UCA i386 warnings | one ceph repo, `ceph_stable_release: pacific` | 5 |
| cinder api: `Service Unavailable (HTTP 503)` in maintenance mode | take it out of maintenance (F9 in haproxy UI) | 6 |
| cinder api: `CappedVersionUnknown: Versioned Objects in DB are capped to unknown version 1.37` | `cinder-manage service remove` the dead rbd services | 7 |
| horizon console: `Refused to frame ... Content-Security-Policy directive "frame-src"` | haproxy `http-response set-header` with the right frame-src | 8 |
| nova: rabbit-backed services dead after the run | stop/start the rabbit containers | 9 |
| libvirtd-tls.socket: `Socket service libvirtd.service already active, refusing` | stop all five units, start them in order, restart nova-compute | 10 |
| GPFS cinder-volume down after the venv swap (cinder-24.4.0) | the usual two moves | 11 |

Notes on a few:

1. A `#mysql50#tmp.9g7ImAkk8C` entry in the datadir is a **directory mysql treats as a database** — old tmp-file debris from a crashed repair. `--all-databases` chokes on it and no dump happens:

        find /var/lib -name "*9g7ImAkk8C"     # /var/lib/mysql/tmp.9g7ImAkk8C
        systemctl stop mysql && rm -r /var/lib/mysql/tmp.9g7ImAkk8C && systemctl start mysql

4. The keystone DB check burns 105 seconds and dies; the galera TLS setup is the reason, and the workaround in the notes is honest about its blast radius: `keystone_galera_use_ssl: false` fixed keystone, **but placement failed with the same DB connection error**, so the whole `galera_use_ssl: false` was set instead. The check itself was fine — the connection was not.

5. The apt state on the api containers was a museum: the dead eu.ceph.com pacific repo, an Ubuntu Cloud Archive entry skipping i386, and — the note's own "wtf" — an attempted **ceph downgrade** while installing cinder packages. The fix is a single ceph repo (`download.ceph.com/debian-pacific`) and `ceph_stable_release: pacific` pinned in `user_variables.yml` so the playbooks stop improvising. This is the incident that ended the estate's trust in playbook-managed package state — the moment behind the takeover told in [the trail](../openstack-trail/index.md): before this run, openstack-ansible's playbooks decided versions on their own. After it, nothing on this estate was installed without a pin with a human's name on it.

7. Two cinder-volume services from 2020, `rbd:` backends on hosts long gone, `XXX` in the service list since January that year — and the new api refuses to boot while they exist:

        cinder-volume    rbd:<host>    nova    enabled    XXX    2020-01-09 ...    1.37

        cinder-manage service remove cinder-volume rbd:<host>   # once per ghost

   The api then came up with a `PermissionError ... GAME OVER` on top — the same glance-style cache ownership problem as [Victoria to Wallaby](../victoria-to-wallaby/index.md) §4, cinder-flavoured.

8. The web console died to a Content-Security-Policy that allowed the wrong frame origin. The fix lives in haproxy, not horizon — the frontend rewrites the header with the console's real origin in `frame-src`. (The same iframe problem returns in the [Antelope to Bobcat](../antelope-to-bobcat/index.md) haproxy restore list.)

10. Dated 2022-08-21, a month after the run: systemd refuses the TLS socket because the service is already up — libvirtd's units have an order, and the order is the fix: stop `libvirtd.socket`, `libvirtd-ro.socket`, `libvirtd-tls.socket`, `libvirtd-admin.socket`, `libvirtd`; start them in the same order; restart nova-compute.

## Older leftovers in the same note

The tail of this file is the wallaby-era and older pile — the victoria walls, the ussuri aftermath — filed once, with [Victoria to Wallaby](../victoria-to-wallaby/index.md) and [Ussuri to Victoria](../ussuri-to-victoria/index.md).

---

*This saved you a night? I do this for a living: [info@wirt.ee](mailto:info@wirt.ee).*
