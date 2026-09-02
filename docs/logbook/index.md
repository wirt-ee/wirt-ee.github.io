---
description: "The logbook: dated entries from production OpenStack, Ceph, networking, VyOS and on-prem AI work. Reconstructed, sanitized, honest."
---

# Logbook

Reconstructed from production work. Sanitized. The next person to hit the same wall should not be left with one usable reference on the internet.

The OpenStack upgrades are one story: one estate, upgraded in place since 2016, ten of the runs documented (2021 to 2026). [The trail, with the recurring-bug index](openstack-trail/index.md).

- **2026-08-31** — [Ceph Reef to Squid](ceph-reef-to-squid/index.md)
- **2026-08-29** — [vLLM serving](vllm-serving/index.md): on-prem LLMs on GPUs, the production shape
- **2026-07-17** — [LiteLLM proxy](litellm-proxy/index.md): keys, routing, and the nginx config that keeps SSE alive
- **2026-08-11** — [VyOS burn-in period](vyos-three-years/index.md): 1.2.9 to 2026.02, one HA pair, never rebuilt
- **2026-04-15** — [OpenStack Caracal to Dalmatian](caracal-to-dalmatian/index.md): in place, then Ubuntu 24.04 underneath, with the RabbitMQ stream-fanout saga and an OVN split-brain revive
- **2026-03-25** — [Cumulus, NVUE, MLAG](cumulus-nvue-mlag/index.md): the seven bites of the 5.6→5.10 trail
- **2025-08-21** — [OpenStack Bobcat to Caracal](bobcat-to-caracal/index.md): quorum queues deferred, the stream-fanout aftermath
- **2025-07-31** — [OpenStack Antelope to Bobcat](antelope-to-bobcat/index.md): first of three upgrades in twelve months
- **2025-05-06** — [VyOS containers that SNAT](vyos-container-snat/index.md): policy routing marks meet netavark
- **2025-02-07** — [OpenStack LXB to OVN](lxb-to-ovn/index.md)
- **2024-10-10** — [OpenStack Zed to Antelope](zed-to-antelope/index.md): public routing dropped, inventory that would not generate, `_member_` deprecated
- **2023-12-05** — [OpenStack Yoga to Zed](yoga-to-zed/index.md): the oldest note in the trail, where the habits were born
- **2023-11-22** — [Onyx MLAG](onyx-mlag/index.md): lacp-individual: PXE on one end, a bond on the other
- **2023-07-08** — [VyOS 100G AIOM: Power budget exceeded](connectx-100g-optics/index.md)
- **2023-06-05** — [OpenStack Xena to Yoga](xena-to-yoga/index.md): RabbitMQ refuses to boot, the erlang dance begins
- **2022-07-19** — [OpenStack Wallaby to Xena](wallaby-to-xena/index.md): a stray tmp dir poses as a database, cinder's ghost services
- **2022-06-16** — [OpenStack Victoria to Wallaby](victoria-to-wallaby/index.md): keystone's non-existent dev versions
- **2021-08-27** — [FortiGate, VXLAN to OpenStack](fortigate-vxlan/index.md): the edge pair before the VyOS era, and its cookie-fallback API
- **2023-04-04** — [Ceph: scar tissue](ceph-scar-tissue/index.md): five years of incidents, each with a receipt: the noout trap, stalling monitors, scrub errors, the switch loop that fired first
- **2022-05-07** — [Ceph: nautilus to pacific](ceph-nautilus-to-pacific/index.md): two hops, both workarounds labelled "BUG: not using cephadm"
- **2020-10-08** — [Ceph EC pool: the unrecoverable PG](ceph-ec-data-loss/index.md): shards that disagree on version, the countdown to `mark_unfound_lost`, and the salvage that followed
- **2019-12-01** — [Ceph: mimic to nautilus](ceph-mimic-to-nautilus/index.md): the firefly standoff, hammer clients hunted through monitor sessions, kernels identified by trial and error
- **2019-02-18** — [Ceph: luminous to mimic](ceph-luminous-to-mimic/index.md): the upgrade that took cephfs down for fifty-six seconds, and the rank that had to be failed by hand
- **2017-10-05** — [Ceph: jewel to luminous](ceph-jewel-to-luminous/index.md): mons first, the libvirt/libnl trap, and the kernel ladder to EC-pool RBD
- **2016-03-23** — [OpenStack: the birth](openstack-birth/index.md): devstack in one VM, Liberty by hand, Mirantis Fuel, and the OSA cloud booted inside its predecessor
- **2011-05-20** — [NetApp DR test: LUN clones over FCP](netapp-dr-test/index.md): prove the database recovers, then erase every trace
- **2021-07-07** — [OpenStack Ussuri to Victoria](ussuri-to-victoria/index.md): the first note, and the birthplace of most rituals

Entries are dated and honest. Your mileage will vary. The undated write-ups (mechanisms and opinions) live in [Evergreen](../reports/index.md). If an entry saved your night and you would rather not do the next one yourself: [info@wirt.ee](mailto:info@wirt.ee). I do this for a living.
