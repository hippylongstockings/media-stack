# Self-Hosted Media Stack

This repository contains a full media automation stack fronted by Traefik and protected with Cloudflare Zero Trust. It covers discovery (Prowlarr), automation (Sonarr/Radarr/Lidarr), downloading (Transmission behind a dedicated WireGuard VPN), media requests (Ombi), and optional extras such as ytdl-material and Recyclarr policy sync.

| Layer | Components |
| ----- | ---------- |
| Reverse proxy & auth | Traefik 2, Cloudflare Tunnel, Cloudflare Access / Firewall rules |
| Networking & VPN | WireGuard (PIA) container that owns Transmission’s network namespace |
| Media automation | Sonarr, Radarr, Lidarr, Prowlarr, Recyclarr |
| Download client | Transmission (watch → incomplete → complete flow) |
| Utilities | Heimdall, Ombi, Portainer, Watchtower, Flaresolverr, ytdl-material |
| ChatOps | Telegram bot with stack status commands |
| Infrastructure-as-code | Terraform for Cloudflare DNS/Tunnel/Access rules |

The whole stack is described in `docker-compose.yml` and configured via `.env`.

---

## Prerequisites

1. **Host OS**: Linux (native) or Windows with WSL2. Install Docker Engine + Docker Compose v2.
2. **Domain**: A Cloudflare-managed domain and an API token with `Zone:Zone:Read` + `Zone:DNS:Edit`. (Global API keys work, but tokens are strongly preferred.)
3. **Access**: Cloudflare Zero Trust account (for Access rules/Tunnel).
4. **VPN**: Private Internet Access (PIA) account that supports WireGuard and port forwarding.
5. **Media storage**: A mount (e.g., `/opt/media`) with subfolders for Movies, TV, Music, Downloads.
6. **Optional**:
   - Telegram bot token/chat ID for Watchtower alerts.
   - CAPTCHA solver key if you plan to extend Flaresolverr.

---

## Repository Layout

```
.
├── docker-compose.yml           # All services
├── .env                         # Environment/secret values (git-ignored)
├── .env.example                 # Template of required variables
├── appdata/                     # Container configs (ignored)
├── cloudflared/                 # Cloudflare tunnel credentials/config
├── recyclarr/                   # YAML config for Radarr/Sonarr/Lidarr policies
├── terraform/                   # Cloudflare DNS/Tunnel/Firewall/Access IaC
└── ops/fail2ban/                # Traefik auth jail/filter examples
```

---

## Configuration Workflow

### 1. Clone & bootstrap

```bash
git clone <repo> ~/docker
cd ~/docker
cp .env.example .env
```

Edit `.env` to match your environment:

- Host paths: `USERDIR`, `DOCKERDIR`, `DATADIR`, `EXTDRIVE`.
- Networking: `T2_PROXY_SUBNET`, static IPs (`SONARR_IP`, `RADARR_IP`, `LIDARR_IP`, `PROWLARR_IP`), `LOCAL_NETWORK`.
- Secrets: Cloudflare credentials, PIA credentials.
- API keys: Sonarr, Radarr, Lidarr (populate after first launch).

Create the persistent directories (sudo if needed). Replace `/opt/media` with your chosen `DATADIR`:

```bash
MEDIA_ROOT=/opt/media
sudo mkdir -p \
  appdata/{traefik2,fail2ban,sonarr,radarr,lidarr,prowlarr,transmission,portainer,heimdall,ombi,youtubedl-material} \
  recyclarr \
  ${MEDIA_ROOT}/{Movies,TV-Shows,Music,Downloads,downloads/{complete,incomplete,watch,youtubedl-material/audio}}
sudo chown -R $USER:$USER appdata recyclarr
```

### 2. Terraform (Cloudflare)

1. Populate `terraform/terraform.tfvars` with your zone details, account ID, and desired policies (Access allowlists, Zone Lockdown IPs, Tunnel settings).
2. Run:
   ```bash
   cd terraform
   terraform init -upgrade
   terraform plan
   terraform apply
   ```
3. Download the Cloudflare Tunnel credentials JSON once and place it in `cloudflared/<TUNNEL_ID>.json`.

Terraform outputs:
- DNS records (either A/AAAA or CNAME to tunnel).
- Optional Zero Trust Access policies requiring specific emails/IPs.
- Zone Lockdown firewall rule allowing only your IP(s).
- Managed `cloudflared/config.yml` used by the container.
- To drop router port forwarding, enable Zero Trust WARP routing in `terraform.tfvars` (`enable_warp_routing = true`, set `warp_routes` to your LAN CIDR) and re-run `terraform apply`. Devices enrolled in Cloudflare WARP can then reach the stack through the tunnel instead of direct WAN ingress. When you later enable WARP-backed Access auth, remember to set a Warp auth session duration in the Zero Trust dashboard before toggling `access_allow_authenticate_via_warp`.

### 3. Start the stack

Back in the repo root:

```bash
docker compose up -d
```

Watch for errors:

```bash
docker compose logs -f traefik vpn transmission
```

Ensure certificates issue successfully and core services respond behind Traefik.

### 4. Post-deploy tasks

1. **Prowlarr**: Under *Settings → Apps* add Radarr, Sonarr, and Lidarr using their internal URLs (`http://radarr:7878`, etc.) and API keys. Sync categories.
2. **Download client**: In each Arr application, add Transmission manually:
   - Host: `vpn`
   - Port: `9091`
   - Completed folder: `/downloads/complete`
   - Use hardlinks instead of copy.
   Enable `Remove Completed Downloads` if you want Sonarr/Radarr to clear Transmission once import is done.
