resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-${var.resource_group_name}"
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "vnet" {
  name                = "${var.prefix}-${var.vnet_name}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = ["10.0.0.0/22"]
  tags                = var.tags

  depends_on = [azurerm_resource_group.rg]
}

resource "azurerm_subnet" "web_subnet" {
  name                 = "${var.prefix}-${var.web_subnet_name}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
  service_endpoints    = ["Microsoft.Sql", "Microsoft.Storage"]

  depends_on = [azurerm_resource_group.rg]
}

resource "azurerm_subnet" "db_subnet" {
  name                 = "${var.prefix}-${var.db_subnet_name}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
  service_endpoints    = ["Microsoft.Sql"]

  depends_on = [azurerm_virtual_network.vnet]
}

resource "azurerm_network_security_group" "web_nsg" {
  name                = "${var.prefix}-web-nsg"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags

  security_rule {
    name                       = "allow-http"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-https"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-ssh"
    priority                   = 102
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.admin_cidr_block
    destination_address_prefix = "*"
  }

  depends_on = [azurerm_resource_group.rg]
}

# Allow only necessary outbound traffic from web tier
resource "azurerm_network_security_rule" "web_outbound" {
  name                        = "allow-outbound"
  priority                    = 103
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["80", "443", "1433"]  # HTTP, HTTPS, SQL
  source_address_prefix       = azurerm_subnet.web_subnet.address_prefixes[0]
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.web_nsg.name

  depends_on = [azurerm_network_security_group.web_nsg]
}

resource "azurerm_subnet_network_security_group_association" "web_nsg_association" {
  subnet_id                 = azurerm_subnet.web_subnet.id
  network_security_group_id = azurerm_network_security_group.web_nsg.id

  depends_on = [
    azurerm_subnet.web_subnet,
    azurerm_network_security_group.web_nsg
  ]
}

resource "azurerm_network_security_group" "db_nsg" {
  name                = "${var.prefix}-db-nsg"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags

  security_rule {
    name                       = "allow-sql"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "1433"
    source_address_prefix      = azurerm_subnet.web_subnet.address_prefixes[0]
    destination_address_prefix = "*"
  }

  depends_on = [
    azurerm_resource_group.rg,
    azurerm_subnet.web_subnet
  ]
}

resource "azurerm_subnet_network_security_group_association" "db_nsg_association" {
  subnet_id                 = azurerm_subnet.db_subnet.id
  network_security_group_id = azurerm_network_security_group.db_nsg.id

  depends_on = [
    azurerm_subnet.db_subnet,
    azurerm_network_security_group.db_nsg
  ]
}