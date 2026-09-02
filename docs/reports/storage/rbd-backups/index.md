# Backups: RBD volumes, exported and restored

The estate's backup thread, end to end. The lineage: 2011's [LUN-clone DR test](../../../logbook/netapp-dr-test/index.md), the blind RBD-snapshot exports handed to a backup agent (`echo do-tsm-backup` in [the Ceph kit](../ceph/index.md)) — and this page: the mechanism, the logic, and the tool currently doing the work. The mechanism is `rbd export` and `rbd import`; everything else is negotiable. **The destination does not matter** — tape, a spinner on a backup host, object storage, whatever holds the bytes and survives the building. **The snapshot does not have to exist** — `rbd export` is happy to export an entire live volume, inconsistently; the snapshot only buys a frozen source while the volume keeps running, and a lease to release. What is not negotiable: no agent inside any VM, and a backup is not a backup until a restore has been rehearsed. The site's oldest sentence is *"an untested backup is a rumour"*; this page is the sentence taken seriously.

One fact up front, because it is 2026 and honesty is the brand: **the backup software itself was written by an LLM.** My part was the architecture, the complaints, and the testing — which turns out to be the part that matters. The tool is `experimental-rbd-backup` — the name carries its own asterisk, and it is earned: the software works **with or without OpenStack**, because to it a cinder volume is just an RBD image in a pool. OpenStack in the path means keystone-scoped discovery and per-volume-type pools; no OpenStack, and the pool is the whole estate. The Dockerfile builds verbatim from the git checkout, and the only thing passed in is the Ceph release as build arguments. Everything around it — the deployment, the caps, the schedules, the monitoring — is the estate's own.

## The solid logic

Between the blind loops and this pipeline sits the battle tested production setup — a bash script, grown by hand over years. It stays where it lives: written for this landscape, it would be wrong for yours. What transfers is the logic, and the logic is six steps:

1. **Find all VM volumes.**
2. **Snapshot all running VM volumes as fast as possible** — and *running* means *inconsistent*: no agent inside any VM, responsibility ends at the hypervisor, so the snapshot catches the disk mid-write.
3. **Export, `rbd export volume@snapshot`** — as parallel as the backend handles.
4. **Delete the snapshot as soon as possible.** A snapshot is a lease: while it exists, the client cannot delete the volume. Snapshot fast, export, let go.
5. **Copy the exported volume — sparse, if you can — to the safe place.** Tape, TSM, in the era this pattern grew up in; the destination is the only part that has changed since.
6. **Run steps 1–5 in parallel where you can — and keep track of the schedule.** Every volume its own interval, the bookkeeping never lying about what is due.

**Restore:**

1. **Stop the VM.**
2. **Find the volume's `name_id`** — if storage has been migrated, the ID in the database and the image on disk disagree.
3. **Delete the existing RBD image.**
4. **`rbd import` from backup** — the `name_id` looked up from the database if the volume has migrated.
5. **Start the VM. The journal usually replays well.**

Every site gets its own script; nobody gets a different logic. The S3 pipeline below is this same loop with a newer step 5 — diff chains to object storage instead of full images to tape — and the known limitation below is what happens when a step-2 shortcut meets a multi-volume VM.

## The known limitation

Stated before the architecture, because it is the first thing a reader needs: **the snapshots are per-volume, not per-VM.** The snapshot pass walks volumes one by one, so a VM whose application spans several volumes — database data on one, logs on another — has its volumes snapped at different moments: the first at 01:15, its sibling minutes and four thousand volumes later. Each volume's backup is crash-consistent with itself; the *set* is not. Restored together, the application sees a torn state — and a database torn across data and logs is not a backup, it is a corruption with a retention policy.

The precise scope: single-volume VMs are unaffected. Multi-volume VMs need one of three things this tool does not do — application-level quiesce before the snapshot pass (qemu-guest-agent `fsfreeze`), atomic group snapshots, or app-level recovery after restore (a database whose logs are ahead of its data can replay; verify yours). I found this the hard way, testing it; it is the bug I would fix first, and the reason this page's restore-proof claims carry an asterisk. Publishing it anyway, because the alternative is a page that oversells — and overselling backups is how estates end up standing at a `mark_unfound_lost` prompt.

And before anyone asks *why not just install a backup client on every machine*: **our responsibility ends with the hypervisor. NO backdoors.** A multi-tenant estate does not get to install software inside its customers' VMs to make its own backups convenient — not a Tivoli client, not an agent, nothing. The boundary is the product. Unfortunately it also closes the quieting (sync) option: `fsfreeze` would give application-consistent snapshots, but it is an agent in the guest, so for tenant machines it is off the table. Consistency for tenants must therefore come from the hypervisor side — snapshots of a VM's volume set fired back-to-back, as close in time as the control plane allows — or from the tenant's own application-level recovery. Those are all the doors there are.

One more thing this section owes the reader: **the estate solved the timing part before, by hand.** The real-production procedure from the tape era: take the VM, find *its* volumes, fire the snapshot operation on both — as close in time as two commands can be — then dump both files out to tape (Tivoli Storage Manager). Consistency was achieved by a human aiming two snapshots at the same moment, because no tool did it for us. The S3 pipeline has better encryption, better listing and better monitoring than that procedure ever had — and one regression: it forgot the part where a VM's volumes go together. The fix is not a mystery; the old procedure *is* the spec — group the volumes by VM, fire the set back-to-back.

