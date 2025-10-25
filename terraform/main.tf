provider "cloudflare" {
  api_token = var.cloudflare_api_token
  api_key   = var.cloudflare_api_key
  email     = var.cloudflare_email
}

data "cloudflare_zones" "this" {
  account = {
    name       = var.zone_name
    
  }
}



# Core subdomains used by the stack
locals {
  svc_names = [
    "@",          # apex for Heimdall
    "www",        # Heimdall www
    "traefik",    # Traefik dashboard
    "transmission",
    "sonarr",
    "radarr",
    "prowlarr",
    "ombi",
    "portainer",
  ]

  # Build a map for for_each from names
  svc_map = { for n in local.svc_names : n => n }

  svc_hostnames = {
    for n in local.svc_names :
    n => (n == "@" ? var.zone_name : "${n}.${var.zone_name}")
  }

  tunnel_origin_request_base = merge(
    var.tunnel_origin_http_host_header != null ? { httpHostHeader = var.tunnel_origin_http_host_header } : {},
    var.tunnel_disable_origin_tls_verify ? { noTLSVerify = true } : {}
  )

  tunnel_config_path = "${path.module}/../cloudflared/config.yml"

  tunnel_ingress = concat(
    [
      for hostname in values(local.svc_hostnames) : {
        hostname = hostname
        service  = var.tunnel_origin_service
        originRequest = merge(
          local.tunnel_origin_request_base,
          { originServerName = coalesce(var.tunnel_origin_server_name, hostname) }
        )
      }
    ],
    [
      { service = "http_status:404" }
    ]
  )

  tunnel_remote_origin_request_base = merge(
    var.tunnel_origin_http_host_header != null ? { http_host_header = var.tunnel_origin_http_host_header } : {},
    var.tunnel_disable_origin_tls_verify ? { no_tls_verify = true } : {}
  )

  tunnel_remote_ingress = concat(
    [
      for hostname in values(local.svc_hostnames) : {
        hostname       = hostname
        service        = var.tunnel_origin_service
        origin_request = merge(
          local.tunnel_remote_origin_request_base,
          { origin_server_name = coalesce(var.tunnel_origin_server_name, hostname) }
        )
      }
    ],
    [
      { service = "http_status:404" }
    ]
  )

  tunnel_config_map = merge(
    {
      tunnel            = cloudflare_zero_trust_tunnel_cloudflared.tunnel[0].id
      "credentials-file" = "/etc/cloudflared/${cloudflare_zero_trust_tunnel_cloudflared.tunnel[0].id}.json"
      "no-autoupdate"   = true
      loglevel          = "info"
      ingress           = local.tunnel_ingress
    },
    (local.tunnel_origin_request_base != {} || var.tunnel_origin_server_name != null)
      ? { originRequest = merge(local.tunnel_origin_request_base, var.tunnel_origin_server_name != null ? { originServerName = var.tunnel_origin_server_name } : {}) }
      : {}
  )

  tunnel_remote_config_map = merge(
    {
      ingress = local.tunnel_remote_ingress
      warp_routing = {
        enabled = local.warp_routing_enabled
      }
    },
    (local.tunnel_remote_origin_request_base != {} || var.tunnel_origin_server_name != null)
      ? { origin_request = merge(local.tunnel_remote_origin_request_base, var.tunnel_origin_server_name != null ? { origin_server_name = var.tunnel_origin_server_name } : {}) }
      : {}
  )

  # Resolve which hostnames to apply the firewall allowlist to
  waf_hosts = length(var.waf_target_hosts) > 0 ? var.waf_target_hosts : values(local.svc_hostnames)

  # Access app hostnames (default to all managed service hostnames)
  access_hosts     = length(var.access_app_hostnames) > 0 ? var.access_app_hostnames : values(local.svc_hostnames)
  access_hosts_map = { for h in local.access_hosts : h => h }

  # Normalize IPs to CIDR for Access allow IPs
  access_allow_ips_cidrs = [for ip in var.access_allow_ips : strcontains(ip, "/") ? ip : format("%s/32", ip)]
  access_include = concat(
    [for email in var.access_email_addresses : { email = { email = email } }],
    [for domain in var.access_email_domains : { email_domain = { domain = domain } }],
    [for ip in local.access_allow_ips_cidrs : { ip = { ip = ip } }]
  )
  access_policy_include = length(local.access_include) > 0 ? local.access_include : [{ everyone = {} }]
  warp_routes_map       = var.enable_warp_routing ? { for cidr in var.warp_routes : cidr => cidr } : {}
  warp_routing_enabled  = var.enable_warp_routing && length(var.warp_routes) > 0
}

