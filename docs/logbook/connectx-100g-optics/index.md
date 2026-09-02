---
date: 2023-07-08
tags: [vyos, networking, optics, mellanox]
description: "A 100G link between two server rooms goes lossy; ConnectX-6 DX on a VyOS host reports 'Cable error, Power budget exceeded' on third-party LR optics."
---

# 100G AIOM: Power budget exceeded

Context: two server rooms, 1.5 km apart, to be connected directly at 100G over single-mode LR optics. Cards: NVIDIA/Mellanox ConnectX-6 DX, dual-port 100GbE QSFP28 in Supermicro **AIOM** (I/O module) format — in a router: the endpoints of this link are VyOS firewalls. The power problem is the AIOM's, not the router's. Optics: third-party QSFP28-LR4-100G. The first symptom was not an error message — the link was quietly lossy:

    # ethtool -S eth5 | grep err | grep -v ' 0'
     rx_crc_errors_phy: 13147323
     rx_symbol_err_phy: 13115284
     rx_err_lane_0_phy: 13115284
     rx_err_lane_1_phy: 13115284
     rx_err_lane_2_phy: 13115284
     rx_err_lane_3_phy: 13115284

All four lanes, in the millions — not a dirty fiber on one lane, the module as a whole was not coming up clean. Then dmesg said why:

    mlx5_core 0000:81:00.0: port_module:252:(pid 0): Port module
    event[error]: module 0, Cable error, Power budget exceeded

**Power budget exceeded** means the AIOM port refuses to power the module: at firmware 22.31.1014 the adapter did not drive this third-party LR optic. ConnectX-6 DX has a supported-optics list, and a module missing from it draws more than the port is willing to give.

## Stopgap

Keep the rooms talking while the real fix is worked out — lock the port down:

    ethtool -s eth5 speed 10000 duplex full autoneg off

## Firmware update

The card firmware path, on the VyOS host itself (Debian base — which is why this entry is filed under VyOS as much as networking):

    # MLNX_OFED packages for your Debian release
    dpkg -i mlnx-tools_23.04-..._amd64.deb mstflint_4.16.1-..._amd64.deb
    dpkg -i mlnx-fw-updater_23.04-..._amd64.deb mlnx-en-utils_..._amd64.deb

    # the annoying part on a router distro: dependency chasing (libssl1.1),
    # apt sources pointing at the wrong release, resolv.conf on a
    # freshly-booted image — solve them, then:

    mlxfwmanager -u -i fw-ConnectX6Dx-rel-22_32_2004-....bin

    Found 2 device(s) requiring firmware update...
    Device #1: Updating FW ...  Writing Boot image component -  OK
    Device #2: Updating FW ...  Writing Boot image component -  OK
    Restart needed for updates to take effect.

Versions moved 22.31.1014 → 22.32.2004 (FW), 3.6.0403 → 3.6.0502 (PXE), 14.24.0013 → 14.25.0018 (UEFI).

## Takeaways

- `Cable error, Power budget exceeded` is not a broken cable — check the vendor's supported-optics list before blaming the fiber.
- `ethtool -S | grep err` is the first look at a lossy link; all lanes in error points at the module, not one dirty connector.
- `mlxfwmanager` does the update in a minute; the OFED deb dependency dance on a router OS is the part that takes the evening.
- Third-party optics on expensive NICs: budget for the possibility that the combination is simply not supported, and ask the vendor early — with the dmesg line quoted.

Related: the same VyOS pair's burn-in trail is [here](../vyos-three-years/index.md).

---

*This saved you a night? I do this for a living: [info@wirt.ee](mailto:info@wirt.ee).*
