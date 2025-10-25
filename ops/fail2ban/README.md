# Fail2ban for Traefik

These files let you protect Traefik (and any service fronted by it) from brute-force attempts by blocking IPs that trigger repeated HTTP 401 responses.

## Files

- `traefik/traefik-auth.conf` – failregex that matches Traefik access-log entries with status code 401.
- `traefik/jail.local.docker` – jail tuned for the Docker service (reads `/var/log/traefik/access.log`).
- `traefik/jail.local` – sample jail for running fail2ban directly on the host (update `logpath` to your Traefik access log).

## Docker (recommended)

The stack ships a `fail2ban` service in `docker-compose.yml` that:

- mounts Traefik’s access log at `/var/log/traefik/access.log`,
- loads `traefik-auth.conf` and `jail.local.docker`, and
- writes ban state to `appdata/fail2ban`.

Start and inspect it with:

```bash
docker compose up -d fail2ban
docker compose logs -f fail2ban
docker compose exec fail2ban fail2ban-client status traefik-auth
```

Adjust thresholds by editing the jail file and reloading the container (`docker compose restart fail2ban`).

## Running on the host (optional)

If you prefer a host-level install, reuse the same filter and `jail.local`:

1. Install fail2ban (`sudo apt install fail2ban` on Debian/Ubuntu).
2. Copy the files into `/etc/fail2ban/{filter.d,jail.d}` and restart the service.

Remember to set `logpath` inside `jail.local` so it matches your Traefik log location (for example, `${DOCKERDIR}/logs/cloudserver/traefik/access.log`). On nftables-based systems switch the action to `nftables-allports`.