3. **Lidarr**: Add root folder `$DATADIR/Music`.
4. **youtubedl-material**: Visit `https://ytdl.<domain>` and adjust defaults. Point audio output to `/app/audio` (mapped to `$DATADIR/downloads/youtubedl-material/audio`) or directly to `$DATADIR/Music/Incoming`.
5. **Recyclarr**: After setting API keys in `.env`, run:
   ```bash
   docker compose run --rm recyclarr
   ```
   This syncs quality/size profiles for all Arr apps.
6. **Flaresolverr**: In Prowlarr, configure a proxy (Settings → Indexers → Proxies) pointing to `http://flaresolverr:8191` and assign it to problematic indexers.
7. **Fail2ban**: Bring the container online and verify bans are tracking Traefik’s log:
   ```bash
   docker compose up -d fail2ban
   docker compose logs -f fail2ban
   ```
   Adjust ban timings or log paths via the mounted files in `ops/fail2ban/traefik/` if needed.
8. **Telegram bot** (optional): Populate `TGRAM_BOT_TOKEN` / `TGRAM_CHAT_ID` in `.env`, then run `docker compose up -d telegram-bot`. Message the bot (`/start`) to confirm connectivity. `/services`, `/transmission`, `/radarr`, `/sonarr`, `/disk`, `/tunnel` provide quick health checks.

---

## Running & Maintenance

| Task | Command |
| ---- | ------- |
| Check status | `docker compose ps` |
| Tail logs | `docker compose logs -f <service>` |
| Inspect fail2ban bans | `docker compose exec fail2ban fail2ban-client status traefik-auth` |
| Update containers | `docker compose pull && docker compose up -d` |
| Re-run Recyclarr after YAML edits | `docker compose run --rm recyclarr` |
| Reapply Cloudflare config | `cd terraform && terraform apply` |
| Backup configs | archive `appdata/`, `cloudflared/`, and `.env` |

**Directories to retain outside git** (git-ignored):
- `appdata/…` – application databases/config.
- `cloudflared/*.json` – tunnel credentials.
- `downloads/` – active torrents / YouTube grabs.
- `logs/` – runtime logs.

Rotate secrets periodically (PIA credentials, Cloudflare API token) and update `.env`.

---

## Service Reference

- **Traefik** (ports 80/443, host network) + middlewares `chain-no-auth`, `chain-basic-auth`, rate limiting, security headers.
- **Cloudflared** – Zero Trust tunnel for remote access; Terraform-managed config.
- **Cloudflare Access** (Terraform) – Optionally restrict hostnames to specific emails/IPs.
- **Flaresolverr** – Solves Cloudflare challenges for indexers.
- **WireGuard VPN (PIA)** – Provides network namespace for Transmission.
- **Transmission** – Downloads into `/downloads` with watch/incomplete/complete flow (`watch` at `/downloads/watch`).
- **Sonarr / Radarr / Lidarr** – Manage TV, Movies, Music respectively.
- **Prowlarr** – Central indexer manager; syncs indexers to the Arr apps.
- **Recyclarr** – Applies YAML-defined quality and size limits to Arr apps.
- **youtubedl-material** – Easily pull audio/video (e.g., YouTube) into `/downloads/youtubedl-material`.
- **Ombi** – End-user request portal.
- **Heimdall** – Landing/dashboard.
- **Portainer** – Docker UI (secured via Traefik/Cloudflare Access).
- **Watchtower** – Automatic container updates (uses Docker Socket Proxy).
- **Socket Proxy** – Limits docker.sock exposure to Traefik/Watchtower.
- **Fail2ban** – Watches Traefik access logs and bans repeated 401/403 offenders via host firewall.
- **Telegram bot** – Responds to `/help`, `/ping`, `/services`, `/transmission`, `/radarr`, `/sonarr`, `/disk`, `/tunnel`; alerts on low disk space and Arr download/import failures.

---

## Suggested Next Steps

- **Secrets**: Replace placeholder credentials/API tokens and remove hard-coded secrets from `.env`.
- **Monitoring**: Ship logs (Traefik, Transmission, Arr apps) to a centralized stack (ELK, Grafana Loki, etc.).
- **Backups**: Schedule automatic backups of `appdata/*`, especially Sonarr/Radarr/Lidarr/Prowlarr databases and Traefik `acme.json`.
- **Media storage**: Add off-site or snapshot-based backups for `$DATADIR`.
- **CI**: Add lint checks for Compose (`docker compose config`), Terraform (`terraform fmt`), and static security scans.
- **Additional automation**: Extend Recyclarr with TRaSH custom formats or integrate Jellyseerr/Overseerr if you prefer.
- **Security hardening**: Complete the migration to Cloudflare API tokens everywhere; enable strict TLS verification (`tunnel_disable_origin_tls_verify = false` once Traefik certs are trusted).

---

## Git Hygiene

The repo already contains `.gitignore` rules for sensitive/generated content (`.env`, `appdata/**`, download directories, logs, tunnel credentials). Before pushing to GitHub:

1. Ensure `.env` contains no secrets you don’t intend to publish.
2. Commit only the compose/terraform/recyclarr configs and documentation.
3. Consider adding encrypted backups (e.g., restic) rather than raw data files.

---

Happy automating! If you add new services or tweak policies, remember to keep Terraform, Recyclarr, and your `.env` in sync so everything remains reproducible.
