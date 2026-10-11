# <img src="../../Assets/pics/MongoDB.svg" width="35" alt="NoSQL management scripts"> MongoDB Backup Scripts

[![MongoDB](https://img.shields.io/badge/MongoDB-004d39?style=flat&logo=mongodb&logoColor=white&logoSize=auto&labelColor=00e600)](https://www.mongodb.com/)
[![Debian](https://img.shields.io/badge/Debian-607078?style=flat&logo=debian&logoColor=white&logoSize=auto&labelColor=a81d33)](https://www.debian.org/)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-607078?style=flat&logo=ubuntu&logoColor=white&logoSize=auto&labelColor=e95420)](https://ubuntu.com/download)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

This repository contains scripts designed to automate **MongoDB** backup & restore tasks.

## 🚀 Features

- 📂 [Backup & Restore](./Backup/) → Scheduled backups with retention policies.

    - [**`backup_cluster`**](./backup_cluster.sh)
      - backup Atlas cluster databases bash script
      - How to run:
  
      ```bash
         sudo chmod +x ./backup_cluster.sh
         sudo bash ./backup_cluster.sh
      ```

    - [**`backup_mongodb`**](./backup_mongodb.sh)
      - backup **MongoDb** database bash script
    - [**`create_snapsho_dump`**](./Create_Snapshot_Dump.sh)
    - create snapshot or dump database bash script
    - [**`create_snapshot_lvm_cloud`**](./Create_SnapShot_LVM-Cloud.sh)

---

🔙 [back to **`Databases`** repo](../)
