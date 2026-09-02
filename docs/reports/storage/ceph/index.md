# Ceph: the field kit

Commands from the estate's Ceph years — jewel through quincy, ceph-deploy labs to production, replicated and erasure-coded. The dated disasters are in the Logbook: [the unrecoverable EC PG](../../../logbook/ceph-ec-data-loss/index.md), [Reef to Squid by hand](../../../logbook/ceph-reef-to-squid/index.md). Get CEPH backup — it is great when you have one, and this page is written by someone who once did not. Pool names follow the OpenStack conventions (`cinder-volumes` and friends); hostnames and addresses are placeholders.

## Monitoring at a glance

    rbd perf image iotop  --pool cinder-volumes          # live, per volume
    rbd perf image iostat --pool cinder-volumes | grep volume-<uuid>
    ceph iostat                                           # cluster wide
    ceph device ls                                        # disk wear
    watch "bash -c 'ceph osd perf | awk \"{if (\\\$3 > 5) print \\\$0}\"'"   # OSDs over 5 ms
    ceph daemonperf osd.42                                # dstat, for an OSD

## The debug battery

    ceph report | less
    ceph osd status
    ceph osd dump -f json | python -m json.tool | less
    ceph osd dump | grep pool
    ceph osd tree ; ceph osd df ; ceph df
    ceph osd lspools ; ceph osd pool ls detail
    ceph pg stat
    ceph quorum_status --format json-pretty
    ceph daemon osd.42 help | less                       # everything the daemon can do
    ceph daemon osd.42 perf dump | less

The admin socket path, when `ceph daemon` is not enough:

    ceph-conf --name mon.<id> --show-config-value admin_socket
    ceph --admin-daemon /var/run/ceph/ceph-osd.1.asok <command>

## Benchmarks

    rados -p <pool> bench 60 write -t 32
    ceph tell osd.0 bench 3145728000                      # per-OSD, bytes
    ceph tell osd.* bench > bench.txt
    egrep '(osd|iops)' bench.txt | sed -z -e 's/: {\n//g' \
      | awk '{print $1,"\t",$3}' | sort -n -k2           # sort by IOPS

## The full-at-95% emergency

At `full` ratio every client operation stops. Buy room first, delete second:

    ceph daemon osd.0 config show | grep mon_osd_full_ratio
    ceph daemon osd.0 config set mon_osd_full_ratio 0.98   # and then delete as fast you can

## Reweighting

Temporary (`ceph osd reweight`) resets on restart; permanent is the CRUSH reweight:

    ceph osd reweight 11 0.94899                  # temporary
    ceph osd crush reweight osd.32 3.59999        # permanent
    ceph osd reweight-by-utilization              # some OSDs near full
    ceph osd crush reweight-all                   # with noout set; fixed 'objects degraded'

A batch shape from the notes — every 7.0 T OSD stepped down:

    ceph osd df | grep ' 7.0 T' | awk '{print $1}' \
      | while read l; do ceph osd crush reweight osd.$l 6.4; done

## Recovery speed

    # read current
    ceph --admin-daemon /var/run/ceph/ceph-mgr.<host>.asok config show \
      | egrep '(osd_max_backfills|osd_recovery_max_active)'
    # push it — for all OSDs, live
    ceph tell 'osd.*' injectargs '--osd-max-backfills 12'
    ceph tell 'osd.*' injectargs '--osd-recovery-max-active 4'
    ceph tell 'osd.*' config set osd_recovery_sleep_hdd 0      # the way to unthrottle
    ceph tell 'osd.*' config set osd_recovery_sleep_hybrid 0
    # during the recovery swap client/recovery priority
    ceph config set osd osd_recovery_op_priority 63
    ceph config set osd osd_client_op_priority 3

Octopus and later can aim it at one pool:

    ceph osd pool force-recovery cinder-data

