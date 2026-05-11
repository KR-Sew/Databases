# <img src="../../../Assets/pics/icons8-mysql-48.svg" width="35" alt="MySQL"> MySQL & MariaDB <img src="../../../Assets/pics/icons8-mariadb-48.svg" width="35" alt="MariaDB"> Solving InnoDB logs redo issue

These are two scripts that solving logs redo issues like `#ib_redo1` `#ib_redo2` `#innodb_redo`

## 🚀 Description

**How to run**:

- First run [**mysql-step1-inspect-backup.sh**](./mysql-step1-inspect-backup.sh)
  - this script is inspecting to find certain redo error and then backup them
  
  ```bash
     chmod +x mysql-step1-inspect-backup.sh # mark the script executable
     sudo ./mysql-step1-inspect-backup.sh   # run with sudo elevation
  ```

- Then run [**mysql-step2-recover-dump-rebuild.sh**](./mysql-step2-recover-dump-rebuild.sh)
  - this script is trying to **recover** and strat `mysql` service without **rebuild**

  ```bash
    chmod +x mysql-step2-recover-dump-rebuild.sh
    sudo ./mysql-step2-recover-dump-rebuild.sh
  ```

- If the service `mysql` successfully **recoverd** and started and **dump** is created successfully, try to **rebuild**:
  
  ```bash
    sudo ./mysql-step2-recover-dump-rebuild.sh --rebuild-after-dump
  ```

---

🔙 [back to MySQL repo](../)
