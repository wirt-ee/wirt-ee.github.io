# Glance


## OpenStack glance image modification on the backend  
Normal image creation also creates a new UUID even if the name is the same. If you are uploading a fresh copy of the OS to the image service, it is an entirely new thing. Feature or a bug? Someone, somewhere, always manages to wipe out their machine with Terraform and friends when the image UUID changes in the OpenStack cloud. Since I don't like watching someone's life's work go up in smoke, I do image updates with a hack. As a bonus, the machine rescue functionality will remain operational because the UUID will stay the same.   

1. calculate image md5sum, sha512sum, and precise size   
2. replace the image on the storage backend
3. make a database update   

```
# du -b Rocky-9-GenericCloud-Base.latest.x86_64.qcow2
895746048	Rocky-9-GenericCloud-Base.latest.x86_64.qcow2
# md5sum Rocky-9-GenericCloud-Base.latest.x86_64.qcow2
08663eaaf6605bac65bfd9ec6c614996  Rocky-9-GenericCloud-Base.latest.x86_64.qcow2
# sha512sum Rocky-9-GenericCloud-Base.latest.x86_64.qcow2
ef373f4eedc02be817aaffcc4f3eeb4826e84c8d815151b850ed11b05d71ec36285589108e24be7974b58197aa03d0dfcff95061d5a33b9447e164b68a87816f  Rocky-9-GenericCloud-Base.latest.x86_64.qcow2
# cp Rocky-9-GenericCloud-Base.latest.x86_64.qcow2 /glance/images/014d4d6f-0752-440d-ba6a-0c1759463ac4


MariaDB [glance]> update images set os_hash_value='ef373f4eedc02be817aaffcc4f3eeb4826e84c8d815151b850ed11b05d71ec36285589108e24be7974b58197aa03d0dfcff95061d5a33b9447e164b68a87816f',checksum='08663eaaf6605bac65bfd9ec6c614996',size='895746048' where id='014d4d6f-0752-440d-ba6a-0c1759463ac4' limit 1;
Query OK, 1 row affected (0.001 sec)
Rows matched: 1  Changed: 1  Warnings: 0
```

---

*This saved you a night? I do this for a living: [info@wirt.ee](mailto:info@wirt.ee).*
