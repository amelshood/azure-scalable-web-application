# Log Analytics Workspace for centralized logging
resource "azurerm_log_analytics_workspace" "web_log_analytics" {
  name                = "${var.prefix}-webapp-log-analytics"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
  
  depends_on = [azurerm_resource_group.rg]
}

# VM Insights solution for detailed VM monitoring
resource "azurerm_log_analytics_solution" "vm_insights" {
  solution_name         = "VMInsights"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  workspace_resource_id = azurerm_log_analytics_workspace.web_log_analytics.id
  workspace_name        = azurerm_log_analytics_workspace.web_log_analytics.name
  tags                  = var.tags

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/VMInsights"
  }
  
  depends_on = [azurerm_log_analytics_workspace.web_log_analytics]
}

# Azure Monitor Action Group for alert notifications
resource "azurerm_monitor_action_group" "main" {
  name                = "${var.prefix}-web-app-action-group"
  resource_group_name = azurerm_resource_group.rg.name
  short_name          = "webappag"
  tags                = var.tags

  email_receiver {
    name                    = "admin"
    email_address           = var.admin_email
    use_common_alert_schema = true
  }
  
  depends_on = [azurerm_resource_group.rg]
}

# CPU Alert for VM Scale Set
resource "azurerm_monitor_metric_alert" "cpu_alert" {
  name                = "${var.prefix}-vmss-high-cpu-alert"
  resource_group_name = azurerm_resource_group.rg.name
  scopes              = [azurerm_linux_virtual_machine_scale_set.web_vmss.id]
  description         = "Alert when CPU usage is high"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachineScaleSets"
    metric_name      = "Percentage CPU"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 85
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
  
  depends_on = [
    azurerm_linux_virtual_machine_scale_set.web_vmss,
    azurerm_monitor_action_group.main
  ]
}

# Low memory alert for VM Scale Set
resource "azurerm_monitor_metric_alert" "memory_alert" {
  name                = "${var.prefix}-vmss-low-memory-alert"
  resource_group_name = azurerm_resource_group.rg.name
  scopes              = [azurerm_linux_virtual_machine_scale_set.web_vmss.id]
  description         = "Alert when available memory is low"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachineScaleSets"
    metric_name      = "Available Memory Bytes"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 1073741824  # 1GB in bytes
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
  
  depends_on = [
    azurerm_linux_virtual_machine_scale_set.web_vmss,
    azurerm_monitor_action_group.main
  ]
}

# Azure Automation Account
resource "azurerm_automation_account" "web_automation" {
  name                = "${var.prefix}-webapp-automation"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "Basic"
  tags                = var.tags
  
  depends_on = [azurerm_resource_group.rg]
}

# Update Management Solution
resource "azurerm_log_analytics_solution" "update_management" {
  solution_name         = "Updates"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  workspace_resource_id = azurerm_log_analytics_workspace.web_log_analytics.id
  workspace_name        = azurerm_log_analytics_workspace.web_log_analytics.name
  tags                  = var.tags

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/Updates"
  }

  depends_on = [azurerm_log_analytics_workspace.web_log_analytics]
}

# Diagnostic settings for Load Balancer
resource "azurerm_monitor_diagnostic_setting" "lb_diagnostics" {
  name                       = "${var.prefix}-lb-diagnostics"
  target_resource_id         = azurerm_lb.load_balancer.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.web_log_analytics.id

  metric {
    category = "AllMetrics"
    enabled  = true
  }
  
  depends_on = [
    azurerm_lb.load_balancer,
    azurerm_log_analytics_workspace.web_log_analytics
  ]
}

