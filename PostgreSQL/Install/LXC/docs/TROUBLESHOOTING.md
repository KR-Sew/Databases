# Troubleshooting

## `postgresql.service` says active (exited)

On Debian/Ubuntu:

```text
postgresql.service
```

is an umbrella service and can show:

```text
active (exited)
```

even when the actual cluster is down.

Check:

```bash
pg_lsclusters
systemctl status postgresql@18-main --no-pager
```

Logs:

```bash
journalctl -u postgresql@18-main -n 50 --no-pager
tail -50 /var/log/postgresql/postgresql-18-main.log
```

## PostgreSQL cannot find postgresql.conf with `postgres -D`

Debian separates the data and configuration directories.

Data:

```text
/var/lib/postgresql/18/main
```

Configuration:

```text
/etc/postgresql/18/main/postgresql.conf
```

Therefore this can fail:

```bash
/usr/lib/postgresql/18/bin/postgres \
    -D /var/lib/postgresql/18/main \
    -C ssl_cert_file
```

Use:

```bash
sudo -u postgres \
    /usr/lib/postgresql/18/bin/postgres \
    -D /var/lib/postgresql/18/main \
    -c config_file=/etc/postgresql/18/main/postgresql.conf \
    -C ssl_cert_file
```

Or query the running server:

```bash
sudo -u postgres psql -Atc "SHOW ssl_cert_file;"
```

## PostgreSQL cannot read server.key

The file may be correct while its parent directory blocks traversal.

Recommended:

```bash
chown root:postgres /etc/postgresql/ssl
chmod 750 /etc/postgresql/ssl

chown postgres:postgres /etc/postgresql/ssl/server.key
chmod 600 /etc/postgresql/ssl/server.key
```

Test:

```bash
sudo -u postgres test -r /etc/postgresql/ssl/server.key &&
echo "server.key OK"
```

## OpenSSL says `invalid object identifier ... severAuth`

This is a typo.

Wrong:

```text
extendedKeyUsage = severAuth
```

Correct:

```text
extendedKeyUsage = serverAuth
```

## `sslmode=disable` fails with `no encryption`

When the matching HBA entry is:

```text
hostssl ...
```

this failure is expected and desirable. It proves non-TLS connections do not match an authentication rule.

## TCP/5432 is unreachable

Check PostgreSQL first:

```bash
ss -lntp | grep 5432
sudo -u postgres psql -c "SHOW listen_addresses;"
```

Then from the client:

```powershell
Test-NetConnection 10.10.205.101 -Port 5432
```

If PostgreSQL listens correctly but the TCP test fails, investigate routing/firewalls rather than `pg_hba.conf`.

## `verify-full` hostname mismatch

The connection hostname must match a certificate SAN.

For this lab:

```text
DNS:pg.lightcyber.ru
```

Connect using:

```text
host=pg.lightcyber.ru
```

Connecting to `10.10.205.101` with `verify-full` is not equivalent unless the certificate also contains that IP address as an IP SAN.

## PKCS#12 reports invalid password

PostgreSQL does not require the `.p12` bundle when separate PEM certificate and key files are available. Do not weaken or expose key material just to make the PKCS#12 file work.
