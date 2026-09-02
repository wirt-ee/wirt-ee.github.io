---
date: 2021-08-27
tags: [networking, fortigate, vxlan, ipv6, api]
description: "FortiGate HA at the edge: VXLAN bridges into OpenStack, OSPFv6, IPv6 SLAAC for tenant networks, and a REST API that needs cookies when the token misbehaves."
---

# FortiGate, VXLAN to OpenStack

Context: a FortiGate HA pair at the edge of an OpenStack estate — tenant networks extended from the hypervisors to the firewalls as VXLAN, IPv6 inside the tenants via SLAAC, OSPF/OSPFv3 toward the upstream. These are the 2020–2021 notes; the pair was later replaced by the VyOS firewalls in the [VyOS burn-in period](../vyos-three-years/index.md). Hostnames, addresses and tunnel names genericized.

## CLI scripting over SSH

Everything below works over scripted SSH — no GUI needed, full configs as text:

    cat tac_report;      ssh -tt -T admin@<fw> < tac_report      > tac_report.txt
    cat full_config;     ssh -tt -T admin@<fw> < full_config     > full-configuration.txt

    # tac_report
    config vdom
    edit root
    execute tac report

    # full_config
    config global
    config system console
    set output standard
    end
    config vdom
    edit root
    show full-configuration

## The diagnostics that matter

    get system status
    diagnose sys top 1
    get system performance status            # config global
    diagnose debug crashlog read             # and: crashlog history
    get router info routing-table all        # IPv4
    get router info6 routing-table           # IPv6 — separate tree, always
    get router info routing-table database   # includes inactive routes

IPv4 and IPv6 live in separate subcommand trees (`info` vs `info6`) — half the confusion in any FortiGate IPv6 session is looking at the wrong one. The sniffer is a full tcpdump, including BPF on VXLAN source MACs:

    diagnose sniffer packet vx<vni> 'icmp6' 3
    diagnose sniffer packet any "(ether[6:4]=0x3e03e29e) and (ether[10:2]=0xff90)" 6 0
    diagnose sniffer packet any 'host <ip>' 4 0 0

    # hexdump output converts to pcap for Wireshark (File -> Import from hexdump)

And the IPv6 neighbor cache, when SLAAC mysteries start: `diagnose ipv6 neighbor-cache list`.

## VXLAN into OpenStack

The bridge between the firewall and the tenant networks. On the OpenStack side, find the VNI and the multicast group:

    openstack network show -c 'provider:segmentation_id' -f value <network-id>
    # from any neutron agent container:
    ip -d link show vxlan-<vni> | grep -o "group <mcast>.*"

On the FortiGate, the VXLAN and its interface:

    config system vxlan
        edit "vx<vni>"
            set interface "vlan<id>"
            set vni <vni>
            set ip-version ipv4-multicast
            set remote-ip "<mcast-group>"
            set multicast-ttl 32
            set dstport 8472
        next
    end

    config system interface
        edit "vx<vni>"
            set vdom "root"
            set allowaccess ping
            set type vxlan
            config ipv6
                set ip6-address <v6>::2/64
                set ip6-allowaccess ping
                config ip6-extra-addr
                    edit <v6>::1/64
                next
                end
                set ip6-send-adv enable
                config ip6-prefix-list
                    edit <v6>::/64
                        set rdnss <rdnss-1> <rdnss-2>
                    next
                end
            end
        next
    end

`ip6-send-adv` + the prefix list makes the firewall the RA source: **guest instances obtain IPv6 from the firewall itself, via SLAAC, not from any OpenStack router** — with Cloudflare's public resolvers announced as RDNSS. Deleting one is the mirror image: `config system vxlan` → `delete <name>`, then unset the interface's `ip6-address` and remove the prefix from the list.

One multicast gotcha documented by Fortinet: neighbor solicitation does not forward by default — [multicast forwarding must be enabled](https://docs.fortinet.com/document/fortigate/6.0.0/handbook/21554/enabling-multicast-forwarding), or the VXLAN looks deaf.

## OSPF housekeeping

    # stop advertising statics into OSPF
    config router ospf
        config redistribute static
            set status disable
        end
    end

    # stop originating a default route
    config router ospf
        unset default-information-originate
    end

    # migrate a network off the box (e.g. to a new firewall):
    config router ospf
        config network
            delete 5
        end
    end

OSPFv3 (`config router ospf6`) holds its own summary-address entries — `show summary-address`, `delete <id>`, `edit 1` + `set prefix6 …` — and `get router info6 ospf neighbor` is where adjacency truth lives (`Full/DR` or nothing).

## The REST API, and its cookie fallback

The token flow is simple — until it isn't:

    curl -k "https://<fw>:8443/api/v2/cmdb/system/interface/vx<vni>?access_token=$(cat fg-apikey)&format=name" | jq
    # toggle an interface (down/up creates the IPv6 routes)
    curl -k -XPUT -d '{"status":"down"}' "https://<fw>:8443/api/v2/cmdb/system/interface/vx<vni>?vdom=root&access_token=$(cat fg-apikey)"

Three findings worth keeping:

1. **POST/PUT of a full interface config fails with 500 twice, then succeeds.** The working pattern is a retry loop that stops on the first 200.

2. **When the API token misbehaves (routing not created), fall back to session auth** — `logincheck` with cookies, extracted with sed:

        headers="$(curl -k -i -s -XPOST https://<fw>:8443/logincheck \
            -d "username=<admin-username>&secretkey=<secret>" \
            | grep Set | grep -v 'ccsrftoken_' \
            | sed -r 's/Set-Cookie: (.*); p.*/-H \x27Cookie: \1\x27/g' \
            | sed -r 's/-H .*Cookie: ccsrftoken="(.*)"/-H \x27X-CSRFTOKEN: \1/g' \
            | tr '\n' " ")"

3. **Arrays in CMDB objects are replaced, not appended** — jq builds the full list: add with `.results[.results|length] |= . + {...}`, remove with `del(.results[] | select(."interface-name" == "vx<vni>"))`, then PUT the whole `{"interface": ...}` object.

API debugging on the box: `diagnose debug application httpsd -1` + `diagnose debug enable` (auto-off after 30 minutes).

## Odds and ends

- **IPsec ping bug**: ICMP to a host behind the tunnel dies while traceroute runs almost to the end — check `get vpn ipsec tunnel details` and `diagnose vpn tunnel list name <tunnel>` before blaming the far end.
- **VRRP for both families**: `get router info vrrp` and `get router info6 vrrp`; the IPv6 virtual IPs live under `config vrrp6` in the interface's `config ipv6` block, with a link-local `vrip6_link_local`.
- **Upgrade procedure, verbatim from a colleague**: back up the config, then "press the button on global → system → firmware". If the box bricks mid-upgrade, the config restores onto another box.
- **Syslog** is `config log syslogd setting` — `set status enable`, `set server <host>`, `set mode udp`, `set port 514`; disable with `unset server` + `set status disable`.
- **Admin SSH key** instead of passwords: `config system admin` → `edit admin` → `set ssh-public-key1 "ssh-rsa <blob>"`.

---

*This saved you a night? I do this for a living: [info@wirt.ee](mailto:info@wirt.ee).*
