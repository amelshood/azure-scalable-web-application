variable "prefix" {
  description = "Prefix to be used for all resources"
  type        = string
  default     = "sample"
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus"
}

variable "vnet_name" {
  type    = string
  default = "vnet"
}

variable "web_subnet_name" {
  type    = string
  default = "web-subnet"
}

variable "db_subnet_name" {
  type    = string
  default = "db-subnet"
}

variable "web_vm_name_prefix" {
  type    = string
  default = "web-vm"
}

variable "sql_server_name" {
  type    = string
  default = "sqlserver"
}

variable "sql_database_name" {
  type    = string
  default = "webappdb"
}

variable "storage_account_name" {
  type    = string
  default = "storage"
}

variable "admin_username" {
  type = string
  default = "adminuser"
}

variable "admin_password" {
  type = string
  sensitive = true
}

variable "admin_cidr_block" {
  type    = string
  description = "Admin CIDR block for remote access"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {
    Environment = "Dev"
    Project     = "AzureWebApp"
    Owner       = "Owner's Name"
    CreatedBy   = "Terraform"
    Purpose     = "WebApplication"
  }
}

variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key file"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "admin_email" {
  description = "Admin email"
  type        = string
  default     = "email@example.com"
}