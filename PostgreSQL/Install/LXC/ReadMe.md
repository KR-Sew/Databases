# <img src="../../../Assets/pics/icons8-postgresql-48.svg" width="25" alt="PostgreSQL Automated Installation"> PostgreSQL 18 in an LXD VM with TLS

[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-336791?style=flat&logo=postgresql&logoColor=white&logoSize=auto&labelColor=5197e1)](https://www.postgresql.org/)
[![LXC/LXD](https://custom-icon-badges.demolab.com/badge/LXC_LXD-Containers-607078?style=flat&logo=lxd-lxc_logo&logoColor=grey&logoSize=auto&labelColor=grey)](https://documentation.ubuntu.com/lxd/stable-5.21/)
[![Docker](https://img.shields.io/badge/Docker-2496ED?style=flat&logo=docker&logoColor=white)](https://hub.docker.com/)
[![Debian](https://img.shields.io/badge/Debian-607078?style=flat&logo=debian&logoColor=white&logoSize=auto&labelColor=a81d33)](https://www.debian.org/)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-607078?style=flat&logo=ubuntu&logoColor=white&logoSize=auto&labelColor=e95420)](https://ubuntu.com/download)
[![Bash](https://img.shields.io/badge/Bash-4EAA25?style=flat&logo=gnubash&logoColor=white&logoSize=auto&labelColor=black)](https://www.gnu.org/software/bash/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

A reproducible **How-To** for deploying **PostgreSQL 18** inside a **Debian 13** `LXD` virtual machine, enabling restricted remote access, enforcing TLS, and using a publicly trusted **Let's Encrypt** certificate.

## Lab topology

```text
Windows workstation
10.10.101.108
        |
        | routed TCP/5432
        v
LXD host (Debian 13)
        |
        | lxdbr0-vm
        | 10.10.254.253/24
        v
pgsql01
10.10.254.101/24
PostgreSQL 18 :5432
        |
        +-- labdb
        +-- labuser
        +-- SCRAM-SHA-256
        +-- TLS / hostssl
        +-- pg.lightcyber.ru
```

For Internet access, a router/firewall can destination-NAT a public TCP port to `10.10.254.101:5432`. Restrict source addresses whenever possible; exposing PostgreSQL to the entire Internet is not recommended.

## Environment used

- **LXD 5.21.6 LTS**
- **Debian 13** (Trixie) VM
- **ZFS**-backed `LXD` storage pool: `lxdpool`
- VM bridge: `lxdbr0-vm`
- VM address: `10.10.254.101/24`
- Gateway: `10.10.254.253`
- **PostgreSQL 18.6** from PGDG
- Database: `labdb`
- Login role: `labuser`
- DNS: `pg.lightcyber.ru`
- TLS certificate: **Let's Encrypt**, issued through **Selectel** (in my case)
  - You can use original cerficate isssued by **Let's Encrypt** using **Certbot** or **ACME**

Adjust addresses, names and credentials for your own environment.

## 1. Create the LXD VM

Inspect the host first:

```bash
lxc version
lxc network list
lxc storage list
lxc profile show default
ip -br addr
```

Create the VM:

```bash
lxc init images:debian/13 pgsql01 \
    --vm \
    --storage lxdpool

lxc config set pgsql01 limits.cpu=2
lxc config set pgsql01 limits.memory=4GiB

lxc config device add pgsql01 eth0 nic \
    nictype=bridged \
    parent=lxdbr0-vm \
    name=eth0

lxc start pgsql01
```

Check networking:

```bash
lxc list pgsql01
lxc exec pgsql01 -- ip -br addr
lxc exec pgsql01 -- ip route
```

The lab VM received `10.10.254.101/24`. Its interface appeared inside the VM as `enp5s0`; predictable interface naming means it does not have to appear as `eth0`.

## 2. Install PostgreSQL 18 from PGDG

Enter the VM:

```bash
lxc exec pgsql01 -- bash
```

Install prerequisites:

```bash
apt update
apt install -y curl ca-certificates gnupg postgresql-common
```

Configure the official PostgreSQL repository:

```bash
/usr/share/postgresql-common/pgdg/apt.postgresql.org.sh
apt update
```

Check the candidate:

```bash
apt-cache policy postgresql-18
```

Install PostgreSQL:

```bash
apt install -y postgresql-18 postgresql-client-18
```

Or use:

```bash
sudo ./scripts/01-install-postgresql.sh
```

## 3. Understand the Debian layout

Debian separates PostgreSQL configuration and data:

```text
/etc/postgresql/18/main/
├── postgresql.conf
├── pg_hba.conf
└── pg_ident.conf

/var/lib/postgresql/18/main/     # database data
/var/log/postgresql/            # logs
```

Ask PostgreSQL directly:

```bash
sudo -u postgres psql -c "SHOW config_file;"
sudo -u postgres psql -c "SHOW hba_file;"
sudo -u postgres psql -c "SHOW data_directory;"
```

Check the cluster:

```bash
pg_lsclusters
```

Expected:

```text
Ver Cluster Port Status Owner    Data directory
18  main    5432 online postgres /var/lib/postgresql/18/main
```

## 4. Create the database and login role

Check password encryption:

```bash
sudo -u postgres psql -c "SHOW password_encryption;"
```

Expected:

```text
scram-sha-256
```

Enter PostgreSQL:

```bash
sudo -u postgres psql
```

Create a normal login role and database:

```sql
CREATE ROLE labuser
    WITH LOGIN
    PASSWORD 'CHANGE-ME-TO-A-STRONG-PASSWORD';

CREATE DATABASE labdb
    OWNER labuser;
```

Verify:

```sql
\du+ labuser
\l labdb
```

Do **not** make application roles superusers.

Test locally over TCP:

```bash
psql -h 127.0.0.1 -U labuser -d labdb -W
```

## 5. Enable network listening

Edit:

```text
/etc/postgresql/18/main/postgresql.conf
```

Use:

```conf
listen_addresses = 'localhost,10.10.254.101'
ssl = on
```

A reusable example is available in `configs/postgresql.conf.example`.

Restart after changing `listen_addresses`:

```bash
systemctl restart postgresql@18-main
```

Verify:

```bash
ss -lntp | grep 5432
sudo -u postgres psql -c "SHOW listen_addresses;"
```

Expected listeners include:

```text
127.0.0.1:5432
10.10.254.101:5432
[::1]:5432
```

## 6. Restrict access with pg_hba.conf

`listen_addresses` controls which **server addresses** listen.

`pg_hba.conf` controls which **clients/users/databases** may authenticate.

For the lab:

```conf
hostssl  labdb  labuser  10.10.254.0/24      scram-sha-256
hostssl  labdb  labuser  10.10.101.108/32   scram-sha-256
```

Use `hostssl`, not `host`, when remote connections must use TLS.

See `configs/pg_hba.conf.example`.

Validate:

```bash
sudo -u postgres psql -c "
SELECT line_number,type,database,user_name,address,auth_method,error
FROM pg_hba_file_rules
WHERE error IS NOT NULL;
"
```

Expected:

```text
(0 rows)
```

Reload:

```bash
systemctl reload postgresql@18-main
```

## 7. Test from Windows

First prove basic routing/firewall connectivity:

```powershell
Test-NetConnection 10.10.254.101 -Port 5432
```

Expected:

```text
TcpTestSucceeded : True
```

Connect with TLS:

```powershell
psql "host=10.10.205.101 port=5432 dbname=labdb user=labuser sslmode=require"
```

Inside `psql`:

```text
\conninfo
```

The lab negotiated:

```text
SSL Protocol : TLSv1.3
SSL Cipher   : TLS_AES_256_GCM_SHA384
```

Now prove TLS is mandatory:

```powershell
psql "host=10.10.254.101 port=5432 dbname=labdb user=labuser sslmode=disable"
```

Expected failure:

```text
FATAL: no pg_hba.conf entry ... no encryption
```

That is a successful security test: `hostssl` is enforcing TLS.

## 8. Why sslmode=require is not enough

`sslmode=require` encrypts the connection but does not provide the same hostname verification as `verify-full`.

The preferred final connection is:

```text
sslmode=verify-full
```

This verifies:

1. the connection is encrypted;
2. the certificate chains to a trusted CA;
3. the certificate is valid for the requested hostname.

## 9. DNS and Let's Encrypt

Create a DNS record such as:

```text
pg.lightcyber.ru
```

The certificate used in this lab was issued by Let's Encrypt through Selectel and contained:

```text
CN=lightcyber.ru
SAN=DNS:lightcyber.ru,DNS:pg.lightcyber.ru
```

Selectel supplied:

```text
public.pem
private.pem
chain.p12
```

`public.pem` contained three certificates and therefore included the certificate chain.

Before installation, inspect it:

```bash
openssl x509 \
    -in public.pem \
    -noout \
    -subject \
    -issuer \
    -dates \
    -ext subjectAltName

grep -c "BEGIN CERTIFICATE" public.pem
```

Verify the certificate and private key are a pair:

```bash
openssl x509 \
    -in public.pem \
    -pubkey -noout |
openssl pkey -pubin -outform DER |
sha256sum

openssl pkey \
    -in private.pem \
    -pubout -outform DER |
sha256sum
```

The hashes **must match**.

## 10. Install the certificate

Copy the Selectel files to a protected temporary directory, then run:

```bash
sudo ./scripts/02-install-certificate.sh \
    /root/selectel-cert/public.pem \
    /root/selectel-cert/private.pem
```

The script installs them as:

```text
/etc/postgresql/ssl/server.crt
/etc/postgresql/ssl/server.key
```

The recommended permissions are:

```text
/etc/postgresql/ssl             root:postgres      750
server.crt                      postgres:postgres  644
server.key                      postgres:postgres  600
```

Configure PostgreSQL:

```conf
ssl = on
ssl_cert_file = '/etc/postgresql/ssl/server.crt'
ssl_key_file  = '/etc/postgresql/ssl/server.key'
```

Restart the real cluster:

```bash
systemctl restart postgresql@18-main
pg_lsclusters
```

## 11. Test verify-full

For an internal LAN test, if public DNS resolves to the router's public address and hairpin NAT is not configured, temporarily map the hostname on the Windows client:

```text
10.10.205.101    pg.lightcyber.ru
```

in:

```text
C:\Windows\System32\drivers\etc\hosts
```

Then:

```powershell
psql "host=pg.lightcyber.ru port=5432 dbname=labdb user=labuser sslmode=verify-full"
```

With a publicly trusted Let's Encrypt chain, no private lab CA should be required, provided the local libpq/OpenSSL trust configuration has access to the appropriate public roots.

Inside PostgreSQL:

```sql
\conninfo

SELECT
    a.usename,
    a.client_addr,
    s.ssl,
    s.version,
    s.cipher
FROM pg_stat_activity AS a
JOIN pg_stat_ssl AS s USING (pid)
WHERE a.pid = pg_backend_pid();
```

## 12. Internet publishing

A typical final path is:

```text
Remote client / VPS
        |
        | pg.lightcyber.ru
        v
Public router/firewall
        |
        | dst-NAT + firewall
        v
10.10.205.101:5432
        |
        +-- hostssl
        +-- SCRAM-SHA-256
        +-- Let's Encrypt TLS
        +-- PostgreSQL 18
```

Prefer firewall rules that permit only known remote source IP addresses. A VPN is even better when public PostgreSQL access is unnecessary.

Changing the external NAT port can reduce scanner noise but is **not** a security control by itself.

## 13. Health check

Run:

```bash
sudo ./scripts/03-check-postgresql.sh
```

It checks the cluster, listeners, PostgreSQL version, TLS configuration, certificate identity and HBA parse errors.

## Security notes

- Never use `host all all 0.0.0.0/0 trust`.
- Do not remotely use the `postgres` superuser for applications.
- Prefer `/32` client entries where practical.
- Use `hostssl` for TLS-only access.
- Keep private keys mode `600`.
- Never commit passwords, certificates containing private keys, `.p12` bundles or `private.pem`.
- Prefer `sslmode=verify-full` for remote clients.
- Restrict Internet-facing 5432 at the firewall.
- Plan certificate renewal deployment: renewal in a certificate service does not automatically replace the copy installed on the PostgreSQL VM.

## Useful commands

```bash
pg_lsclusters
systemctl status postgresql@18-main --no-pager
ss -lntp | grep 5432

sudo -u postgres psql -c "SELECT version();"
sudo -u postgres psql -c "SHOW ssl;"
sudo -u postgres psql -c "SHOW ssl_cert_file;"
sudo -u postgres psql -c "SHOW ssl_key_file;"
sudo -u postgres psql -c "SHOW listen_addresses;"
```

See `docs/TROUBLESHOOTING.md` for the problems encountered while building this lab.