## Slow requests

    ceph osd blocked-by                                  # which OSD blocks which
    ceph pg dump_stuck stale
    ceph pg 30.171 query ; ceph pg 30.171 list_unfound
    ceph --admin-daemon /var/run/ceph/ceph-osd.1.asok dump_historic_ops | less
    ceph daemon osd.X dump_ops_in_flight
    ceph daemon osd.21 dump_ops_in_flight | grep client   # who is slow
    ceph daemon osd.21 dump_historic_ops | egrep '(client_addr|duration)'
    ceph --admin-daemon /var/run/ceph/ceph-osd.1.asok perf dump \
      | grep -A 20 -e op_latency -e op_[rw]_latency -e journal_latency

Latencies are in seconds; sum/avgcount averages since the daemon last restarted — restarts reset your history.

The heuristic for the wire itself: 0.2 ms is the magic number. Everything is still fine at 0.2. At 0.4 ms the cluster already feels slow, and above that you are sorry. The week this number got burned in is [in the logbook](../../../logbook/ceph-ec-data-loss/index.md).

## Scrub toggles

    ceph osd set noscrub ; ceph osd set nodeep-scrub      # during peak or recovery
    ceph osd unset noscrub ; ceph osd unset nodeep-scrub

## Who is holding this volume

    rbd -p cinder-volumes lock ls volume-<uuid>
    #   Locker            ID                  Address
    #   client.1029402390 auto 140675748435392 <ip>:0/2720028981

    rbd -p cinder-volumes status volume-<uuid>            # watchers — the VM is running somewhere

The exclusive-lock list answers "which hypervisor has this VM"; the watcher list answers "why can't I delete this image".

## Small fixes that matter

- **SSD detected as HDD** (`/sys/block/sdc/queue/rotational` says 1): the device class is wrong in CRUSH:

        ceph osd crush rm-device-class osd.20
        ceph osd crush set-device-class ssd osd.20

- **Monitor clock skew**: `ceph health detail` says so; `/etc/init.d/ntp restart`, then the ceph daemons.
- **How long an OSD may be down before backfill starts**: `ceph config set mon mon_osd_down_out_interval 600`.
- **OSD priority, the blunt way**: `renice -n -20` over every OSD pid, one ps/awk pipeline.
- **OSD memory**: read the target, check reality, then set it per class:

        ceph daemon osd.3 config show | grep osd_memory_target
        ps aux | grep ceph-osd | grep -v grep | awk '{print "pmap " $2 "|tail -n 1"}' | sh
        ceph osd tree | grep ssd | grep -v '    0' | awk '{print $1}' \
          | while read l; do ceph config set osd.$l osd_memory_target 8589934592; done

- **tcmalloc profiling**: `ceph tell osd.0 heap start_profiler`, `heap dump`, `heap stats`; `TCMALLOC_MAX_TOTAL_THREAD_CACHE_BYTES` in `/etc/default/ceph`. jemalloc was *not* the answer on luminous — `Segmentation fault`, tracker 20557.
- **rados/rbd python libs missing inside a venv** (OpenStack-ansible): symlink the distro's `rbd.so`/`rados.so` into the service venv, restart the service.
- **Old kernel, new cluster**: `CRUSH_TUNABLES5 are not supported` on xenial 4.4 — `ceph osd crush tunables hammer`.

## When a binary loses a symbol

`rbd-nbd` refusing to start with `symbol lookup error: undefined symbol: _Z18socketpair_cloexeciiiPi` means the binary and the installed `libceph-common.so.0` disagree about versions. Find which library should carry the symbol — from a working node:

    ldd /usr/bin/rbd-nbd | grep -o "\/.* " | while read l; do
      echo library:$l; nm -D $l 2>&1; done \
      | egrep '(library|_Z18socketpair_cloexeciiiPi)' | grep -B 1 _Z18socketpair_cloexeciiiPi

The answer was `/usr/lib/ceph/libceph-common.so.0` — owned by `librados2` (`dpkg -S`), so the fix was simply: upgrade librados2.

## OSD lifecycle

Removing, one at a time or in a batch:

    ceph osd out 11 && systemctl stop ceph-osd@11
    ceph osd crush remove osd.11 ; ceph auth del osd.11 ; ceph osd rm osd.11
    for i in 19 24 28; do ceph osd crush remove osd.${i}; sleep 5; \
      ceph auth del osd.${i}; sleep 5; ceph osd rm osd.${i}; sleep 5; done

