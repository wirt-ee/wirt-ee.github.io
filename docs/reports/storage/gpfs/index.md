# GPFS: Spectrum Scale

The parallel filesystem behind the estate's HPC years — IBM Spectrum Scale, still GPFS to everyone who ran it. NSD servers, CES protocol nodes, storage pools and policies, and at the bottom the declustered arrays where the disks actually live. GPFS is documented by IBM the way a cathedral is documented by its architect: completely, and unreadably. This is the operator's cut. Hostnames are placeholders; the benchmark and error output are real.

GPFS also served one tour of duty it was never built for: **after the Ceph EC crash, it stood in as VM storage for a while.** The OpenStack volumes moved onto it — hence the `volume-%` tiering rules in the policy section below, migrating cinder images between its SSD and spindle pools — and the notes from that era are full of dd speed duels, GPFS against RBD, to see if the stand-in could hold the line. It could not forever: GPFS was built for an HPC cluster's throughput, not for keeping stable VMs alive. The interlude ended, Ceph — replicated pools only, per the [EC retrospective](../../../logbook/ceph-ec-data-loss/index.md) — took the VMs back, and GPFS went home to the workload it was designed for.

GPFS has appeared on this site before, sideways — the interlude above, and the storage arithmetic it forced. This page is where those references lived all along.

## The speed duels

The interlude was measured, not assumed — the notes carry the report generator that settled whether the stand-in could hold the line, GPFS against RBD, dd samples from both pasted into one CSV:

    gpfs=<host>; rbd=<host>; for i in ${gpfs} ${rbd}; do
      ssh root@$i 'ls dd-stat/ | sort -n | while read l; do cat dd-stat/$l; done
        | grep bytes | rev | cut -f 2 -d " " | rev' > /tmp/${i}
    done && paste /tmp/${gpfs} /tmp/${rbd} | tail -n 72 > /tmp/report.csv && libreoffice /tmp/report.csv

Both stores dumping dd-stat samples on schedule, one column each, read in a spreadsheet — the stand-in was benchmarked against the incumbent before anyone trusted it, and the duel's verdict is the interlude's ending: GPFS went home to the HPC cluster.

## The state battery

    mmlscluster                                # the cluster, at a glance
    mmgetstate -aLs                            # every node's GPFS state
    mmlsmgr                                     # who is cluster manager, per-FS manager
    mmlsfs <fs>                                 # filesystem parameters
    mmlsdisk <fs> -L                            # disks, with failure group detail
    mmlsnsd ; mmlsnsd -M                        # NSD servers and device mapping
    mmdf <fs>                                   # capacity, per pool, per NSD
    less /var/adm/ras/mmfs.log.latest           # where GPFS explains itself
    mmdiag --waiters ; mmdiag --deadlock ; mmdiag --network
    mmnetverify

Node-level health, with reasons attached:

    mmhealth node show
    Node status:    DEGRADED
    Component      Status        Reasons
    GPFS           DEGRADED      csm_resync_needed
    NETWORK        FAILED        ib_rdma_ports_undefined
    FILESYSTEM     DEGRADED      unmounted_fs_check(hpchome)

A node can be DEGRADED for eighty days and the cluster will not mention it unless asked. `mmhealth event show <reason>` unpacks each one.

One config worth knowing exists at all: **deadlock overload detection is off by default** — a user can hold files for more than five minutes and nobody is told. `deadlockOverloadThreshold 500` turns the detector on; `mmdiag --waiters` then has something to report.

## Node classes and per-class tuning

    mmcrnodeclass nc_cloud -N node1,node2,node3,node4
    mmchconfig pagepool=16G -i -N nc_cloud        # 4G -> 16G, live

The pagepool is the read cache; maxFilesToCache the metadata cache; `dioSmallSeqWriteBidding`-style knobs exist for VM writeback workloads — the notes carry the last two marked **NOT TESTED**, and they stay marked.

## NSD surgery

Every disk joins through a stanza; the stanza is the source of truth:

    %nsd: device=dm-92
           nsd=f2_g16_r6_hdd
           servers=nsd1,nsd2
           usage=dataOnly
           failureGroup=2
           pool=dataPool

    mmcrnsd -F stanza            # define
    mmadddisk <fs> -F stanza     # add to filesystem
    mmchdisk <fs> change -F stanza   # e.g. spindles from dataAndMetadata to dataOnly
    mmrestripefs <fs> -r         # rebalance afterwards — always afterwards

Two lessons recorded the hard way:

- **The enlargement that did not work**: `./spectrumscale nsd add` from the installer — failed. The stanza-and-`mmcrnsd` path worked. And *NB! use the long names* — short NSD names collide in ways that cost an afternoon.
- **The deletion that leaves ghosts**: the `spectrumscale nsd delete` path can leave disks visible in `mmlsnsd` that exist only in the installer's world. The notes carry the cleanup in caps, translated: *you must ALSO migrate the files off the disk being deleted first* — `mmdeldisk <fs> <nsd>` then `mmdelnsd <nsd>`.

