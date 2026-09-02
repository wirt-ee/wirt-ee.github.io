# Fibre Channel: Brocade Fabric OS

Notes from bringing up and running SAN switches — 8 and 16 Gbit, OEM'd Brocades under HP and IBM badges (Fabric OS), and a Cisco MDS in IOS grammar. The fabric behind the [NetApp DR test](../../../logbook/netapp-dr-test/index.md). Switch names, zone and alias names, WWNs, addresses, community strings and passwords below are genericized or placeholders; the commands and their order are the point.

## First contact

Find the host side first — on Debian, the HBA's WWN is a sysfs read:

    cat /sys/class/fc_host/host*/port_name

On the switch, four commands tell you what you are standing in front of:

    version          # Fabric OS release
    configshow       # the whole running configuration
    chassisshow      # the platform
    switchshow       # ports, WWNs, switch type; domain ID lives here too
    firmwareshow     # what it runs

## Bring-up

    ipaddrset        # DHCP and static IP are mutually exclusive
    ipaddrshow
    tsTimeZone --interactive
    tsClockServer "<ntp-server>"
    switchname <name>
    chassisname <name>
    fabricname --set <fabric>

`switchname` and `chassisname` are different things — one names the switch, the other the platform; set both, or logs and prompts disagree with each other.

The **domain ID must be unique within the fabric** — set it with the switch disabled:

    switchDisable
    configure        # walk the prompts, set the domain
    switchEnable

## The reset ritual

A switch that arrives with history, or a lab switch between tests:

    switchDisable
    cfgclear         # wipes the zoning — the whole zoning database
    configdefault    # everything back to factory defaults
    configure
    switchEnable

`cfgclear` is the one to respect: it does not ask twice, and a fabric without its zoning database is four silent silos.

## Diagnostics

    switchshow                    # state at a glance
    porterrshow                   # error counters, per port — the first stop
    portperfshow -t 15            # live throughput, 15 s window
    portstatsshow 2               # historical counters, port 2
    portstatsclear 0              # reset them
    bottleneckmon --show          # who is the bad guy on your SAN
    bottleneckmon --show -interval 60 -span 300 2
                                  # bottleneck history on port 2, 60 s samples
                                  # over 300 s spans — roughly three hours deep
    supportshow                   # everything, for the support case

And the one-liner for watching a port's numbers stream past, timestamped and normalized to megabytes:

    ./supportsave-output | egrep --line-buffered -v '(Total|=|admin|spawn)' \
      | sed -u 's/m//g' | sed -u -r "s/^/$(date +'%T')/g" \
      | awk '{if ($2 ~ /k/) {gsub(/k$/,""); print $1,$2/1024} else {print $1,$2}}'

## Zoning — the object model

Three levels, built in this order: **aliases** (names for WWNs) → **zones** (who may talk to whom) → **configs** (which zones are active). A zone is a whitelist; anything not in it does not exist.

    alicreate <alias>, "<pwwn>"              # alias for one port WWN
    aliadd   <alias>, "<pwwn>"              # second HBA port into the same alias

    zonecreate <zone>, "<alias1>; <alias2>" # a zone from aliases
    zoneadd   <zone>, "<alias>"             # add a member to an existing zone
    zoneremove <zone>, "<member>"           # take one back out

    cfgcreate <cfg>, "<zone1>; <zone2>"     # a configuration from zones
    cfgadd    <cfg>, "<zone>"               # add a zone to it
    cfgremove <cfg>, "<zone>"

    zone --validate                         # syntax check; read the legend:
                                            # '*' defined, '~' not in cfg, '#' ineffective

    cfgsave                                 # saves definitions — does NOT activate
    cfgenable <cfg>                         # activates

That `cfgsave`/`cfgenable` distinction is the one that bites: saving a zone changes nothing on the wire until a configuration containing it is enabled.

Zones can also be written in domain,port form — `zonecreate <zone>, "2,1; 3,1"` — port numbers per switch domain. Aliases age better.

Deleting is the reverse, plus a reboot at the end of the notes:

    cfgdisable <cfg>
    cfgdelete <cfg>
    zonedelete <zone>
    alidelete <alias>
    cfgsave
    # ...and then a reboot, per the notes

And the archaeology commands, for copying an old zoning layout to a new date-stamped one instead of retyping it:

    zoneobjectcopy <cfg-2010>, <cfg-2014>
    zoneobjectexpunge <cfg>     # really gone

## Naming that reads like a map

The convention from these notes, worth copying: aliases say *what the port is* (`<storage>`, `<host>_hba0`, `<host>_hba1`), zones say *what connects to what*:

    zone: <host>_dev_hba0_<storage>_1a
          <host_hba0>
          <storage_port_1a>

A `zoneshow` output in that convention is documentation by itself — every zone is a sentence: this host's HBA 0 talks to that storage's port 1a.

## SNMP

Access list first, then the v3 users — both are interactive walks:

    snmpConfig --set accessControl      # one host subnet per prompt, ro/rw each
    snmpConfig --set snmpv3             # users, auth/priv protocols, trap recipients

The v3 walk takes user names, auth protocol (MD5/SHA/none), priv protocol (DES/AES/none) and passwords inline, then trap recipients with severity and port — the notes show it end to end, mistakes included. For a monitoring box that only speaks v1: `snmpConfig --set snmpv1`, plus the same accessControl walk.

## The Cisco MDS cousin

Not every SAN switch speaks Fabric OS. The same era's Cisco MDS (IBM-branded 9124) answers in IOS grammar, and the management interface is where the lockdown happens:

    configure terminal
    snmp-server community <community> ro
    snmp-server community <community> group network-operator
    ip access-list mgmtacl permit udp <monitoring-host> <wildcard> any eq snmp
    ip access-list mgmtacl permit tcp any any eq ssh
    ip access-list mgmtacl permit tcp any any eq 443
    ip access-list mgmtacl permit icmp any any
    ip access-list mgmtacl deny ip any any
    interface mgmt 0
    ip access-group mgmtacl in
    write memory

Two things these notes earn their keep with:

- **Read ACLs top-down.** The original note had `deny ip any any` *before* the icmp permit — a dead line, ICMP unreachable forever, nobody the wiser until someone read the order. The deny goes last.
- **An edit to an already-applied ACL does not take effect until the ACL is detached and reattached:**

        interface mgmt 0
        no ip access-group mgmtacl in
        ip access-group mgmtacl in

  Change, reattach, then believe the config.

## Web UI

The HTTP listener is visible in the config dump: `configshow 'http'` — worth checking on a switch that should not have one.

---

*This saved you a night? I do this for a living: [info@wirt.ee](mailto:info@wirt.ee).*
