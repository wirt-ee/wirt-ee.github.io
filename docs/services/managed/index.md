---
description: "Managed care: monitoring, patching and backup verification for your cluster. Escalation-only paging, two clusters ever."
---

# Managed care

A cluster nobody watches is a cluster that fails quietly.

**What it is:**

- Monitoring with alerts that reach a human. Your stack or ours, Prometheus-class.
- **Escalation-only paging.** Routine noise stays in your dashboards; fires reach a wrist that has answered such pages for ten years. Quiet nights are the design goal, on both ends.
- One scheduled maintenance window a month. Patches applied as if rolling back matters.
- Backup verification: restores are rehearsed, not assumed. An untested backup is a rumour.
- A monthly capacity and health report. You hear about the filling disk from me, not from the outage.

**The monitoring boundary.** Every estate is full of integrations: old, strange, undocumented, wonderful. None of them are my scope, and the rule that keeps it finite: **I monitor the platform, not your applications.** Hypervisors, storage, network, service endpoints, the backup pipeline's one number. Everything visible from outside, everything that *is* the cluster. No agents inside tenant VMs, no backdoors. The same boundary as everywhere else on this site. Your integrations are invisible to me by design. That is a feature of the offer, not a gap in it.

If something of yours must be watched, it has to say **one number from outside**: an endpoint, a port, an OID. One number is one poll target; one poll target is scope. Anything that can only be seen from inside a VM stays inside the VM, and stays yours.

**Why now:** a cluster nobody watches fails quietly. I have carried a voluntary 24/7 on-call for a research cluster for a decade. My own monitoring, my own wrist, ten years of 3am single-issue fixes. Escalation-only paging: routine noise stays in your dashboards, fires reach me. I do not sell compliance paperwork. I run the infrastructure that produces the evidence: logs, metrics, tested recovery.

**What it is not:**

- A pager for every warning.
- A helpdesk for everything with a plug.
- A portfolio product. **Two clusters, ever.** One engineer, undivided attention. I intend to keep it that way.
- An integration project. I watch the floor your strange integrations stand on; the floor is the scope.

**€900 per cluster per month**, fixed. When both slots are full, there is a waiting list. See [Hire](../../hire/index.md).
