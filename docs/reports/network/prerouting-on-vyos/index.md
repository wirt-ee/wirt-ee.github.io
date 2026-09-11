# Prerouting on VyOS  
The prerouting hook is the earliest point in the packet path, before connection tracking (conntrack). The packet's fate is decided before the kernel allocates a conntrack entry, so action drop discards junk at the cheapest possible stage. The main uses are DDoS/abuse filtering at line rate and protecting the conntrack table itself by dropping a SYN flood.

## SYN footgun  
If your generated nftables rule contains TCP, it counts ALL traffic. If it does not, you are on the right track:

```
nft list chain ip vyos_filter NAME_SYN-ABUSE-POLICY
    meta l4proto tcp add @RECENT{...} tcp flags syn/syn,ack ...   #BROKEN: 6.35M all-TCP packets fed the meter                    
    add @RECENT{...} ... (no flags; entered via SYN-gated jump)   #FIXED: 1.94M SYNs fed the meter, 494 over-rate, 0 false 
```

## Egress throttle
Never trust your tenants. As a landlord, you have a reputation to keep. It is super hard to get out of someone else's blocklist.
Here is a basic decision tree to help design a VyOS firewall ruleset.   

![tcp-syn-limit](https://lh3.googleusercontent.com/d/1rU_OJk-FZ-KOrg0fe9rQOMAV4jr47nXW)


---

*This saved you a night? I do this for a living: [info@wirt.ee](mailto:info@wirt.ee).*
