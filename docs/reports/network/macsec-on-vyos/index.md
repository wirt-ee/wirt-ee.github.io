# MACsec on VyOS

MACsec encrypts at layer 2 — the answer when the wire between two switches belongs to someone else and the traffic on it does not. On VyOS there are two ways: static keys, managed by hand; and MKA (MACsec Key Agreement), which needs wpa and exchanges keys for you. Both end with an interface you can route over.

## Static keys, three hosts

The key schedule for three hosts is two shared keys per link direction: every host transmits with its own key, and receives the other two. In this shape: A transmits key A1, B transmits B1, C transmits A2 — each host installs two receive rules for the other two.

Host A:

    ip link set eth2 down
    ip link add link eth2 macsec0 type macsec encrypt on
    ip macsec add macsec0 tx sa 0 pn 1 on key A1 <128-bit hex>
    # receive from B
    ip macsec add macsec0 rx address <mac-B> port 1
    ip macsec add macsec0 rx address <mac-B> port 1 sa 0 pn 1 on key B1 <128-bit hex>
    # receive from C
    ip macsec add macsec0 rx address <mac-C> port 1
    ip macsec add macsec0 rx address <mac-C> port 1 sa 0 pn 1 on key A2 <128-bit hex>
    ip addr add 192.0.2.1/24 dev macsec0
    ip link set eth2 up
    ip link set macsec0 up

Host B transmits with B1 and receives A1/A2; host C transmits with A2 and receives A1/B1. The VyOS config command for the same picture:

    set high-availability vrrp group MACSEC interface 'macsec1'
    set interfaces macsec macsec1 address '192.0.2.1/24'
    set interfaces macsec macsec1 security cipher 'gcm-aes-128'
    set interfaces macsec macsec1 security encrypt
    set interfaces macsec macsec1 source-interface 'eth2'
    set protocols static route 198.51.100.0/24 interface macsec1

## MKA variant

With MKA the keys are agreed, not installed; you provide the CAK (connectivity association key) and CKN (its name):

    set interfaces macsec macsec1 security mka cak '<32-byte hex>'
    set interfaces macsec macsec1 security mka ckn '<32-byte hex>'

All hosts in the group share the CAK/CKN pair. VRRP runs on top of the macsec interface like on any other.

## The virtual-hardware trap

MACsec key agreement uses EAPOL frames — and bridges drop them by default. On virtual hardware (libvirt and friends), open the hole or MKA never converges:

    ip link set virbr_3 type bridge group_fwd_mask 0x8

---

*This saved you a night? I do this for a living: [info@wirt.ee](mailto:info@wirt.ee).*
