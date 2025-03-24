resource "random_string" "storage_suffix" {
  length  = 8
  special = false
  upper   = false
  numeric = true
}

resource "azurerm_storage_account" "storage_account" {
    name                     = lower(substr("${var.prefix}${var.storage_account_name}${random_string.storage_suffix.result}", 0, 24))
    resource_group_name      = azurerm_resource_group.rg.name
    location                 = azurerm_resource_group.rg.location
    account_tier             = "Standard"
    account_replication_type = "LRS"
    tags                     = var.tags

    depends_on = [
        azurerm_resource_group.rg,
        azurerm_subnet.web_subnet
    ]
}

resource "azurerm_storage_account_network_rules" "str_rules" {
  storage_account_id = azurerm_storage_account.storage_account.id
  default_action     = "Deny"
  virtual_network_subnet_ids = [azurerm_subnet.web_subnet.id]
  bypass             = ["AzureServices"]
  ip_rules           = [split("/", var.admin_cidr_block)[0]]
  
  depends_on = [
    azurerm_storage_account.storage_account
  ]
}

# Enable static website hosting on the storage account
resource "azurerm_storage_account_static_website" "static_website" {
  storage_account_id = azurerm_storage_account.storage_account.id
  index_document       = "index.html"
  error_404_document   = "404.html"
}

resource "azurerm_storage_container" "static_content" {
  name                  = "${var.prefix}-static-content"
  storage_account_id    = azurerm_storage_account.storage_account.id
  container_access_type = "blob"
  
  depends_on = [azurerm_storage_account.storage_account]
}
