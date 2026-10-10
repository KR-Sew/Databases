# Networking

## Lab networks

```text
10.10.101.0/24    workstation/LAN VLAN
10.10.254.0/24     LXD VM network
```

The PostgreSQL VM used:

```text
IP      10.10.254.101/24
Gateway 10.10.254.253
```

The LXD host had:

```text
lxdbr0-vm 10.10.254.253/24
```

The VM NIC was attached to the unmanaged Linux bridge:

```bash
lxc config device add pgsql01 eth0 nic \
    nictype=bridged \
    parent=lxdbr0-vm \
    name=eth0
```

Inside Debian it appeared as `enp5s0`.

## Routing test

From Windows:

```powershell
Test-NetConnection 10.10.254.101 -Port 5432
```

If this fails while PostgreSQL is listening on `10.10.254.101:5432`, troubleshoot routing and firewalls before changing PostgreSQL.

## Public access

A router such as MikroTik can perform destination NAT:

```text
Public IP:external-port -> 10.10.254.101:5432
```

Recommendations:

- permit only known source public IPs when possible;
- prefer a VPN when direct database publication is unnecessary;
- do not treat a non-standard external port as a security boundary;
- use `hostssl`, SCRAM and `sslmode=verify-full`.

## Hairpin NAT

If `pg.lightcyber.ru` resolves publicly to the router, LAN clients may require hairpin NAT.

For testing only, an internal client can instead resolve:

```text
10.10.205.101 pg.lightcyber.ru
```

via split DNS or its hosts file. The hostname must remain `pg.lightcyber.ru` so TLS hostname verification matches the certificate SAN.
