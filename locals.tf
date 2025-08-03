locals {
  environment = "private-aks-test"
  location    = "westus2"

  vnet_cidrs  = ["10.180.0.0/16"]
  aks_subnet_cidrs = ["10.180.0.0/18"]
  gateway_subnet_cidrs = ["10.180.200.0/27"]
  inbound_dns_resolver_subnet_cidrs = ["10.180.200.32/27"]
  vpn_client_address_space = ["10.183.0.0/21"]

  kubernetes_version = "1.32.3"

  tags = {
    Environment = local.environment
  }

  vpn_root_certificate = "your-root-certificate-content"
}