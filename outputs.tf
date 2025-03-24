output "static_website_url" {
  value       = azurerm_storage_account.storage_account.primary_web_endpoint
  description = "URL for the static website hosted in the storage account"
}

output "resource_group_name" {
  value       = azurerm_resource_group.rg.name
  description = "Name of the resource group"
}

output "load_balancer_ip" {
  value       = azurerm_public_ip.load_balancer_ip.ip_address
  description = "Public IP address of the load balancer"
}

output "sql_server_fqdn" {
  value       = azurerm_mssql_server.sql_server.fully_qualified_domain_name
  description = "The fully qualified domain name of the SQL server"
}

output "vmss_name" {
  value       = azurerm_linux_virtual_machine_scale_set.web_vmss.name
  description = "The name of the Virtual Machine Scale Set"
}

output "storage_account_name" {
  value       = azurerm_storage_account.storage_account.name
  description = "The name of the Storage Account"
}

output "virtual_network_name" {
  value       = azurerm_virtual_network.vnet.name
  description = "The name of the Virtual Network"
}

output "bastion_host_name" {
  value       = azurerm_bastion_host.bastion.name
  description = "The name of the Bastion Host"
}