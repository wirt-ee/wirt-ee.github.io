---
title: Cinder
---

## Procedure and justification  

Old storage needs to be decommissioned. It's the nature of IT operations.  
And cloud is not an exception. In that context, OpenStack Cinder storage retype functionality seems easy to use and feature-complete.  
Unfortunately, it is pushing everything through Python (0.3 TB/h) and may end with files filled with emptiness or just an unrecoverably crashed state. If you then reset its state, you may end up wiping the last healthy source and replacing it with a heavily corrupted source. And if you are doing entire cloud storage retyping from one vendor to another for the fourth time under a restrictive SLA, it's time to rethink some processes.  


👉 This is a high-level overview of how we achieve a storage migration speed of up to 6TB/h without a corruption risk:  

* Find attached volumes ID, actual NAME_ID, secrets, etc.  
* Detect the maintenance window, VM state and stop it.  
* Flatten snapshots, kiss goodbye for sparse disks.  
* Determine whether it's a bootable or data disk.  
* Sync storage backends.  
* Update DB nova block_device_mapping, volume_attachment ...  
* Regenerate the VM definition on the hypervisor.  
* Start VM.  

## Devil is in the details  
To reflect the new reality, the Nova and Cinder databases need to be updated. Adjust to your needs.  

```
nova_block_device_mapping_connection_info="{\"driver_volume_type\": \"rbd\", \"data\": {\"name\": \"cinder-pool-name/volume-${volume_name_id}\", \"hosts\": [\"${ceph_mon1}\", \"${ceph_mon2}\", \"${ceph_mon3}\"], \"ports\": [\"6789\", \"6789\", \"6789\"], \"cluster_name\": \"xxx\", \"auth_enabled\": true, \"auth_username\": \"xxx\", \"secret_type\": \"ceph\", \"secret_uuid\": \"${ceph_secret}\", \"volume_id\": \"${volume_id}\", \"discard\": true, \"qos_specs\": null, \"access_mode\": \"rw\", \"encrypted\": false, \"cacheable\": false}, \"status\": \"reserved\", \"instance\": \"${server_id}\", \"attached_at\": \"\", \"detached_at\": \"\", \"volume_id\": \"${volume_id}\", \"serial\": \"${volume_id}\"}"
```
```
cinder_volume_attachment_connection_info="{\"name\": \"cinder-volumes/volume-${volume_name_id}\", \"hosts\": [\"${ceph_mon1}\", \"${ceph_mon2}\", \"${ceph_mon3}\"], \"ports\": [\"6789\", \"6789\", \"6789\"], \"cluster_name\": \"xxx\", \"auth_enabled\": true, \"auth_username\": \"xxx\", \"secret_type\": \"ceph\", \"secret_uuid\": \"${ceph_secret}\", \"volume_id\": \"${volume_name_id}\", \"discard\": true, \"qos_specs\": null, \"access_mode\": \"rw\", \"encrypted\": false, \"cacheable\": false, \"driver_volume_type\": \"rbd\", \"attachment_id\": \"${attachment_id}\"}"
```

```
mysql -e "update nova.block_device_mapping set connection_info='${nova_block_device_mapping_connection_info}' where volume_id='${volume_id}' and deleted='0' limit 1;"
mysql -e "update cinder.volume_attachment set connection_info='${cinder_volume_attachment_connection_info}' where volume_id='${volume_id}' and deleted='0' limit 1;"
mysql -e "update cinder.volumes set host='${volume_host}',volume_type_id='${volume_dst_type_id}',cluster_name='${cluster_name}' where id='${volume_id}' and deleted='0' limit 1;"
```