## The flow

Cron on the backup host, five jobs, one pipeline:

    snapshot   01:15 daily   experimental-rbd-backup snapshot   # rbd snap create on every volume
    rotate     01:45 daily   experimental-rbd-backup rotate     # keep only keep_local backup-* snaps
    upload     02:30 daily   experimental-rbd-backup upload     # rbd export-diff → zstd → AES-GCM → S3
    monitor    every 10 min  experimental-rbd-backup monitor refresh  # writes status.json
    prune      04:30 weekly  experimental-rbd-backup prune      # drop old S3 chains past keep_chains

The increments are chains: one `full`, then `diff` entries (`rbd export-diff`), a fresh `full` every `chain_size` snaps — retention `{keep_local: 5, chain_size: 14, keep_chains: 2}`. A volume is a chain away from restoreable at all times, and never more than one full backup away from a fresh chain.

And the economics, stated as a finding rather than a promise: **the storage savings are huge.** A volume's daily footprint in S3 is its diff, zstd-compressed — where the blind-era patterns shipped the entire exported image every run, this stores what changed. The chains bound the rest: one full per `chain_size` snaps, deltas in between, two chains kept. The savings are why the tool earns its keep at estate scale — with the consistency shortcoming stated above.

## The architecture decisions

Each of these was chosen against an alternative, and the reasons are the page's real content:

- **It runs locally on the backup host.** The host reads the local Ceph cluster via `rbd export-diff`, so at backup time there is nothing to orchestrate from anywhere — hence **cron, not a systemd timer**, and no deploy-node involvement at 02:30.
- **Podman throughout, no Docker.** The deploy host builds and pushes to a private registry; the backup host pulls. The image is a versioned artifact, not a build-on-target.
- **Least privilege by default.** The Ceph client key is created read-only (`profile rbd-read-only` style caps); write caps on the pool are added only by an explicit deploy override — the one used when a restore is actually planned.
- **Monitoring without ceremony.** `monitor refresh` writes `status.json` every ten minutes; a volume is *stale* when its newest S3 backup is older than 26 hours. `monitor summary` returns the stale count — `0` means healthy — and the wrapper short-circuits `summary|discover|age` to `jq` over the cached file, so a status check costs no container spawn. Cron also mails root on non-zero exit. Point alerting at one number.
- **Two regions, on purpose** — when OpenStack is in the path. `openstack_region` is the Keystone scope, used only in `clouds.yaml`; `s3.region` is the S3 v4-signing region. They are different values for different protocols, and conflating them is a classic silent failure.
- **The encryption key is irreplaceable.** AES-GCM, a key id plus per-chunk GCM verification, sha256 checked against the manifest on every restore — and **no key rotation in v1**. Lose the key and every backup ever taken is unreadable. It is backed up off-host; the README says so in bold, and so does this page.

## The proof

The unit tests mock `rbd` — which means the tests prove the software, not the backup. The real DR proof is a two-liner in the deploy docs: take a second snapshot+upload so a volume has `[full, diff]`, then restore the chain to a fresh image:

    experimental-rbd-backup snapshot && experimental-rbd-backup upload
    experimental-rbd-backup restore --image volumes/<vol> --output rbd://volumes/restored-<vol>

Restore semantics worth knowing before the fire:

- default restores the **newest** snap in the chain (full + diffs applied forward); `--snap backup-<ts>` restores a point in time (find snap names with `list --image`)
- `--output` accepts an RBD image, a file path, or `-` for stdout — but a file/stdout only works for a single-`full` chain; **diffs require an RBD image to apply against**
- the restored image carries the chain's backup snaps — `rbd snap purge` clears them before use
- true DR — source deleted, same name restored — ends with re-registration if the volume was deleted via the API rather than `rbd rm`:

        rbd rm volumes/<vol>
        experimental-rbd-backup restore --image volumes/<vol> --output rbd://volumes/<vol>
        rbd snap purge volumes/<vol>
        openstack volume manage --host <cinder-host@rbd> --volume-type <type> volumes/<vol>

And the preflight that answers "is everything still reachable" in one command: `experimental-rbd-backup verify-access` — OpenStack, S3, and Ceph, before the first snapshot is ever taken.

## Listing what you have

`list` reads manifests from S3 only — no OpenStack, no Ceph; it works when half the estate is down, which is when you want it to:

    experimental-rbd-backup list                             # one summary line per image
    experimental-rbd-backup list --image volumes/<vol>       # chain breakdown: snap, kind, from, size, age, etag
    experimental-rbd-backup list --json                      # machine-readable

The per-image view marks `── new chain ──` between chains, so the shape of your restore options is visible at a glance.

---

*Backups that restore, proven by restoring them. If your estate's backups have never met their own restore command — [info@wirt.ee](mailto:info@wirt.ee).*

---

*This saved you a night? I do this for a living: [info@wirt.ee](mailto:info@wirt.ee).*
