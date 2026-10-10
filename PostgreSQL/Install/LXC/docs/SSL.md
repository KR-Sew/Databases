# PostgreSQL TLS notes

## sslmode levels

Important libpq modes include:

```text
require       encrypt the connection
verify-ca     encrypt and verify the issuing CA
verify-full   encrypt, verify CA and verify hostname
```

Use `verify-full` for the final remote configuration.

## Debian default certificate

A fresh Debian PostgreSQL installation may use:

```text
/etc/ssl/certs/ssl-cert-snakeoil.pem
/etc/ssl/private/ssl-cert-snakeoil.key
```

In this lab it was self-signed with:

```text
CN=pgsql01
SAN=DNS:pgsql01
```

This can encrypt traffic but is unsuitable for public hostname verification of `pg.lightcyber.ru`.

## Let's Encrypt certificate

The Selectel-issued certificate contained:

```text
CN=lightcyber.ru
SAN=DNS:lightcyber.ru,DNS:pg.lightcyber.ru
Issuer=Let's Encrypt YR1
```

Selectel provided:

```text
public.pem
private.pem
chain.p12
```

`public.pem` contained three PEM certificates.

PostgreSQL uses:

```text
public.pem  -> /etc/postgresql/ssl/server.crt
private.pem -> /etc/postgresql/ssl/server.key
```

The PKCS#12 bundle is not required by PostgreSQL.

## Permissions

Use:

```bash
chown root:postgres /etc/postgresql/ssl
chmod 750 /etc/postgresql/ssl

chown postgres:postgres /etc/postgresql/ssl/server.crt
chmod 644 /etc/postgresql/ssl/server.crt

chown postgres:postgres /etc/postgresql/ssl/server.key
chmod 600 /etc/postgresql/ssl/server.key
```

Do not make the private key world-readable.

## Verify certificate/key pairing

```bash
openssl x509 -in public.pem -pubkey -noout |
openssl pkey -pubin -outform DER |
sha256sum

openssl pkey -in private.pem -pubout -outform DER |
sha256sum
```

Both hashes must match.

## Certificate renewal

Let's Encrypt certificates are short-lived. If a certificate manager renews the certificate remotely, that does **not** automatically update the files copied onto the PostgreSQL VM.

Automate deployment so that renewal eventually performs:

```text
renew certificate
       |
copy new public.pem/private.pem
       |
verify certificate/key pair
       |
install with safe permissions
       |
reload/restart PostgreSQL
```

Never commit `private.pem`, `server.key` or PKCS#12 bundles to Git.
