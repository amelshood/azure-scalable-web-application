resource "azurerm_mssql_server" "sql_server" {
    name                         = "${var.prefix}-${var.sql_server_name}-${random_string.storage_suffix.result}"
    resource_group_name          = azurerm_resource_group.rg.name
    location                     = azurerm_resource_group.rg.location
    version                      = "12.0"
    administrator_login          = var.admin_username
    administrator_login_password = var.admin_password
    minimum_tls_version          = "1.2"
    tags                         = var.tags

    depends_on = [
      azurerm_resource_group.rg,
      random_string.storage_suffix
    ]
}

resource "azurerm_mssql_database" "sql_database" {
    name           = "${var.prefix}-${var.sql_database_name}"
    server_id      = azurerm_mssql_server.sql_server.id
    sku_name       = "Basic"
    collation      = "SQL_Latin1_General_CP1_CI_AS"
    tags           = var.tags

    depends_on = [ azurerm_mssql_server.sql_server ]
}

resource "azurerm_mssql_virtual_network_rule" "main" {
    name      = "${var.prefix}-sql-vnet-rule"
    server_id = azurerm_mssql_server.sql_server.id
    subnet_id = azurerm_subnet.web_subnet.id

    depends_on = [
        azurerm_mssql_server.sql_server,
        azurerm_subnet.web_subnet
    ]
}

resource "azurerm_mssql_firewall_rule" "main" {
  name             = "${var.prefix}-AllowWebSubnet"
  server_id        = azurerm_mssql_server.sql_server.id
  start_ip_address = cidrhost(azurerm_subnet.web_subnet.address_prefixes[0], 0)
  end_ip_address   = cidrhost(azurerm_subnet.web_subnet.address_prefixes[0], 255)

  depends_on = [
    azurerm_mssql_server.sql_server,
    azurerm_subnet.web_subnet
  ]
}

# Admin access for management
resource "azurerm_mssql_firewall_rule" "admin" {
  name             = "${var.prefix}-AllowAdminAccess"
  server_id        = azurerm_mssql_server.sql_server.id
  start_ip_address = split("/", var.admin_cidr_block)[0]
  end_ip_address   = split("/", var.admin_cidr_block)[0]

  depends_on = [azurerm_mssql_server.sql_server]
}