Replacing a failed one (ceph-disk era):

    systemctl stop ceph-osd@2 && umount /var/lib/ceph/osd/ceph-2
    ceph osd destroy 2 --yes-i-really-mean-it
    ceph-disk zap /dev/sdc
    ceph-disk prepare --bluestore /dev/sdc --osd-id 2 --osd-uuid `uuidgen`
    ceph-disk activate /dev/sdc1

And the discipline around it: `ceph osd set noout` before hardware work, `unset` after; `mon osd down out subtree limit = host` in `ceph.conf` to stop node-level backfill storms (noted as untested in the notes; treat accordingly).

## RBD snapshot machinery

From a running VM (via nova), or blind:

    rbd --pool cinder-volumes snap list <volume>
    nova image-create <server> <name>                     # snapshot from the running VM
    rbd clone cinder-volumes/volume-<uuid>@snap cinder-volumes/child-<uuid>
    rbd children cinder-volumes/volume-<uuid>@snap
    rbd flatten cinder-volumes/child-<uuid>

Note: **rbd snapshots and pool snapshots are mutually incompatible.**

Find every snapshot that still has children, flatten everything, then clean up backup-script leftovers:

    rbd list -p cinder-volumes | while read vol; do
      rbd snap list cinder-volumes/$vol | awk '/snaps/ {print $2}' | while read snap; do
        test -n "$(rbd children cinder-volumes/${vol}@${snap})" && echo ${vol}@${snap}
      done
    done

    # and the one-liner that removes the snapshots a backup script created and forgot:
    pool='cinder-volumes'; rbd -p $pool ls | while read l; do rbd snap list ${pool}/${l}; done \
      | awk -v pool=$pool '!/NAME/ && /volume/ {print "rbd snap rm " pool"/"$2"@"$2}' | sh

The "blind" pattern — snapshot everything, export, remove — logged to a file so the cleanup can be generated from the same list that created it:

    rbd ls cinder-volumes | while read l;do \
      echo rbd snap create cinder-volumes/${l}@$(date +%d%m%y)-${l}; done | tee /var/log/rbd-snap | sh
    awk '{print $4}' /var/log/rbd-snap | while read l; do rbd snap rm ${l}; done

## Object storage: RGW, Swift, S3

The same cluster that serves blocks can serve objects — the rados gateway, three daemons on three hosts in this estate's case, speaking both S3 and Swift on port 7480:

    ceph-deploy install --rgw <node1> <node2> <node3>
    ceph --admin-daemon /var/run/ceph/ceph-client.rgw.<node>.asok config show
    radosgw-admin metadata list user
    swift -V 3 stat

And the truth that makes RGW less magical: an S3 object is just a rados object in a pool — `rados -p <pool> ls`, `rados get`, `rados put` walk the same data the gateway serves.

The interesting part is authentication. This estate's gateway authenticated **S3 and Swift through Keystone** — OpenStack tokens, not S3 keys — which turns the object store into just another OpenStack service:

    [client.rgw.<node>]
    rgw_frontends = "civetweb port=7480"
    rgw_keystone_url = https://<keystone>:5000
    rgw_keystone_api_version = 3
    rgw_keystone_implicit_tenants = true
    rgw_s3_auth_use_keystone = true
    rgw_keystone_accepted_roles = admin, _member_
    rgw_swift_account_in_url = true
    rgw_swift_url_prefix = "swift"

Two service users in Keystone carry it (one in the admin group — RGW requires exactly one admin), and `_member_` in the accepted roles is the same role the OpenStack side later deprecated — the [Yoga→Zed run](../../../logbook/yoga-to-zed/index.md) cleans up what this config leans on.

Swift itself was learned the cheap way first: a SAIO — swift all-in-one, the whole object store on one machine, walked from `temp_auth` to Keystone auth before it ever touched production.

### The backup thread