# Diagnostic settings for SQL Database
resource "azurerm_monitor_diagnostic_setting" "sql_diagnostics" {
  name                       = "${var.prefix}-sql-diagnostics"
  target_resource_id         = azurerm_mssql_database.sql_database.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.web_log_analytics.id

  enabled_log {
    category = "SQLInsights"
  }

  enabled_log {
    category = "AutomaticTuning"
  }

  enabled_log {
    category = "QueryStoreRuntimeStatistics"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
  
  depends_on = [
    azurerm_mssql_database.sql_database,
    azurerm_log_analytics_workspace.web_log_analytics
  ]
}

resource "azurerm_portal_dashboard" "web_dashboard" {
  name                = "${var.prefix}-web-dashboard"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  tags                = var.tags
  dashboard_properties = <<DASHBOARD
{
  "lenses": {
    "0": {
      "order": 0,
      "parts": {
        "0": {
          "position": {
            "x": 0,
            "y": 0,
            "colSpan": 5,
            "rowSpan": 4
          },
          "metadata": {
            "inputs": [
              {
                "name": "options",
                "value": {
                  "chart": {
                    "metrics": [
                      {
                        "resourceMetadata": {
                          "id": "/subscriptions/${var.subscription_id}/resourceGroups/${azurerm_resource_group.rg.name}/providers/Microsoft.Compute/virtualMachineScaleSets/${azurerm_linux_virtual_machine_scale_set.web_vmss.name}"
                        },
                        "name": "Percentage CPU",
                        "aggregationType": 4,
                        "namespace": "Microsoft.Compute/virtualMachineScaleSets",
                        "metricVisualization": {
                          "displayName": "CPU Percentage"
                        }
                      }
                    ],
                    "title": "VMSS CPU Usage",
                    "visualization": {
                      "chartType": 2,
                      "legendVisualization": {
                        "isVisible": true,
                        "position": 2,
                        "hideSubtitle": false
                      },
                      "axisVisualization": {
                        "x": {
                          "isVisible": true,
                          "axisType": 2
                        },
                        "y": {
                          "isVisible": true,
                          "axisType": 1
                        }
                      }
                    },
                    "timespan": {
                      "relative": {
                        "duration": 86400000
                      },
                      "showUTCTime": false,
                      "grain": 1
                    }
                  }
                }
              },
              {
                "name": "sharedTimeRange",
                "isOptional": true
              }
            ],
            "type": "Extension/HubsExtension/PartType/MonitorChartPart",
            "settings": {}
          }
        },
        "1": {
          "position": {
            "x": 5,
            "y": 0,
            "colSpan": 5,
            "rowSpan": 4
          },
          "metadata": {
            "inputs": [
              {
                "name": "options",
                "value": {
                  "chart": {
                    "metrics": [
                      {
                        "resourceMetadata": {
                          "id": "/subscriptions/${var.subscription_id}/resourceGroups/${azurerm_resource_group.rg.name}/providers/Microsoft.Compute/virtualMachineScaleSets/${azurerm_linux_virtual_machine_scale_set.web_vmss.name}"
                        },
                        "name": "VMAvailabilityMetric",
                        "aggregationType": 4,
                        "namespace": "Microsoft.Compute/virtualMachineScaleSets",
                        "metricVisualization": {
                          "displayName": "VM Availability Metric (Preview)"
                        }
                      }
                    ],
                    "title": "VMSS Instance Availability",
                    "visualization": {
                      "chartType": 2,
                      "legendVisualization": {
                        "isVisible": true,
                        "position": 2,
                        "hideSubtitle": false
                      },
                      "axisVisualization": {
                        "x": {
                          "isVisible": true,
                          "axisType": 2
                        },
                        "y": {
                          "isVisible": true,
                          "axisType": 1
                        }
                      }
                    },
                    "timespan": {
                      "relative": {
                        "duration": 86400000
                      },
                      "showUTCTime": false,
                      "grain": 1
                    }
                  }
                }
              },
              {
                "name": "sharedTimeRange",
                "isOptional": true
              }
            ],
            "type": "Extension/HubsExtension/PartType/MonitorChartPart",
            "settings": {}
          }
        },
        "2": {
          "position": {
            "x": 10,
            "y": 0,
            "colSpan": 5,
            "rowSpan": 4
          },
          "metadata": {
            "inputs": [
              {
                "name": "options",
                "value": {
                  "chart": {
                    "metrics": [
                      {
                        "resourceMetadata": {
                          "id": "/subscriptions/${var.subscription_id}/resourceGroups/${azurerm_resource_group.rg.name}/providers/Microsoft.Sql/servers/${azurerm_mssql_server.sql_server.name}/databases/${azurerm_mssql_database.sql_database.name}"
                        },
                        "name": "dtu_consumption_percent",
                        "aggregationType": 4,
                        "namespace": "Microsoft.Sql/servers/databases",
                        "metricVisualization": {
                          "displayName": "DTU Percentage"
                        }
                      }
                    ],
                    "title": "SQL Database DTU Consumption",
                    "visualization": {
                      "chartType": 2,
                      "legendVisualization": {
                        "isVisible": true,
                        "position": 2,
                        "hideSubtitle": false
                      },
                      "axisVisualization": {
                        "x": {
                          "isVisible": true,
                          "axisType": 2
                        },
                        "y": {
                          "isVisible": true,
                          "axisType": 1
                        }
                      }
                    },
                    "timespan": {
                      "relative": {
                        "duration": 86400000
                      },
                      "showUTCTime": false,
                      "grain": 1
                    }
                  }
                }
              },
              {
                "name": "sharedTimeRange",
                "isOptional": true
              }
            ],
            "type": "Extension/HubsExtension/PartType/MonitorChartPart",
            "settings": {}
          }
        },
        "3": {
          "position": {
            "x": 0,
            "y": 4,
            "colSpan": 5,
            "rowSpan": 4
          },
          "metadata": {
            "inputs": [
              {
                "name": "options",
                "value": {
                  "chart": {
                    "metrics": [
                      {
                        "resourceMetadata": {
                          "id": "/subscriptions/${var.subscription_id}/resourceGroups/${azurerm_resource_group.rg.name}/providers/Microsoft.Storage/storageAccounts/${azurerm_storage_account.storage_account.name}"
                        },
                        "name": "Transactions",
                        "aggregationType": 1,
                        "namespace": "Microsoft.Storage/storageAccounts",
                        "metricVisualization": {
                          "displayName": "Transactions"
                        }
                      }
                    ],
                    "title": "Storage Transactions",
                    "visualization": {
                      "chartType": 2,
                      "legendVisualization": {
                        "isVisible": true,
                        "position": 2,
                        "hideSubtitle": false
                      },
                      "axisVisualization": {
                        "x": {
                          "isVisible": true,
                          "axisType": 2
                        },
                        "y": {
                          "isVisible": true,
                          "axisType": 1
                        }
                      }
                    },
                    "timespan": {
                      "relative": {
                        "duration": 86400000
                      },
                      "showUTCTime": false,
                      "grain": 1
                    }
                  }
                }
              },
              {
                "name": "sharedTimeRange",
                "isOptional": true
              }
            ],
            "type": "Extension/HubsExtension/PartType/MonitorChartPart",
            "settings": {}
          }
        },
        "4": {
          "position": {
            "x": 5,
            "y": 4,
            "colSpan": 5,
            "rowSpan": 4
          },
          "metadata": {
            "inputs": [
              {
                "name": "options",
                "value": {
                  "chart": {
                    "metrics": [
                      {
                        "resourceMetadata": {
                          "id": "/subscriptions/${var.subscription_id}/resourceGroups/${azurerm_resource_group.rg.name}/providers/Microsoft.Compute/virtualMachineScaleSets/${azurerm_linux_virtual_machine_scale_set.web_vmss.name}"
                        },
                        "name": "Network In Total",
                        "aggregationType": 1,
                        "namespace": "Microsoft.Compute/virtualMachineScaleSets",
                        "metricVisualization": {
                          "displayName": "Network In Total"
                        }
                      },
                      {
                        "resourceMetadata": {
                          "id": "/subscriptions/${var.subscription_id}/resourceGroups/${azurerm_resource_group.rg.name}/providers/Microsoft.Compute/virtualMachineScaleSets/${azurerm_linux_virtual_machine_scale_set.web_vmss.name}"
                        },
                        "name": "Network Out Total",
                        "aggregationType": 1,
                        "namespace": "Microsoft.Compute/virtualMachineScaleSets",
                        "metricVisualization": {
                          "displayName": "Network Out Total"
                        }
                      }
                    ],
                    "title": "Network In/Out",
                    "visualization": {
                      "chartType": 2,
                      "legendVisualization": {
                        "isVisible": true,
                        "position": 2,
                        "hideSubtitle": false
                      },
                      "axisVisualization": {
                        "x": {
                          "isVisible": true,
                          "axisType": 2
                        },
                        "y": {
                          "isVisible": true,
                          "axisType": 1
                        }
                      }
                    },
                    "timespan": {
                      "relative": {
                        "duration": 86400000
                      },
                      "showUTCTime": false,
                      "grain": 1
                    }
                  }
                }
              },
              {
                "name": "sharedTimeRange",
                "isOptional": true
              }
            ],
            "type": "Extension/HubsExtension/PartType/MonitorChartPart",
            "settings": {}
          }
        },
        "5": {
          "position": {
            "x": 10,
            "y": 4,
            "colSpan": 5,
            "rowSpan": 4
          },
          "metadata": {
            "inputs": [
              {
                "name": "options",
                "value": {
                  "chart": {
                    "metrics": [
                      {
                        "resourceMetadata": {
                          "id": "/subscriptions/${var.subscription_id}/resourceGroups/${azurerm_resource_group.rg.name}/providers/Microsoft.Sql/servers/${azurerm_mssql_server.sql_server.name}/databases/${azurerm_mssql_database.sql_database.name}"
                        },
                        "name": "connection_successful",
                        "aggregationType": 1,
                        "namespace": "Microsoft.Sql/servers/databases",
                        "metricVisualization": {
                          "displayName": "Successful Connections"
                        }
                      },
                      {
                        "resourceMetadata": {
                          "id": "/subscriptions/${var.subscription_id}/resourceGroups/${azurerm_resource_group.rg.name}/providers/Microsoft.Sql/servers/${azurerm_mssql_server.sql_server.name}/databases/${azurerm_mssql_database.sql_database.name}"
                        },
                        "name": "blocked_by_firewall",
                        "aggregationType": 1,
                        "namespace": "Microsoft.Sql/servers/databases",
                        "metricVisualization": {
                          "displayName": "Blocked By Firewall"
                        }
                      }
                    ],
                    "title": "SQL Database Connections",
                    "visualization": {
                      "chartType": 2,
                      "legendVisualization": {
                        "isVisible": true,
                        "position": 2,
                        "hideSubtitle": false
                      },
                      "axisVisualization": {
                        "x": {
                          "isVisible": true,
                          "axisType": 2
                        },
                        "y": {
                          "isVisible": true,
                          "axisType": 1
                        }
                      }
                    },
                    "timespan": {
                      "relative": {
                        "duration": 86400000
                      },
                      "showUTCTime": false,
                      "grain": 1
                    }
                  }
                }
              },
              {
                "name": "sharedTimeRange",
                "isOptional": true
              }
            ],
            "type": "Extension/HubsExtension/PartType/MonitorChartPart",
            "settings": {}
          }
        }
      }
    }
  },
  "metadata": {
    "model": {
      "timeRange": {
        "value": {
          "relative": {
            "duration": 24,
            "timeUnit": 1
          }
        },
        "type": "MsPortalFx.Composition.Configuration.ValueTypes.TimeRange"
      }
    }
  }
}
DASHBOARD

  depends_on = [
    azurerm_resource_group.rg,
    azurerm_log_analytics_workspace.web_log_analytics,
    azurerm_linux_virtual_machine_scale_set.web_vmss,
    azurerm_mssql_database.sql_database,
    azurerm_storage_account.storage_account,
    azurerm_mssql_server.sql_server
  ]
}

# Create a PowerShell runbook for VM patching
resource "azurerm_automation_runbook" "vm_patching" {
  name                    = "${var.prefix}-vm-patching-runbook"
  location                = azurerm_resource_group.rg.location
  resource_group_name     = azurerm_resource_group.rg.name
  automation_account_name = azurerm_automation_account.web_automation.name
  log_verbose             = true
  log_progress            = true
  description             = "Runbook to apply updates to VMs in the scale set"
  runbook_type            = "PowerShell"
  tags                    = var.tags

  content = <<-EOF
# VM Patching Runbook
# This runbook applies updates to VMs in the scale set

param (
    [Parameter(Mandatory = $false)]
    [string] $ResourceGroupName = "${azurerm_resource_group.rg.name}",
    
    [Parameter(Mandatory = $false)]
    [string] $VMSSName = "${azurerm_linux_virtual_machine_scale_set.web_vmss.name}",
    
    [Parameter(Mandatory = $false)]
    [string] $ClientId = "",
    
    [Parameter(Mandatory = $false)]
    [string] $ClientSecret = "",
    
    [Parameter(Mandatory = $false)]
    [string] $SubscriptionId = "${var.subscription_id}"
)

# Ensures you do not inherit an AzContext in your runbook
Disable-AzContextAutosave -Scope Process

# Connect to Azure with service principal if provided, otherwise use interactive login
# Note: In production, you would use an automation credential asset instead of parameters
if ($ClientId -ne "" -and $ClientSecret -ne "") {
    $SecurePassword = ConvertTo-SecureString $ClientSecret -AsPlainText -Force
    $Credential = New-Object System.Management.Automation.PSCredential ($ClientId, $SecurePassword)
    
    try {
        $AzureContext = (Connect-AzAccount -ServicePrincipal -Credential $Credential -TenantId $TenantId -SubscriptionId $SubscriptionId).Context
        Write-Output "Connected to Azure using service principal"
    } 
    catch {
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}
else {
    Write-Output "No service principal provided. Make sure to configure the automation account with a Run As account or provide credentials."
    try {
        $AzureContext = (Connect-AzAccount -SubscriptionId $SubscriptionId).Context
    }
    catch {
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}

# Set the subscription context
Set-AzContext -SubscriptionId $SubscriptionId

# Get the VM Scale Set
Write-Output "Getting VM Scale Set $VMSSName in resource group $ResourceGroupName"
$vmss = Get-AzVmss -ResourceGroupName $ResourceGroupName -VMScaleSetName $VMSSName

if (!$vmss) {
    Write-Error "VMSS '$VMSSName' not found in resource group '$ResourceGroupName'"
    exit
}

# Get the VMSS instances
$instances = Get-AzVmssVM -ResourceGroupName $ResourceGroupName -VMScaleSetName $VMSSName

Write-Output "Found $($instances.Count) instances in the scale set"

# Process instances in batches to maintain availability
$batchSize = [Math]::Max(1, [Math]::Ceiling($instances.Count * 0.25)) # Update 25% of instances at a time
Write-Output "Will process instances in batches of $batchSize"

$batches = [Math]::Ceiling($instances.Count / $batchSize)

for ($i = 0; $i -lt $batches; $i++) {
    $start = $i * $batchSize
    $end = [Math]::Min(($i + 1) * $batchSize, $instances.Count) - 1
    $currentBatch = $instances[$start..$end]
    
    Write-Output "Processing batch $($i+1) of $batches (instances $($start+1) to $($end+1))"
    
    foreach ($instance in $currentBatch) {
        Write-Output "Starting update for instance $($instance.InstanceId)"
        
        try {
            # Run update command on the VM (for Linux VMs)
            $result = Invoke-AzVmssVMRunCommand -ResourceGroupName $ResourceGroupName `
                -VMScaleSetName $VMSSName `
                -InstanceId $instance.InstanceId `
                -CommandId "RunShellScript" `
                -ScriptString "apt-get update && apt-get upgrade -y"
            
            Write-Output "Update results for instance $($instance.InstanceId):"
            Write-Output $result.Value[0].Message
        }
        catch {
            Write-Error "Failed to update instance $($instance.InstanceId): $_"
        }
    }
    
    # Wait between batches to allow the system to stabilize
    if ($i -lt $batches - 1) {
        $waitTime = 300 # 5 minutes
        Write-Output "Waiting $waitTime seconds before processing next batch..."
        Start-Sleep -Seconds $waitTime
    }
}

Write-Output "VM patching completed"
  EOF

  depends_on = [azurerm_automation_account.web_automation]
}

# Create a schedule for the runbook to run weekly
resource "azurerm_automation_schedule" "weekly_patching" {
  name                    = "${var.prefix}-weekly-patching"
  resource_group_name     = azurerm_resource_group.rg.name
  automation_account_name = azurerm_automation_account.web_automation.name
  frequency               = "Week"
  interval                = 1
  timezone                = "UTC"
  start_time              = timeadd(timestamp(), "168h") # Start one week from now
  description             = "Weekly schedule for VM patching"
  week_days               = ["Sunday"] # Run on Sundays when traffic is likely lower

  depends_on = [azurerm_automation_account.web_automation]
}

# Link the runbook to the schedule
resource "azurerm_automation_job_schedule" "vm_patching_schedule" {
  resource_group_name     = azurerm_resource_group.rg.name
  automation_account_name = azurerm_automation_account.web_automation.name
  schedule_name           = azurerm_automation_schedule.weekly_patching.name
  runbook_name            = azurerm_automation_runbook.vm_patching.name

  depends_on = [
    azurerm_automation_runbook.vm_patching,
    azurerm_automation_schedule.weekly_patching
  ]
}
