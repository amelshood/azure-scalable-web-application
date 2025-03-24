resource "azurerm_public_ip" "load_balancer_ip" {
  name                = "${var.prefix}-load-balancer-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags

  depends_on = [azurerm_resource_group.rg]
}

resource "azurerm_lb" "load_balancer" {
  name                = "${var.prefix}-web-lb"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"
  tags                = var.tags
  
  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.load_balancer_ip.id
  }

  depends_on = [azurerm_public_ip.load_balancer_ip]
}

resource "azurerm_lb_backend_address_pool" "backend_address_pool" {
  loadbalancer_id = azurerm_lb.load_balancer.id
  name            = "${var.prefix}-BackEndAddressPool"

  depends_on = [azurerm_lb.load_balancer]
}

resource "azurerm_lb_probe" "http_probe" {
  loadbalancer_id = azurerm_lb.load_balancer.id
  name            = "${var.prefix}-http-probe"
  port            = 80
  protocol            = "Http"      
  request_path        = "/"             
  interval_in_seconds = 5              
  number_of_probes    = 2 

  depends_on = [azurerm_lb.load_balancer]
}

resource "azurerm_lb_rule" "http_rule" {
    loadbalancer_id                = azurerm_lb.load_balancer.id
    name                           = "${var.prefix}-http-rule"
    protocol                       = "Tcp"
    frontend_port                  = 80
    backend_port                   = 80
    frontend_ip_configuration_name = "PublicIPAddress"
    backend_address_pool_ids       = [azurerm_lb_backend_address_pool.backend_address_pool.id]
    probe_id                       = azurerm_lb_probe.http_probe.id

    depends_on = [
        azurerm_lb.load_balancer,
        azurerm_lb_backend_address_pool.backend_address_pool,
        azurerm_lb_probe.http_probe
    ]
}

resource "azurerm_linux_virtual_machine_scale_set" "web_vmss" {
    name                = "${var.prefix}-web-vmss"
    resource_group_name = azurerm_resource_group.rg.name
    location            = azurerm_resource_group.rg.location
    sku                 = "Standard_B1ms"
    instances           = 2
    admin_username      = "adminuser"
    tags                = var.tags

    admin_ssh_key {
    username   = "adminuser"
    public_key = file(var.ssh_public_key_path)
    }
    
    source_image_reference {
        publisher = "Canonical"
        offer     = "0001-com-ubuntu-server-jammy"
        sku       = "22_04-lts-gen2"
        version   = "latest"
        }

    os_disk {
        storage_account_type = "Standard_LRS"
        caching              = "ReadWrite"
        }

    network_interface {
        name    = "${var.prefix}-web-nic"
        primary = true
        ip_configuration {
            name      = "ipconfig"
            primary   = true
            subnet_id = azurerm_subnet.web_subnet.id
            load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.backend_address_pool.id]
            }
    }

    upgrade_mode = "Automatic"
    health_probe_id = azurerm_lb_probe.http_probe.id

    automatic_os_upgrade_policy {
    disable_automatic_rollback = false
    enable_automatic_os_upgrade = true
    }

    custom_data = base64encode(file("${path.module}/scripts/vm-init.sh"))

    depends_on = [
    azurerm_subnet.web_subnet,
    azurerm_lb_backend_address_pool.backend_address_pool,
    azurerm_lb_probe.http_probe
  ]
}

resource "azurerm_monitor_autoscale_setting" "web" {
  name                = "${var.prefix}-webapp-autoscale"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.web_vmss.id
  tags                = var.tags

  profile {
    name = "default"

    capacity {
      default = 2
      minimum = 2
      maximum = 10
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.web_vmss.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 75
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.web_vmss.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 25
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }
  }

  depends_on = [azurerm_linux_virtual_machine_scale_set.web_vmss]
}