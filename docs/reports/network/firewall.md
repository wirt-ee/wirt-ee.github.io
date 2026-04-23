---
title: VyOS firewall
---
##VyOS 1.5.x ISO using Docker
You can run the HA production cluster with this if you are brave (and experienced).  
```
git clone -b current --single-branch https://github.com/vyos/vyos-build
cd vyos-build/
docker run --rm -it --privileged -v $(pwd):/vyos -w /vyos vyos/vyos-build:current bash
vyos_bld@f6cbbb83c7d1:/vyos$ sudo make clean
vyos_bld@5b5d83d5d5c0:/vyos$ sudo ./build-vyos-image  generic --architecture amd64 --build-by "wirt"
```

