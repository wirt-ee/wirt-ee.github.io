---
title: SSH(1) 
---
## SOCS5 proxy
It allows you to browse the web via a proxy machine. Configure the browser SOCS5 proxy address localhost or 127.0.0.1 and port 1337.


```
ssh -Nf -D 1337 username@remote-proxy-host
```

## Port forwarding
ssh -L from your machine to the remote and then forward connections from your workstation port X to the remote port Y.  
ssh -R from remote to your local workstation and then forward connections from your workstation port X to remote port Y.

```
ssh -L 1337:localhost:1337 username@remote-proxy-host
ssh -R 1337:localhost:1337 username@my-local-machine
```
