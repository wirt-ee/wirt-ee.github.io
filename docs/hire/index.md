---
description: "How to hire Wirt OÜ: what I do, packages, day rates, conditions, proof, and what I refuse. One senior engineer, one engagement at a time."
---

# Hire

One senior engineer. Expensive compared to a junior, cheap compared to the outage.

## What I actually do

**My main focus is deploying new systems.** Designing and building the thing that has not existed yet: a private cloud, a storage cluster, a firewall pair, a backup pipeline, an LLM serving stack. Delivered running, documented on the way out. The [2016 OpenStack birth entry](../logbook/openstack-birth/index.md) is the pattern: devstack to learn, then the real thing, booted in 2016 and still serving. Building new is the work I prefer.

**I upgrade in place, indefinitely.** One OpenStack estate, live-upgraded continuously since 2016. Mitaka onward, same cluster, never rebuilt, all hardware replaced underneath. You will find [the latest ten runs](../logbook/openstack-trail/index.md) in the trail: Ussuri to Dalmatian, 2021 to 2026. Nine release upgrades and one 950-network live migration. Ceph went [jewel to squid by hand](../logbook/ceph-reef-to-squid/index.md), no cephadm. Upgrades are the build work that never ends, and they run on the same discipline: rehearsed path, rollback planned, everything written down.

**Disasters are premium work too.** Triage, salvage, and honesty about what is gone. [The EC disaster entry](../logbook/ceph-ec-data-loss/index.md) is the receipt, start to finish. The rescue rate is the rescue rate.

**What I build, I prove. Including the backup pipelines, if requested.** A backup is a rumour until a restore has been rehearsed. On this estate the restore is rehearsed and the [procedure is published](../reports/storage/rbd-backups/index.md). The pipeline's one known consistency bug is published too. I found it in testing, before it found anyone else. The software was written by an LLM. The architecture and the responsibility are mine.

**When I really have to, I take over systems whose documentation never existed.** The previous admin is gone. The bash history, the cron, the configs and the monitoring remain. I reconstruct how the system actually works and deliver the map. This entire website is that process applied to my own estate. **It is shovel work, and it is priced like one.** I try to avoid it. When I take it, it is premium day rate.

## How it starts

1. **Email [info@wirt.ee](mailto:info@wirt.ee).** What is broken, or what you want built. One paragraph is enough.
2. **Email, again.** That is the whole channel. I work asynchronously and answer properly rather than instantly. If a call ever becomes genuinely necessary, it will be obvious to both of us.
3. **A number and a start month.** Fixed price where the scope is controlled; day rate where the environment is not. If remote hands and DC wiring decide the outcome, nobody should bet fixed. The logbook contains the war story.

## Availability

**One engagement runs at a time. That is the whole operating model.**

Work is asynchronous and deep: a senior engineer undivided, in long uninterrupted slices, at hours that suit the work. A 02:00 upgrade on an empty cluster is a feature, not a compromise. When a slot is taken, the next engagement queues behind it.

## Packages

Indicative, EUR, excluding VAT. Real quotes come by email.

| | What you get | From |
|---|---|---|
| **Build** | Private cloud, storage or firewall cluster, delivered running. | €8,000 |
| **Live upgrade** | Ceph / OpenStack / VyOS upgrade on a rehearsed path, rollback planned. | €2,500 |
| **Managed care** | Monitoring, patching, backup verification. Per cluster, monthly. **Two clusters, ever.** | €900/month |
| **Health audit** | Second opinion on your cluster: failure domains, upgrade readiness, backup truth. Written report. | €1,800 |
| **Rescue** | Broken-cluster triage. Remote, one at a time. | €900/day |
| **Takeover** | The reconstruction described above, delivered as the map plus the runbook. The logbook on this site is what the output looks like. Premium-priced. The calendar and the mood both have to align. | premium day rate |

Day rate, remote: **€600**. Emergency: **€900/day**.

## If it breaks

- Defects in delivered work are fixed without a new invoice, within 30 days of handover. If my upgrade breaks what my upgrade touched, that is my problem.
- Not covered: hardware that dies on its own, problems that predate the work, and changes made by others after handover. Those are new work. Rescue rate if urgent.
- The fixed prices already carry this risk. That is why builds are sized to survive any single part failing, and upgrades run on a rehearsed path.

## Practicalities

Remote-first; on-site in Estonia and the Baltics when the work needs hands. Contracts and invoicing via Wirt OÜ (reg. 16986693). Communication is email. Asynchronous, answered properly rather than instantly. Rescues start when the current engagement closes.

## Proof

Every claim below has a page on this site. Anonymized where the estate requires it. Details on request.

- OpenStack from [its 2016 birth](../logbook/openstack-birth/index.md): devstack, Mirantis Fuel, then a cloud booted inside its predecessor. Live-upgraded ever since. [Ten of those runs are documented](../logbook/openstack-trail/index.md), from Ussuri to Dalmatian, plus a distribution jump underneath.
- Ceph from jewel to squid, by hand, no cephadm. The receipts: [the unrecoverable PG](../logbook/ceph-ec-data-loss/index.md), [five years of scar tissue](../logbook/ceph-scar-tissue/index.md), and [the field kit](../reports/storage/ceph/index.md).
- ~950 production networks migrated from linuxbridge to OVN, in place. [The nine bugs are in the logbook](../logbook/lxb-to-ovn/index.md).
- [Backup pipelines](../reports/storage/rbd-backups/index.md): restore-proven, one known limitation published.
- Serving LLMs in production: [vLLM](../logbook/vllm-serving/index.md), [a LiteLLM proxy](../logbook/litellm-proxy/index.md), and backup software written by an LLM under my architecture.

## What I refuse

So you don't waste an email:

- 24/7 on-call contracts.
- Work that touches the University of Tartu: no selling to it, no bidding against its services.
- My responsibility ends at the hypervisor. No agents inside tenant or customer VMs, not even when an agent would make my own backups more consistent. [The boundary is documented](../reports/storage/rbd-backups/index.md) with its price tag.
- Bluff. If a page on this site claims an outcome, there is a receipt; where the notes end, the claim ends. Expect the same discipline in my reports to you. That includes the words "I don't know yet".
- "Free architecture review" over coffee. Paid audits only.
- Fixed price on environments I cannot reach.
- Builds that cannot survive rebooting any single part. I won't put my name on it.
- Sub-subcontracting. With more than one intermediary, the details that matter (SLAs, fault tolerance, real dependencies) do not survive the chain. Without them there is nothing to build against.
- Simultaneous emergencies. One engagement at a time means one emergency at a time. Attention is not a shared resource.
