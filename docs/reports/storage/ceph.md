---
title: Ceph
---
## Get CEPH backup
It is great when you have a backup or you don't destroy your network under an erasure-coded pool.

```
rbd export -p  pool volume-ad0ceef0-64ef-4050-afd6-3a12c13dd6be ./volume-ad0ceef0-64ef-4050-afd6-3a12c13dd6be.bac
```

## Restore CEPH from backup

```
rbd rm pool volume-ad0ceef0-64ef-4050-afd6-3a12c13dd6be
rbd import ./volume-ad0ceef0-64ef-4050-afd6-3a12c13dd6be.bac  pool/volume-ad0ceef0-64ef-4050-afd6-3a12c13dd6be
```

## Manipulate CEPH block storage (VM disk)
From time to time, you need to do some artwork inside VM. To do so, you first need to be able to mount RBD.

```
rbd export <pool>/<volume> /tmp/<uuid> #backup if needed
dev=$(rbd map  <pool>/<volume> )
sgdisk --print ${dev} #record current layout
rbd showmapped
rbd unmap ${dev}
```