# Optional Cloudflare Tunnel (Zero Trust) to avoid exposing origin IP
resource "cloudflare_zero_trust_tunnel_cloudflared" "tunnel" {
  count       = var.manage_tunnel ? 1 : 0
  account_id  = var.cloudflare_account_id
  name        = var.tunnel_name
  config_src  = "cloudflare"
}

data "cloudflare_zero_trust_tunnel_cloudflared_token" "tunnel_token" {
  count      = var.manage_tunnel ? 1 : 0
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.tunnel[0].id
}

resource "cloudflare_zero_trust_tunnel_cloudflared_virtual_network" "warp_vnet" {
  count      = local.warp_routing_enabled && var.manage_tunnel ? 1 : 0
  account_id = var.cloudflare_account_id
  name       = var.warp_virtual_network_name
  comment    = var.warp_virtual_network_comment
  lifecycle {
    precondition {
      condition     = var.cloudflare_account_id != null
      error_message = "cloudflare_account_id must be set when enable_warp_routing is true."
    }
  }
}

resource "cloudflare_zero_trust_tunnel_cloudflared_route" "warp" {
  for_each = local.warp_routing_enabled && var.manage_tunnel ? local.warp_routes_map : {}

  account_id         = var.cloudflare_account_id
  tunnel_id          = cloudflare_zero_trust_tunnel_cloudflared.tunnel[0].id
  network            = each.value
  virtual_network_id = cloudflare_zero_trust_tunnel_cloudflared_virtual_network.warp_vnet[0].id
  lifecycle {
    precondition {
      condition     = var.cloudflare_account_id != null
      error_message = "cloudflare_account_id must be set when enable_warp_routing is true."
    }
  }
}

## Note: cloudflare_zero_trust_tunnel_cloudflared_config is read-only in provider v5; we render config to disk instead.

resource "local_file" "tunnel_config" {
  count = var.manage_tunnel ? 1 : 0

  filename = local.tunnel_config_path
  content  = <<-EOF
    # Managed by Terraform
    ${yamlencode(local.tunnel_config_map)}
    EOF
}

resource "cloudflare_dns_record" "svc_a" {
  for_each = var.use_tunnel ? {} : local.svc_map

  zone_id = var.zone_id
  name    = each.value
  type    = "A"
  content = var.origin_ipv4
  proxied = var.proxied
  ttl     = var.ttl
}

resource "cloudflare_dns_record" "svc_aaaa" {
  for_each = var.use_tunnel ? {} : (var.create_ipv6 && var.origin_ipv6 != null ? local.svc_map : {})

  zone_id = var.zone_id
  name    = each.value
  type    = "AAAA"
  content = var.origin_ipv6
  proxied = var.proxied
  ttl     = var.ttl
}

# Optional additional records
resource "cloudflare_dns_record" "extra" {
  for_each = { for r in var.additional_records : format("%s-%s", r.name, r.type) => r }

  zone_id = var.zone_id
  name    = each.value.name
  type    = each.value.type
  content = each.value.content
  proxied = coalesce(try(each.value.proxied, null), var.proxied)
  ttl     = coalesce(try(each.value.ttl, null), var.ttl)
}

# Optional CNAMEs to Cloudflare Tunnel target (when use_tunnel = true)
resource "cloudflare_dns_record" "svc_cname" {
  for_each = var.use_tunnel ? local.svc_map : {}

  zone_id = var.zone_id
  name    = each.value
  type    = "CNAME"
  content = var.manage_tunnel ? "${cloudflare_zero_trust_tunnel_cloudflared.tunnel[0].id}.cfargotunnel.com" : var.tunnel_cname_target
  proxied = var.proxied
  ttl     = var.ttl
}

# Cloudflare Access Applications and default allow policies
resource "cloudflare_zero_trust_access_policy" "default_allow" {
  for_each          = var.enable_access ? local.access_hosts_map : {}
  account_id        = var.cloudflare_account_id
  name              = "Allow identities/IPs - ${each.value}"
  decision          = "allow"
  include           = local.access_policy_include
  session_duration  = var.access_session_duration
}

resource "cloudflare_zero_trust_access_application" "app" {
  for_each                   = var.enable_access ? local.access_hosts_map : {}
  account_id                 = var.cloudflare_account_id
  name                       = "Access - ${each.value}"
  domain                     = each.value
  type                       = "self_hosted"
  session_duration           = var.access_session_duration
  auto_redirect_to_identity  = var.access_auto_redirect_to_identity
  allow_authenticate_via_warp = var.access_allow_authenticate_via_warp
  policies = [
    {
      id         = cloudflare_zero_trust_access_policy.default_allow[each.key].id
      precedence = 1
    }
  ]
}
