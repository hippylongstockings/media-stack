# Cloudflare DNS with Terraform

This Terraform config manages DNS records for your domain in Cloudflare for all services exposed by Traefik.

## Prerequisites

- Terraform >= 1.4
- Cloudflare account with access to the target zone
- API Token with least privilege (Zone:DNS:Edit, Zone:Zone:Read)

## Setup

1) Copy `terraform.tfvars.example` to `terraform.tfvars` and set values:
   - `zone_name` (e.g., hippylongstockings.com)
   - `origin_ipv4` (your public IP)
   - Optionally set `origin_ipv6` and `create_ipv6 = true`
2) Provide Cloudflare credentials (choose one):
   - API Token (recommended): set `cloudflare_api_token` in `terraform.tfvars`, or `export CLOUDFLARE_API_TOKEN=...`
   - Global API Key (not recommended): set `cloudflare_api_key` and `cloudflare_email` in `terraform.tfvars`, or `export CLOUDFLARE_API_KEY=...` and `export CLOUDFLARE_EMAIL=...`
3) Initialize/upgrade providers (uses Cloudflare provider v5+):
   - `terraform init -upgrade`
4) Review the plan:
   - `terraform plan`
5) Apply:
   - `terraform apply`

## Cloudflare Tunnel (no origin IP exposure)

By default, this project creates a Cloudflare Zero Trust tunnel and points all service hostnames (and apex) at it with CNAMEs. This avoids exposing your home IP.

Because of an upstream provider bug, the tunnel ingress routes are rendered to disk instead of using the `cloudflare_zero_trust_tunnel_cloudflared_config` resource. Whenever you run `terraform apply`, Terraform overwrites `cloudflared/config.yml` with the latest host -> Traefik mappings (and top-level `originRequest` settings). After the apply:

1. Ensure the tunnel credentials file (downloaded from Zero Trust once) lives at `cloudflared/<TUNNEL_ID>.json`.
2. `docker compose up -d cloudflared` so the container reloads the managed configuration.

If you need to disable origin TLS verification temporarily, set `tunnel_disable_origin_tls_verify = true` in `terraform.tfvars`. Flip it back to `false` once the Traefik certificate is trusted and re-run `terraform apply` to re-enable strict verification.

If you already have a tunnel and want to use it instead, set `manage_tunnel = false` and provide `tunnel_cname_target = "<UUID>.cfargotunnel.com"`. In that mode you’ll need to maintain the ingress routes manually.

### Private network access (Zero Trust WARP)

You can drop router port forwarding entirely and still reach services (or any LAN IP) through Cloudflare’s Zero Trust client:

1. In `terraform.tfvars`, set `enable_warp_routing = true` and list the private CIDRs you want reachable, e.g. `warp_routes = ["192.168.0.0/16"]`. Optionally adjust `warp_virtual_network_name/comment`.
2. `terraform apply` – Terraform enables WARP routing in the tunnel config and creates Cloudflare routes for those networks.
3. Install the Cloudflare WARP client on your devices and enroll them in your Zero Trust org.
4. (Optional) Create a “Private Network” application in the Zero Trust dashboard if you want additional Access policies.
5. If you are using Cloudflare Access on the HTTP apps, set `access_allow_authenticate_via_warp = true` **after** you configure a Warp auth session duration under Zero Trust → Settings → Authentication → Sessions; Cloudflare rejects the setting otherwise.

With WARP routing enabled, any enrolled device (including those on your home network) can hit the tunnel without exposing ports publicly.

## Records Managed

- Apex `@` and `www`
- `traefik`, `transmission`, `sonarr`, `radarr`, `prowlarr`, `ombi`, `portainer`
- Optional `additional_records` list for any extras

All service records default to proxied with `ttl = 1` (auto). Adjust via variables. When `use_tunnel = true`, CNAMEs are created to the tunnel instead of A/AAAA records.

## Firewall Allowlist (Block All Except Specific IPs)

This project uses a Cloudflare Zone Lockdown rule to allow only specific client IPs to reach selected hostnames (others are blocked at the edge).

1) In `terraform.tfvars`, set:
   - `enable_waf_allowlist = true`
   - `waf_allowlist_ips = ["203.0.113.10"]` (replace with your IPs/CIDRs)
   - Optionally `waf_target_hosts = ["traefik.example.com", ...]` to scope the rule. By default it applies to all managed hostnames.
2) `terraform apply`

Notes:
- Works with Cloudflare Tunnel and proxied DNS since it enforces at Cloudflare’s edge.
- Add a temporary second IP while testing to avoid locking yourself out.
- For identity-aware access, prefer Cloudflare Access policies.

## Adopting Existing Records

If records already exist in Cloudflare, you can import them so Terraform adopts instead of replacing:

- Find your Zone ID in the Cloudflare dashboard or via:
  - `terraform console` -> `data.cloudflare_zone.this.id` after setting `zone_name`
- For each existing record (e.g., `traefik.example.com`) find the Record ID in the dashboard (DNS -> record -> API details), then:
  - `terraform import 'cloudflare_dns_record.svc_a["traefik"]' <ZONE_ID>/<RECORD_ID>`
  - For apex: `terraform import 'cloudflare_dns_record.svc_a["@"]' <ZONE_ID>/<RECORD_ID>`
  - For AAAA (if exists): `terraform import 'cloudflare_dns_record.svc_aaaa["traefik"]' <ZONE_ID>/<RECORD_ID>`

After imports, run `terraform plan` to verify the state matches desired settings.

## Notes

- Use API Tokens, not Global Keys, where possible.
- Traefik and the other services rely on these subdomains being resolvable to your host.
- If your public IP changes frequently, consider setting `origin_ipv4` to a dynamic DNS CNAME chain instead of an A record by using `additional_records` and specifying `type = "CNAME"`.

## Cloudflare Access (Zero Trust)

Protect subdomains with Cloudflare Access so only authenticated identities (or specific IPs) can reach Traefik and the other apps.

1) Ensure `cloudflare_account_id` is set in `terraform.tfvars` (required for Access resources).
2) In the same file, set:
   - `enable_access = true`
   - Optional `access_app_hostnames = ["traefik.example.com"]` (defaults to all managed hostnames)
   - One or more allow conditions:
     - `access_email_addresses = ["you@example.com"]`
     - `access_email_domains = ["example.com"]`
     - `access_allow_ips = ["203.0.113.10"]`
   - Adjust `access_session_duration`, `access_auto_redirect_to_identity`, or `access_allow_authenticate_via_warp` as needed.
3) `terraform apply`.

Make sure the DNS records for these hostnames are proxied (orange cloud) so Cloudflare Access intercepts requests.