GPFS sees only `dm-*` device names — making it use friendly multipath aliases is documented and **does not work**; copy `/usr/lpp/mmfs/samples/nsddevices.sample` to `/var/mmfs/etc/nsddevices` and accept dm names, or fight forever. After a reboot, metadata disks can stay down until told:

    mmlsdisk infra -M ; mmlsnsd -f storage -X
    mmchdisk storage start -d "nsd_meta1;nsd_meta2"

And before touching block devices on a manager node, move the managers — `mmchmgr <fs> <node>` and `mmchmgr -c <node>` — because the node you are about to reboot is probably holding the cluster together.

## Metadata to SSD, the full recipe

The migration that keeps a filesystem serving while its metadata moves to flash:

1. add `metadataOnly` SSD NSDs (`mmcrnsd`, `mmadddisk`)
2. `mmrestripefs <fs>` — metadata redistributes onto SSD
3. change the spinning NSDs to `dataOnly` (`mmchdisk change`)
4. `mmrestripefs <fs> -r` again

Metadata replication is its own knob: `mmchfs <fs> -m 3`, restripe, `mmchfs <fs> -m 2`.

Restriping has a thread budget, and it refuses rather than degrade:

    mmrestripefs: The total number of PIT worker threads of all participating nodes
    has been exceeded to safely restripe the file system. ... cannot exceed 31.

Reissue with fewer nodes (`-N`) or lower `pitWorkerThreadsPerNode`. And one honesty note from the field: a per-file `mmrestripefile -b` on a large disk image *made it slower than before the migration* — restriping is not always progress.

## Performance reality: RDMA or nothing

`nsdperf`, client to NSD server, 120 seconds, 4M buffers:

    RDMA on:   write 1670 MB/s, read 1800 MB/s
    RDMA off:  write  247 MB/s, read  542 MB/s

The estate's InfiniBand was not decoration; it was a 3–6× multiplier, and the health check that proves verbs still work belongs in node verification:

    /usr/lpp/mmfs/bin/mmfsadm test verbs conn

Also caught in the field: a node drifting badly on clock — root cause a missing HPET entry in the ACPI table; `acpi=off` on the kernel cmdline made time honest again.

## The cluster kill

One line in the notes, translated: *I took the cluster down with -9 while the filesystem was mounted.* What follows:

    mmgetstate
       3      <host>    down
    runmmfs
    runmmfs: GPFS is waiting for mmdelfs

The daemon refused to come back because it remembered an unfinished filesystem deletion. The recovery notes point at IBM's problem-determination flow and a reboot. Worth knowing before you ever reach for `kill -9`: GPFS forgives many things, but not being interrupted mid-thought.

## CES: NFS and Samba at the edge

Protocol nodes are a cluster of their own:

    spectrumscale config protocols -f cesshared -m /ibm/esimene/cesshared
    spectrumscale enable nfs
    spectrumscale config protocols --export-ip-pool <ips>
    mmchconfig cesSharedRoot=/ibm/esimene/cesshared
    mmchnode -N <node> --ces-enable
    spectrumscale deploy ; mmces state show ; mmces service list -a

NFS exports, with the client spec that matters:

    mmnfs export add /gpfs/<host>/nfs/cloud/<share> \
      --client "<ip>(Access_Type=RW,Squash=root_squash,SecType=sys,Protocols=3:4)"
    mmnfs export change <path> --nfschange "<ip>(Access_Type=RW)"
    mmnfs export change <path> --nfsremove <ip>
    showmount -e <ces-node>

Field notes from CES, kept honest:

- the ganesha package conflicts with a system `libntirpc` — remove the distro one, install `nfs-ganesha-gpfs`, then `mmces service enable nfs`
- a ganesha.nfsd that will not start was fixed with `mmces service disable/enable nfs` — **which silently deleted the export**; re-add it
- Samba broken by an AD change: the domain had three A records and one of them lied. The fix was pinning the working DC in `/etc/hosts`, `net ads testjoin`, and — for the Windows client — editing `hosts` via notepad *run as administrator*, plus a logoff/logon. The notes call it, deadpan, "such magic in Windows"

Samba shares with inherited group ACLs:

    chmod g+s /gpfs/hpc/samba/agvr
    mmsmb export add AGVR /gpfs/hpc/samba/agvr
    mmeditacl /gpfs/hpc/samba/agvr        # EDITOR=vi first; NFSv4 ACL with FileInherit:DirInherit

The NFSv4 ACL pattern that makes a share group-usable while `everyone@` gets nothing is in the notes in full — owner and group get rwxc with inheritance, everyone gets `----`.

