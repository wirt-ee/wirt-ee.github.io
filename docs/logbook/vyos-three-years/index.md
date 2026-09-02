---
date: 2026-08-11
tags: [vyos, networking, firewalls]
description: "One HA firewall pair, live-upgraded through every VyOS release from 1.2.9 (2023) to 2026.02 — images, migrations, and the bugs between them."
---

# VyOS burn-in period

Context: a pair of HA firewalls on VyOS, upgraded in place from 1.2.9 in early 2023 to the 2026.02 stream release. Never rebuilt from scratch. Hostnames and addresses below are genericized; versions, errors and commands are as they happened.

## The trail

| Version | When | Note |
|---|---|---|
| 1.2.9 | 2023 start | where the pair came from |
| 1.4-rolling-202302150317 | 2023-02 | first rolling jump |
| 1.4-rolling-202305091511 | 2023-05 | **self-baked image** |
| 1.5-rolling-202405270829 | 2024-05 | config-error-on-boot bug below |
| 1.5-rolling-202505061352 | 2025-05 | container SNAT bug, [own entry](../vyos-container-snat/index.md) |
| 1.5-rolling-202509150723 | 2025-09 | |
| 2025.11 → 2026.02 | 2025–2026 | stream releases, minisign-verified |

## Image management

    add system image https://s3-us.vyos.io/rolling/current/vyos-rolling-latest.iso
    set system image default-boot 1.5-rolling-202405270829

Two things the S3 mirror does: signature download 403s (`...iso.minisig`, `...iso.asc`) — answer "yes" to continue, but verify stream ISOs yourself with minisign and the published key:

    minisign -Vm vyos-2026.02-generic-amd64.iso -P RWTR1ty93Oyontk6caB9WqmiQC4fgeyd/ejgRxCRGd2MQej7nqebHneP
    Signature and comment signature verified

## Self-baked images

The Docker build flow is not repeated here; it lives in [the Evergreen firewall page](../../reports/network/firewall/index.md). The same flow built every image on this trail: the current stream, `--build-type release` for sagitta, and the equuleus branch with `./configure --version 1.3.2` when a customer-of-one needed a pinned release.

## Bugs the trail hit

1. **1.4 lost the default route on DHCP interfaces.** Workaround: `set protocols static route 0.0.0.0/0 dhcp-interface eth0` — or stop using DHCP on a firewall WAN.

2. **Installer offers no RAID1 for NVMe.** Workaround: build the mirror by hand, metadata 1.0 at the *end* of the disk so the UEFI partition lives in front:

        mdadm --create /dev/md0 --level=1 --raid-devices=2 --metadata=1.0 /dev/nvme0n1p2 /dev/nvme1n1p2
        mdadm --detail --scan >> /etc/mdadm/mdadm.conf

3. **After the 1.5 upgrade: `WARNING: There was a config error on boot`** and a horrifying moment when `/config/config.boot` looked empty. The migration errors are in `/tmp/vyos-configd-script-stdout`; the fix is to zero the status flag so configd proceeds:

        echo 0 > /tmp/vyos-config-status

4. **BFD config crashed on a source-address check** — a genuine source bug in `/usr/libexec/vyos/conf_mode/protocols_bfd.py` (`len(peer_config['source']) < 2`). Fixed it the VyOS way: fork, adjust, Phabricator task, commit with the task reference, pull request. The workflow costs an evening; do it — rolling releases only improve if the people running them in production report.

5. **A static route was in the config but not in the kernel.** Delete the exact line, set the exact line again, commit. Mundane, but first check the kernel (`ip route`) — not the config — when traffic takes a wrong turn.

6. **snmpd kept reporting pre-rename interface names.** Restart snmpd after renaming interfaces.

## Migration mechanics (2025.11 → 2026.02)

The upgrade keeps the pre-migration config; diff it, read the migrate log:

    diff /config/config.boot.20260811-155514.pre-migration /config/config.boot
    cat /config/vyos-migrate.log

## Habits that paid off

- **Compare and count firewall rules between the pair** before believing an upgrade:

        run show configuration commands | grep -v eth0 | sort > fw-a
        # scp it over, then:
        diff fw-a fw-b

- **BFD is downstream of OSPF**: if OSPF is down, BFD is down — don't debug the wrong layer. A healthy peer shows `Status: up`, sane timers; a broken one shows `Status: init`, `Diagnostics: neighbor signaled session down`.
- **iperf3, twenty parallel streams, one average number**:

        b=<src>;s=<dst>; for i in {1..20};do iperf3 -t 30 -T t${i} -c $s -B $b -p 510${i} & done \
          | awk '/sender/ {sum+=$8; cnt+=1} END {print sum/cnt}'

- **sflow-rt for flow visibility** (in docker, on a hypervisor): install, pull the browse-flows / prometheus / particle apps, then export flows in Prometheus format:

        curl "http://<sflow-rt>/app/prometheus/scripts/export.js/flows/ALL/txt?metric=sflow_flows_bps&key=ipsource,ipdestination,vlan,agent,tcpsourceport,tcpdestinationport&label=src,dst,vlan,agent,sport,dport&value=bytes&scale=8&maxFlows=100"

---

*This saved you a night? I do this for a living: [info@wirt.ee](mailto:info@wirt.ee).*
