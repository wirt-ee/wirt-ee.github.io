---
date: 2025-05-06
tags: [vyos, networking, nftables, containers]
description: "On VyOS 1.5, policy-based routing marks collide with netavark's container mark — traffic that matches no NAT rule gets silently masqueraded."
---

# Containers that SNAT traffic they should not

Context: self-built VyOS `1.5-rolling-202505061352` on a lab VM, reproducing something seen in production shape: packets leaving the router were source-NAT'd although **no NAT rule matched them**. The first hint was iptables refusing to show the truth:

    # iptables -L -t nat
    # Table `nat' contains incompatible base-chains, use 'nft' tool to list them.

The nft view showed the chain:

    table ip nat {
        chain NETAVARK-HOSTPORT-MASQ {
             meta mark & 0x00002000 == 0x00002000 counter packets 0 bytes 0 masquerade
        }
    }

netavark — the container network stack — masquerades **everything carrying mark bit 0x2000**. VyOS policy-based routing fwmarks its policy-routed packets with `0x7ffffffe`. Bit 13 of `0x7ffffffe` is set. Any policy-routed packet therefore matches the masquerade rule — containers running or not. And the rule stays behind after the container is deleted.

## Reproduce, nine steps

    # 0) have any nat rule configured
    # 1) a static table for policy routing
    set protocols static table 1 route 0.0.0.0/0 next-hop <wan-gw>

    # 2) policy routing that uses it
    set policy route pbr-eth0 interface 'eth0'
    set policy route pbr-eth0 rule 16 log
    set policy route pbr-eth0 rule 16 set table '1'
    set policy route pbr-eth0 rule 16 destination address '<captured-host>'

    # confirm the fwmark exists
    # ip rule list | grep fwmark
    1: from all fwmark 0x7ffffffe lookup 1

    # 3-5) a container network and a container
    set container network ctr prefix '10.0.100.0/24'
    run add container image 'debian:bookworm'
    set container name ctest image 'debian:bookworm'
    set container name ctest network 'ctr'

    # 6) ping the captured host from LAN while tcpdumping the WAN side
    #    -> replies arrive with correct addresses
    # 7) commit any (even partial) nat rule
    set nat
    commit

    # 8) now the same ping leaves MASQUERADE'd — tcpdump on the
    #    container interface shows translated addresses
    # 9) delete the container — the masquerade rule stays

Counters confirm who did it:

    chain NETAVARK-HOSTPORT-MASQ {
         meta mark & 0x00002000 == 0x00002000 counter packets 138 bytes 11592 masquerade
    }

## Workarounds

- Put container networks in their own VRF, so their traffic never crosses the policy-routing marks:

        set vrf name container-vrf description "container networks"
        set vrf name container-vrf table 100
        set container network ctr prefix '10.0.100.0/24'
        set container network ctr vrf container-vrf

- Or delete the container and reboot — the masquerade rule does not survive.

## Why it matters

Nothing in the config says "SNAT this". The NAT table looks correct. The proof needs `nft`, tcpdump and reading a bit mask — which is why it looks like random magic in production. If you run VyOS with both policy-based routing and containers, check for `0x2000` in your marks. Filed upstream: [vyos.dev/T7436](https://vyos.dev/T7436).

---

*This saved you a night? I do this for a living: [info@wirt.ee](mailto:info@wirt.ee).*
