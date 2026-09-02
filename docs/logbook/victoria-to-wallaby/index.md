---
date: 2022-06-16
tags: [openstack, openstack-ansible, upgrades, galera]
description: "Victoria to Wallaby on openstack-ansible 23.3.1: the keystone dev-version constraint dance begins, galera checks its own name, and glance forgets its cache."
---

# OpenStack Victoria to Wallaby

Context: the second step of the estate's upgrade trail — victoria → wallaby, openstack-ansible checked out from `stable/wallaby` (23.3.1; the branch, not a tag — the note files learn that lesson one run later). Backup directories dated 2022-06-16. The rituals come from [Ussuri to Victoria](../ussuri-to-victoria/index.md); the walls below are this run's own. Names genericized.

## The run

New in this cycle: the **local CA variables** (`openstack_pki_authorities`, `openstack_pki_service_intermediate_cert_name`) entered `user_variables.yml` — every later note's "added during wallaby cycle" comment points here. A fresh certificate for prod before the run, rabbitmq constraints again; test continued on the old one.

## What bit — quick reference

| The thing you are staring at | Fix | § |
|---|---|---:|
| galera: `The galera_cluster_name variable does not match what is set in mysql` | restart the failed galera containers, recover the state, re-run | 1 |
| keystone venv: `ERROR: Could not find a version that satisfies the requirement keystone` | sed the non-existent dev version in the repo's constraints file | 2 |
| keepalived: watchdog loop fires but the config is wrong | stop/start keepalived, re-run | 3 |
| glance: `PermissionError: [Errno 13] Permission denied: '.' ... no app loaded. GAME OVER` | `chown -R glance:glance /var/lib/glance/cache/` | 4 |
| GPFS cinder-volume down after the venv swap (cinder-23.3.1, py3.8) | the usual two moves | 5 |

Notes on a few:

1. The check compares `galera_cluster_name` in `user_*.yml` against `wsrep_cluster_name` in the running cluster, and refuses to continue on a mismatch. The containers that failed to rejoin cleanly were the tell — restart them, let the cluster settle, re-run the play. The same assertion returns in [Zed to Antelope](../zed-to-antelope/index.md) as the `Fail if cluster is out of sync` variant with its own escape flag.

2. First appearance of a bug that repeats in [Wallaby to Xena](../wallaby-to-xena/index.md) almost verbatim: the constraints file shipped by the repo container pins a **development version that does not exist** (`keystone==19.0.1.dev12`), and pip refuses to resolve it. The fix is a sed against the served constraints file:

        sed -i 's/keystone==19.0.1.dev12/keystone==19.0.0/g' \
          /var/www/repo/os-releases/23.3.1/ubuntu-20.04-x86_64/requirements/keystone-23.3.1-constraints.txt

   The note's own advice for the next time: find a version that actually exists (`pip install keystone==` and read the error) and pin that.

3. The watchdog from the ussuri run restarts keepalived from a sed'd config; this time the sed itself produced a config keepalived would not load. A plain stop/start picked up the correct one — the loop can only restart, it cannot repair.

## Older leftovers in the same note

The tail of this file is the ussuri→victoria aftermath — heat's `EntityNotFound` reboot, the cinder `__DEFAULT__` SQL, the ironic walls — filed once, with the [Ussuri to Victoria entry](../ussuri-to-victoria/index.md#the-aftermath-dated).

---

*This saved you a night? I do this for a living: [info@wirt.ee](mailto:info@wirt.ee).*