The object store earned its keep as a backup target. The estate's oldest pattern is above — the blind RBD snapshot, `rbd export`, and the note's own `echo do-tsm-backup` handing the export to a backup agent. For real production the bulk loop gave way to a curated procedure: take the VM, find its volumes, fire the snapshots back-to-back — as close in time as two commands can be — then dump the files to tape (Tivoli Storage Manager). Consistency was a human aiming two snapshots at the same moment. The pattern's descendant needs no agent and no tape: software that takes Ceph snapshots of VM block volumes and ships them **to S3** — the same blind-snapshot mechanics, the export target swapped from a queue to an object store, and a restore that becomes an S3 GET. Its architecture, encryption, restore discipline and one known consistency limitation have [their own page](../rbd-backups/index.md). The proof of a backup remains a restore; the object store just shortens the distance between them.

## CephFS with a writeback cache tier

The full shape, plus the teardown — cache tiers are two-phase machinery, and the teardown is the part nobody remembers:

    ceph osd pool create cephfs_metadata 64 64 replicated hot-storage
    ceph osd pool create cephfs_data 64 64 erasure ec-cold cold-storage
    ceph osd pool create cephfs_data_cache 64 64 replicated hot-storage
    ceph osd tier add cephfs_data cephfs_data_cache
    ceph osd tier cache-mode cephfs_data_cache writeback
    ceph osd tier set-overlay cephfs_data cephfs_data_cache
    ceph osd pool set cephfs_data_cache size 3
    ceph osd pool set cephfs_data_cache target_max_bytes 107374182400
    ceph osd pool set cephfs_data_cache hit_set_count 2
    ceph osd pool set cephfs_data_cache hit_set_period 300
    ceph osd pool set cephfs_data_cache min_read_recency_for_promote 1
    ceph osd pool set cephfs_data_cache cache_target_dirty_ratio 0.4
    ceph osd pool set cephfs_data_cache cache_target_dirty_high_ratio 0.6
    ceph osd pool set cephfs_data_cache cache_target_full_ratio 0.8
    ceph osd pool set cephfs_data_cache cache_min_flush_age 600
    ceph osd pool set cephfs_data_cache cache_min_evict_age 1800
    ceph fs new cephfs cephfs_metadata cephfs_data

    # teardown, in order:
    ceph osd tier cache-mode cephfs_data_cache forward --yes-i-really-mean-it
    ceph osd tier remove-overlay cephfs_data
    ceph osd tier remove cephfs_data cephfs_data_cache
    ceph osd pool delete cephfs_data_cache cephfs_data_cache --yes-i-really-really-mean-it

## RBD client cache

The client-side cache is config, not code — read what the clients actually run before tuning anything:

    ceph config get client rbd_cache_policy          # writearound, writeback...
    ceph config get client rbd_cache_size
    ceph config get client rbd_cache_max_dirty
    ceph config get client rbd_cache_target_dirty

The estate's production ran `writearound` with the 32M/24M/16M defaults; the notes carry a sizing for `writeback` at 256M/128M/64M — and an honest `#TODO write cache?`. A writeback client cache is durability arithmetic: what the client has not flushed, the cluster does not have. Decide with that sentence in mind.

## Get CEPH backup
It is great when you have a backup or you don't destroy your network under an erasure-coded pool.

```
rbd export -p  pool volume-ad0ceef0-64ef-4050-afd6-3a12c13dd6be ./volume-ad0ceef0-64ef-4050-afd6-3a12c13dd6be.bac
```

## Restore CEPH from backup

```
rbd rm pool volume-ad0ceef0-64ef-4050-afd6-3a12c13dd6be
rbd import ./volume-ad0ceef0-64ef-4050-afd6-3a12c13dd6be.bac  pool/volume-ad0ceef0-64ef-4050-afd6-3a12c13dd6be
```

## Manipulate CEPH block storage (VM disk)
From time to time, you need to do some artwork inside VM. To do so, you first need to be able to mount RBD.

```
rbd export <pool>/<volume> /tmp/<uuid> #backup if needed
dev=$(rbd map  <pool>/<volume> )
sgdisk --print ${dev} #record current layout
rbd showmapped
rbd unmap ${dev}
```

---

*This saved you a night? I do this for a living: [info@wirt.ee](mailto:info@wirt.ee).*
