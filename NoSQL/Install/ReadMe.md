# <img src="../../Assets/pics/MongoDB.svg" width="35" alt="NoSQL management scripts"> MongoDB Installation Scripts

[![MongoDB](https://img.shields.io/badge/MongoDB-004d39?style=flat&logo=mongodb&logoColor=white&logoSize=auto&labelColor=00e600)](https://www.mongodb.com/)
[![Debian](https://img.shields.io/badge/Debian-607078?style=flat&logo=debian&logoColor=white&logoSize=auto&labelColor=a81d33)](https://www.debian.org/)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-607078?style=flat&logo=ubuntu&logoColor=white&logoSize=auto&labelColor=e95420)](https://ubuntu.com/download)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

This repository contains PowerShell and Bash scripts designed to help DBAs and DevOps engineers automate MongoDB installation tasks.

## 🚀 Installing MongoDB on Windows/Linux:

- 📂 [Automated SQL Server Installation](./Install/) (Windows, Linux, Docker)
- [Install MongoDB on Debian](./inst_mongo_debian.sh) - includes:
  Error Handling, Root previlages, Quiet mode, Dynamic Debian code detection, Error checking for gpt key

## 🚀 Updating/Installing Mongo Shell CLI and Mongo Atlas CLI on Windows/Linux:

- For **Windows systems**:

  [![Windows Server](https://custom-icon-badges.demolab.com/badge/Windows%20Server-Microsoft-0078D6?style=flat&logo=ms-windows-server&logoColor=white)](https://www.microsoft.com/en-us/windows-server/)
  [![PowerShell](https://custom-icon-badges.demolab.com/badge/.-PowerShell-blue.svg?style=flat&logo=powershell-core-eyecatch32&logoColor=white)](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.5)
  [![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue?logo=powershell)](https://docs.microsoft.com/en-us/powershell/)
  [![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

  - 📂 [Update-MongoDBAtlasCli.ps](./Update-MongoDBAtlasCli.ps1) → this is `powershell` script to `Install`/`Update` **Mongo Atlas CLI** on **Windows**.
  - 📂 [Update-MongoShell.ps1](./Update-MongoShell.ps1) → this is `powershell` script to `Install`/`Update` **Mongo Shell** on **Windows**.
- For **Debian/Ubuntu**:
  
  [![Debian](https://img.shields.io/badge/Debian-607078?style=flat&logo=debian&logoColor=white&logoSize=auto&labelColor=a81d33)](https://www.debian.org/)
  [![Ubuntu](https://img.shields.io/badge/Ubuntu-607078?style=flat&logo=ubuntu&logoColor=white&logoSize=auto&labelColor=e95420)](https://ubuntu.com/download)
  [![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)
  - 📂 [update-mongoAtlas.sh](./update-mongoAtlas.sh) → this is `bash` script to `Install`/`Update` **Mongo Atlas CLI** on **Debian**/**Ubuntu**.
  - 📂 [update-mongoShell.sh](./update-mongoShell.sh) → this is `bash` script to `Install`/`Update` **Mongo Shell CLI** on **Debian**/**Ubuntu**.
  - How to run:
  
   ```bash
      sudo chmod +x ./update-mongoShell.sh
      sudo bash ./update-mongoShell.sh
   ```

----

🔙 [back to Databases repo](../)
