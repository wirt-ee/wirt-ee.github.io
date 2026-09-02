---
date: 2023-06-05
tags: [openstack, openstack-ansible, upgrades, rabbitmq]
description: "Xena to Yoga on openstack-ansible 25.3.2: the run where RabbitMQ refused to boot at all — the start of the erlang version dance."
---

# OpenStack Xena to Yoga

Context: the fourth step of the estate's upgrade trail — xena → yoga, openstack-ansible tag 25.3.2, backup directories dated 2023-06-05. The note's tail carries the older walls as usual; what is native here is one big story: **RabbitMQ would not boot at all**, and the fix pattern that every later run inherits was invented in the middle of it. Names genericized.

## What bit — quick reference

| The thing you are staring at | Fix | § |
|---|---|---:|
| rabbit: `BOOT FAILED` — `cuttlefish_escript:parse_and_command/1 ... re-compile this module with an Erlang/OTP 25 compiler` | Cloudsmith repos, let ansible manage the pins | 1 |
| nova-compute in `MessagingTimeout` after the rabbit work | stop/start the rabbit and nova-api containers, nova-compute | 2 |
| nova-compute down after the ironic driver left (nova-25.3.2) | `compute_driver = libvirt.LibvirtDriver` + the libvirt symlinks | 3 |
| GPFS cinder-volume down after the venv swap (cinder-25.3.2) | the usual two moves | 4 |
| `neutron-db-manage` missing mid-play (`No such file or directory` during the DB contract) | re-run the playbook | 5 |
| haproxy-install: public IP disappears | keepalived config fix | 6 |

Notes on a few:

1. Dated 5-Jun-2023 — the run's own first day. The packaged erlang could not load the packaged rabbitmq's scripts:

        beam/beam_load.c(551): Error loading function cuttlefish_escript:parse_and_command/1: op put_tuple u x:
          please re-compile this module with an Erlang/OTP 25 compiler

   The repo offered only the same ancient pair (erlang 25.0.4-1, rabbitmq-server 3.8.2-0). The way out, in the order the notes found it: add the Cloudsmith repos for erlang and rabbitmq-server by hand, then let the apt pin preferences manage the versions from there — stepwise, `3.9.29` → `3.10.5` → `3.11.x`, because each rabbitmq version wants a minimum erlang. The aftermath of this dance — the feature-flags lesson and the pinned end state — is filed with the [Yoga to Zed run](../yoga-to-zed/index.md#the-aftermath-december-to-february), where the notes finish it.

3. First appearance of the symlink fix: the nova venv does not see the distro's compiled libvirt modules, so the ironic-flavoured compute container will not start. `compute_driver` back to `libvirt.LibvirtDriver`, then the module links into the venv — here four files, later runs five.

## The post-run restore list

This run's note writes down the restore checklist in its near-final shape: haproxy config for the object store, ironic images and the exporter container; the public endpoints replayed from the saved `endpoint_list_xena`; the radosgw backends restarted; the `enabled_filters` line; GPU flavors and PCI passthrough restored through the `hpc-nova-pci` playbook; and a `PXE-E79: NBP is too big to fit in free base memory` node calmed with `boot_mode:bios`.

The watchdog also evolved here: it now restores keepalived from **this run's own pre-run backup** instead of a sed'd config — the sed variant had already bitten in [Victoria to Wallaby](../victoria-to-wallaby/index.md) §3.

## Older leftovers in the same note

The tail of this file is the older pile — the xena and wallaby walls, the ussuri aftermath — filed once with [Wallaby to Xena](../wallaby-to-xena/index.md) and its predecessors.

---

*This saved you a night? I do this for a living: [info@wirt.ee](mailto:info@wirt.ee).*
