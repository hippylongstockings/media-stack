output "zone_id" {
  value       = var.zone_id
  description = "Cloudflare Zone ID"
}

output "tunnel_id" {
  value       = try(cloudflare_zero_trust_tunnel_cloudflared.tunnel[0].id, null)
  description = "ID of the managed Cloudflare Tunnel (if enabled)"
}

output "tunnel_token" {
  value       = try(data.cloudflare_zero_trust_tunnel_cloudflared_token.tunnel_token[0].token, null)
  description = "Connector token for the managed Cloudflare Tunnel"
  sensitive   = true
}
