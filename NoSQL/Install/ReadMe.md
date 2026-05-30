# <img src="../../Assets/pics/MongoDB.svg" width="35" alt="NoSQL management scripts"> MongoDB Installation Scripts

[![MongoDB](https://img.shields.io/badge/MongoDB-004d39?style=flat&logo=mongodb&logoColor=white&logoSize=auto&labelColor=00e600)](https://www.mongodb.com/)
[![Debian](https://img.shields.io/badge/Debian-607078?style=flat&logo=debian&logoColor=white&logoSize=auto&labelColor=a81d33)](https://www.debian.org/)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-607078?style=flat&logo=ubuntu&logoColor=white&logoSize=auto&labelColor=e95420)](https://ubuntu.com/download)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

This repository contains PowerShell and Bash scripts designed to help DBAs and DevOps engineers automate MongoDB installation tasks.

## 🚀 Features

- 📂 [Automated SQL Server Installation](./Install/) (Windows, Linux, Docker)
- [Install MongoDB on Debian](./inst_mongo_debian.sh) - includes:
  Error Handling, Root previlages, Quiet mode, Dynamic Debian code detection, Error checking for gpt key

## 🚀 Updating/Installing Mongo Shell CLI and Mongo Atlas CLI on Windows/Linux:

- 📂 [Update-MongoDBAtlasCli.ps](./Update-MongoDBAtlasCli.ps1) → this is `powershell` script to `Install`/`Update` **Mongo Atlas CLI** on **Windows**.
- 📂 [Update-MongoShell.ps1](./Update-MongoShell.ps1) → this is `powershell` script to `Install`/`Update` **Mongo Shell** on **Windows**.
- 📂 [update-mongoAtlas.sh](./update-mongoAtlas.sh) → this is `bash` script to `Install`/`Update` **Mongo Atlas CLI** on **Debian**/**Ubuntu**.
- 📂 [update-mongoShell.sh](./update-mongoShell.sh) → this is `bash` script to `Install`/`Update` **Mongo Shell CLI** on **Debian**/**Ubuntu**.

---

🔙 [back to Databases repo](../)
