variable "zone_name" {
  description = "Cloudflare zone name (root domain), e.g., example.com"
  type        = string
}

variable "origin_ipv4" {
  description = "Public IPv4 of your host to point A records at"
  type        = string
}

variable "origin_ipv6" {
  description = "Optional public IPv6 of your host to point AAAA records at"
  type        = string
  default     = null
}

variable "proxied" {
  description = "Whether Cloudflare should proxy the records"
  type        = bool
  default     = true
}

variable "ttl" {
  description = "DNS TTL in seconds; use 1 for 'auto'"
  type        = number
  default     = 1
}

variable "additional_records" {
  description = "Optional additional records to create as a list of objects"
  type = list(object({
    name    = string
    type    = string
    content = string
    proxied = optional(bool)
    ttl     = optional(number)
  }))
  default = []
}

variable "create_ipv6" {
  description = "Create AAAA records for service subdomains when origin_ipv6 is set"
  type        = bool
  default     = false
}

# Optional: use Cloudflare Tunnel instead of exposing your origin IP.
# When enabled, A/AAAA records are skipped and CNAMEs are created to the tunnel hostname
# (e.g., <UUID>.cfargotunnel.com) for each service subdomain.
variable "use_tunnel" {
  description = "Create CNAME records to a Cloudflare Tunnel target instead of A/AAAA"
  type        = bool
  default     = true
}

variable "tunnel_cname_target" {
  description = "Cloudflare Tunnel target hostname (e.g., 12345678-aaaa-bbbb-cccc-1234567890ab.cfargotunnel.com)"
  type        = string
  default     = null
}

variable "manage_tunnel" {
  description = "Create and manage a Cloudflare Tunnel via Terraform"
  type        = bool
  default     = true
}

variable "tunnel_name" {
  description = "Name for the Cloudflare Tunnel"
  type        = string
  default     = "media-stack"
}

variable "tunnel_origin_service" {
  description = "Origin service URL Cloudflared should route to (e.g., https://traefik:443)"
  type        = string
  default     = "https://traefik:443"
}

variable "tunnel_origin_server_name" {
  description = "Value for originRequest.originServerName (SNI) when connecting to the origin"
  type        = string
  default     = null
}

variable "tunnel_origin_http_host_header" {
  description = "Optional Host header to send to the origin (originRequest.httpHostHeader)"
  type        = string
  default     = null
}

variable "tunnel_disable_origin_tls_verify" {
  description = "Disable TLS verification when Cloudflared connects to the origin"
  type        = bool
  default     = false
}

# No static secret required for remotely-managed tunnels (token is retrieved via data source)

variable "zone_id" {
  description = "Cloudflare Zone ID to attach DNS records to (e.g., 023e105f4ecef8ad9ca31a8372d0c353)"
  type        = string
}

variable "cloudflare_account_id" {
  description = "Optional Cloudflare account ID to disambiguate zone lookup"
  type        = string
  default     = null
}

# Cloudflare authentication (prefer API Token). Set one of:
variable "cloudflare_api_token" {
  description = "Cloudflare API Token with Zone:Zone:Read and Zone:DNS:Edit"
  type        = string
  default     = null
  sensitive   = true
}

variable "cloudflare_api_key" {
  description = "Cloudflare Global API Key (not recommended)"
  type        = string
  default     = null
  sensitive   = true
}

variable "cloudflare_email" {
  description = "Cloudflare account email (used with Global API Key)"
  type        = string
  default     = null
}

# Firewall allowlist (Cloudflare WAF)
variable "enable_waf_allowlist" {
  description = "Enable a Cloudflare Firewall Rule to block all traffic except from the allowlist IPs"
  type        = bool
  default     = false
}

variable "waf_allowlist_ips" {
  description = "List of client IPv4/IPv6 addresses that should be allowed (all others are blocked)"
  type        = list(string)
  default     = []
}

variable "waf_target_hosts" {
  description = "Optional list of hostnames to scope the allowlist to; defaults to all managed service hostnames"
  type        = list(string)
  default     = []
}

# Cloudflare Access (Zero Trust) to protect apps
variable "enable_access" {
  description = "Enable Cloudflare Access Applications and default allow policy"
  type        = bool
  default     = false
}

variable "access_app_hostnames" {
  description = "List of hostnames to protect with Access; defaults to all managed service hostnames"
  type        = list(string)
  default     = []
}

variable "access_session_duration" {
  description = "Access session duration (e.g., 24h)"
  type        = string
  default     = "24h"
}

variable "access_auto_redirect_to_identity" {
  description = "Whether to auto-redirect to IdP login when hitting the app"
  type        = bool
  default     = false
}

variable "access_allow_authenticate_via_warp" {
  description = "Allow users to authenticate via WARP client"
  type        = bool
  default     = false
}

variable "access_email_addresses" {
  description = "Allow list of specific email addresses for Access policy"
  type        = list(string)
  default     = []
}

variable "access_email_domains" {
  description = "Allow list of email domains for Access policy (e.g., example.com)"
  type        = list(string)
  default     = []
}

variable "access_allow_ips" {
  description = "Allow list of client IPs/CIDRs for Access policy"
  type        = list(string)
  default     = []
}

variable "enable_warp_routing" {
  description = "Enable Cloudflare Tunnel WARP routing so Zero Trust clients can reach your private networks without port forwarding"
  type        = bool
  default     = false
}

variable "warp_routes" {
  description = "CIDR blocks to advertise over WARP when warp routing is enabled (e.g., [\"192.168.1.0/24\"])"
  type        = list(string)
  default     = []
}

variable "warp_virtual_network_name" {
  description = "Friendly name for the virtual network that groups the WARP routes"
  type        = string
  default     = "media-stack-lan"
}

variable "warp_virtual_network_comment" {
  description = "Optional comment shown in the Cloudflare dashboard for the virtual network"
  type        = string
  default     = "Home media stack private network"
}