## Snapshots

    mmcrsnapshot space cloud:15112020 -j cloud
    mmlssnapshot cloud
    mmdelsnapshot space cloud:15112020

The snapshot that will not delete — a PIT thread stuck somewhere — is diagnosed with:

    mmfsadm saferdump all > /tmp/mmfs/service.dump
    grep "status pending" /tmp/mmfs/service.dump
    mmdiag --threads

And the note beside it, translated with its shrug: *seems like power-resetting every machine that sinfo shows as down helps.* Snapshot restore is an empty section in the notes — sometimes the restore was never needed, and that is its own kind of evidence.

## Pools, policies, tiering

A default rule is mandatory the moment a second pool exists:

    RULE 'ssd'    SET POOL 'ssd' WHERE name like 'volume-%' OR name like 'snapshot-%'
    RULE 'hdd'    MIGRATE FROM POOL 'ssd' TO POOL 'system'
                  WHERE ((KB_ALLOCATED > 10485760) OR (DAYS(CURRENT_TIMESTAMP) - DAYS(ACCESS_TIME) > 30))
                    AND (name like 'volume-%' OR name like 'snapshot-%')
                    AND (name NOT like '%<excluded-uuid>' AND ...)
    RULE 'default' SET POOL 'system'

The subtlety worth stealing: `KB_ALLOCATED` migrates when space is *actually used*; `FILE_SIZE` migrates the moment a sparse file *claims* more than 10G. OpenStack volume files are sparse — the two rules place different workloads.

    mmapplypolicy cloud -L 6 -P CloudPolicyFile -I test    # always test first
    mmchpolicy cloud CloudPolicyFile_real
    mmchattr -P <pool> /path/to/volume                     # one file, by hand
    mmrestripefile -b /path/to/volume

## Filesets and quotas

    mmcrfileset terra cloud --inode-limit 100000000 --inode-space new
    mmsetquota terra:cloud --block 504800G:524800G --files 600000:800000
    mmlsquota -j cloud terra
    mmlsfileset terra cloud -L

Without `--inode-space new` the fileset is dependent — and has no snapshot capabilities. The notes carry that as a scar from creating one wrong.

The NFS-export-with-quota recipe, end to end: a group, an export with `Squash=all` and `Anonymous_uid=0,Anonymous_gid=<group-gid>`, then a group quota on the fileset — the VM sees root, the quota sees the group, the tenant sees a limit.

## GSS: declustered arrays

Under GPFS's storage services sit the declustered arrays — vdisks striped over pdisk, replication spread across enclosures and drawers:

    mmlspdisk all | egrep '(name|dataBadness)' | tr -d '\n' | sed -r 's/ (name)/\n\1/g' | sort -n -k 6
    # dataBadness characterizes media errors (hard errors) and checksum errors
    # disks with lower replacementPriority should be replaced first
    mmvdisk pdisk list --rg <rg> --pdisk e2d1s01 -L | grep state
    mmvdisk rg list --rg <rg> --all | less

    vdisk               RAID code        disk group fault tolerance   remarks
    RG001LOGHOME        4WayReplication  2 enclosure
    RG001VS002          8+2p             1 drawer
    RG001VS005          8+3p             -                            rebuilding

The replacement procedure is physical: **pull the bad disk, insert the new one, or the box stays yellow** — and the rebuild takes its time. The notes also record drawer-failure simulation and one aborted rebalance (`Abort rebalance of DA DA1`), plus the expander saga: an I2C expander fault light cleared with `gncli exp:N reboot soft` — *and the faults started creeping back*. Intermittent hardware is a schedule item, not a solved ticket.

A colleague's message preserved from that morning, translated: *"I can come over after lunch — maybe you'll find another bad disk by then."* On a declustered array, there usually is one.

## The arithmetic nobody wants

From the notes, an R session — the honest version of vendor reliability math:

    # how often can you read a 12 TB disk end-to-end before expecting a bit error (10^15 spec)?
    > 10^15 / (12 * 10^12 * 8)
    [1] 10.4                       # ten full reads. That is the whole safety margin.

    # the estate's real numbers: 477 TB read, 79 corrected errors, 288+168 disks
    > # effective bit error rate works out to 5.8e14 — a third below spec

    # MTBF (10^6 hours) converted to expected annual failures for the estate:
    > (24*365) / 10^6 * (288 + 168)
    [1] 3.99                       # four dead disks a year, on average

Four dead disks a year, ten full reads of margin, real error rates worse than the datasheet. This is why the array replicates across drawers, why `dataBadness` gets sorted numerically, and why the paragraph above this one exists.

---

*Parallel filesystems punish improvisation. If your estate runs Spectrum Scale and the manuals have not saved you yet — [info@wirt.ee](mailto:info@wirt.ee).*

---

*This saved you a night? I do this for a living: [info@wirt.ee](mailto:info@wirt.ee).*
