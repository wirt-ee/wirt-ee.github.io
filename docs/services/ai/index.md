---
description: "Open-weight models run locally, on hardware you own. The model size is decided by the hardware, not by a contract."
---

# On-prem AI

I run open-weight models on local hardware. How big a model you can run is decided by the hardware you have, not by a contract, not by a sales call. It scales from a single workstation to a rack, and the first job is honest arithmetic: what fits, what it costs, what it serves.

Proof that ordinary metal is enough: my own 744B-parameter model serves ~70 tokens/s from repurposed hyperconverged nodes. That is the kind of hardware an OpenStack or Ceph refresh leaves behind. No API bills. No data leaving the rack. No vendor to pull the rug. The serving stack behind that sentence is in the logbook: [vLLM serving, production shape](../../logbook/vllm-serving/index.md).

**What I do:**

- **Size it.** Which models fit your GPUs and RAM. The math is unforgiving; it is cheaper to know before you buy.
- **Serve it.** A serving stack on your metal, tuned to your load and your power budget.
- **Keep it.** Monitoring and an upgrade path. A model you depend on must be upgradable.

**What I don't do:**

- Sell GPUs. I make the ones you have useful.
- Promise a model size your hardware cannot serve. The hardware decides; I just do the measuring first.

Start: [info@wirt.ee](mailto:info@wirt.ee). [How to hire](../../hire/index.md).
