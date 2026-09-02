---
date: 2026-03-25
tags: [networking, cumulus, mlag, nvue]
description: "Cumulus Linux under NVUE: the seven things that bit across the 5.6 to 5.10 trail — config-validation traps, SNMP in a VRF, and a 400G link that worked and lost packets."
---

# Cumulus, NVUE, MLAG

Context: Cumulus Linux on Mellanox MSN3700 (Spectrum-2, 32×200G QSFP56) and Spectrum-4 400G switches, NVUE, in MLAG pairs — the estate's switches after the [Onyx era](../onyx-mlag/index.md). This entry is the bites, collected from the running notes across the 5.6 → 5.10 trail; the reusable shapes — MLAG essentials, the parameterized port config, breakouts, ONIE installs — are in [Evergreen](../../reports/network/mlag-cumulus/index.md). Hostnames, addresses and VLAN layouts below are genericized.

## What bit — quick reference

| The thing you are staring at | Fix | § |
|---|---|---:|
| `Invalid config: multiple vlan-aware bridges are not supported with mlag` | one bridge, `br_default`; segment with VLANs | 1 |
| `vlan` + `access` + `untagged` conflict on validation | one attachment mode per interface | 2 |
| `br_default state DOWN` with a member down | `svi-force-up` if the SVI must stay up | 3 |
| snmpd in a management VRF answers nothing (`ENETUNREACH`) | run it inside the VRF explicitly | 4 |
| a link that flaps or refuses to come up | fixed speed beats autoneg, usually | 5 |
| a 400G link that works and loses packets | `mlxlink`, trust the raw BER, reseat the optics | 6 |
| `MSTP_IN_rx_bpdu ... Clear Bridge assurance inconsistency` | per-interface `stp network enabled`, both switches | 7 |

Notes on a few:

3. The bridge SVI tracks its members — with one down, the SVI goes down with it. `nv set system global svi-force-up enable on` when that is not what you want.

4. snmpd as a plain systemd service does not inherit the VRF, and answers nothing — strace shows `sendmsg = -1 ENETUNREACH`. Run it inside the VRF explicitly:

        # /etc/systemd/system/snmpd.service.d/overwrite.conf
        ExecStart=/usr/bin/vrf exec mgmt /usr/sbin/snmpd -LOw -u Debian-snmp \
                  -g Debian-snmp -I -smux -f --noTokenWarnings
        ProtectControlGroups=false    # VRF execution needs control groups

5. On links that flap or refuse to come up, forcing works — but note both directions in the notes worked: `nv set interface swp26 link speed 40G` fixed one, and on 5.6.0 `speed auto` also fine. The full nudge set:

        nv set interface swp20 link speed 10G
        nv set interface swp20 link auto-negotiate disabled
        nv set interface swp20 link duplex full
        nv set interface swp20 link fast-linkup enabled
        nv set interface swp20 link state up

6. Random packet loss on a 400G link. `mlxlink` is the tool that tells the truth:

        sudo mlxlink -d /dev/mst/mt53104_pci_cr0 -p <port> --show_counters

        Recommendation      : Bad signal integrity
        Effective Physical Errors : 0
        Effective Physical BER    : 15E-255
        Raw Physical BER         : 2E-5
        Link Down Counter        : 6

   Effective counters clean, raw BER 2E-5 — the link "works" and loses packets. Trust the raw counters; reseat or replace the optics.

7. syslog fills with `MSTP_IN_rx_bpdu ... Clear Bridge assurance inconsistency` on a bond, and the reason is one missing per-interface knob:

        nv set interface bond1 bridge domain br_default stp network enabled

   Do it on both switches of the pair.

---

*This saved you a night? I do this for a living: [info@wirt.ee](mailto:info@wirt.ee).*
