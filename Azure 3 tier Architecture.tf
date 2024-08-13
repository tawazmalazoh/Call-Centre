/*
TEAM A TERRAFORM 
3- Tier Azure achitecure
CLOUD COMPUTING PROJECT
*/

# uses the resourse manager with free default settings
provider "azurerm" {
  features = {}  
}

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "banking-system-rg"
  location = "East US"
}

# Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "banking-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

/* Subnets  DMZ   
# Security Boundary:-security boundary between the external public network (e.g., the internet) and the internal private network
# Controlled Access:-This minimizes the risk of exposing sensitive internal resources directly to the internet
*/
resource "azurerm_subnet" "dmz" {
  name                 = "dmz-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}


# WEB TIER
resource "azurerm_subnet" "web" {
  name                 = "web-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}


# APPLICATION TIER
resource "azurerm_subnet" "business" {
  name                 = "business-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.3.0/24"]
}


# DATA TIER
resource "azurerm_subnet" "data" {
  name                 = "data-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.4.0/24"]
}



# Network Security Group for NVAs
resource "azurerm_network_security_group" "nsg" {
  name                = "banking-system-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Network Virtual Appliance (NVA) for DMZ
resource "azurerm_network_interface" "nva_nic" {
  name                = "nva-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.dmz.id
    private_ip_address_allocation = "Dynamic"
  }
}


#  LINUX VIRTUAL MACHINE
resource "azurerm_linux_virtual_machine" "nva" {
  name                  = "nva-vm"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  size                  = "Standard_DS1_v2"
  admin_username        = "adminuser"
  admin_password        = "P@ssw0rd1234!"
  network_interface_ids = [azurerm_network_interface.nva_nic.id]

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
}





# Bastion Host
/*
Bastion Host is a special-purpose server designed to provide secure access to virtual machines (VMs) in a virtual network, 
especially in scenarios where direct exposure of these VMs to the internet is not desirable.
*/




# Public IP for Bastion Host
resource "azurerm_public_ip" "bastion" {
  name                = "bastion-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}




# Azure Bastion Host
resource "azurerm_bastion_host" "bastion" {
  name                = "bastion-host"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_name            = "bastion-${azurerm_resource_group.rg.name}.eastus.azure.com"

  ip_configuration {
    name                 = "bastion-ip"
    subnet_id            = azurerm_subnet.dmz.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }
}






# Front-End Gateway Load Balancer
resource "azurerm_public_ip" "frontend_lb_pip" {
  name                = "frontend-lb-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_lb" "frontend_lb" {
  name                = "frontend-lb"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"
  frontend_ip_configuration {
    name                 = "frontendConfig"
    public_ip_address_id = azurerm_public_ip.frontend_lb_pip.id
  }
}

resource "azurerm_lb_backend_address_pool" "frontend_pool" {
  name                = "frontend-backend-pool"
  resource_group_name = azurerm_resource_group.rg.name
  loadbalancer_id     = azurerm_lb.frontend_lb.id
}




/*
# Web-Servers (Azure Scale Sets with VMs)
VM Scale Sets are designed for deploying, managing, and scaling a group of identical VMs.
-Automatic Scaling
-Load Balancing
-Uniform Configuration
*/

resource "azurerm_linux_virtual_machine_scale_set" "web_servers" {
  name                = "web-vmss"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard_DS1_v2"
  instances           = 2
  admin_username      = "adminuser"
  admin_password      = "P@ssw0rd1234!"
  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  network_interface {
    name    = "web-nic"
    primary = true
    ip_configuration {
      name                                   = "internal"
      subnet_id                              = azurerm_subnet.web.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.frontend_pool.id]
    }
  }
}




# Backend Load Balancer
resource "azurerm_public_ip" "backend_lb_pip" {
  name                = "backend-lb-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_lb" "backend_lb" {
  name                = "backend-lb"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"
  frontend_ip_configuration {
    name                 = "backendConfig"
    public_ip_address_id = azurerm_public_ip.backend_lb_pip.id
  }
}

resource "azurerm_lb_backend_address_pool" "backend_pool" {
  name                = "backend-backend-pool"
  resource_group_name = azurerm_resource_group.rg.name
  loadbalancer_id     = azurerm_lb.backend_lb.id
}


 

# Business Tier Servers (Azure Scale Sets with VMs)
resource "azurerm_linux_virtual_machine_scale_set" "business_servers" {
  name                = "business-vmss"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard_DS1_v2"
  instances           = 2
  admin_username      = "adminuser"
  admin_password      = "P@ssw0rd1234!"
  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  network_interface {
    name    = "business-nic"
    primary = true
    ip_configuration {
      name                                   = "internal"
      subnet_id                              = azurerm_subnet.business.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.backend_pool.id]
    }
  }
}



# Data Tier - SQL Servers (Primary and Secondary)
resource "azurerm_sql_server" "sql_primary" {
  name                         = "primary-sql-server"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  version                      = "12.0"
  administrator_login          = "sqladmin"
  administrator_login_password = "P@ssw0rd1234!"
}

resource "azurerm_sql_server" "sql_secondary" {
  name                         = "secondary-sql-server"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  version                      = "12.0"
  administrator_login          = "sqladmin"
  administrator_login_password = "P@ssw0rd1234!"
}






# Frontend Load Balancer for Web Tier
resource "azurerm_lb" "web_lb" {
  name                = "web-tier-lb"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"
  frontend_ip_configuration {
    name                 = "public-ip"
    public_ip_address_id = azurerm_public_ip.web_lb.id
  }
}



# Public IP for Web Load Balancer
resource "azurerm_public_ip" "web_lb" {
  name                = "web-lb-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}



# Backend Load Balancer for Business Tier
resource "azurerm_lb" "business_lb" {
  name                = "business-tier-lb"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"
  frontend_ip_configuration {
    name                 = "internal-ip"
    subnet_id            = azurerm_subnet.business.id
  }
}






# SQL Server for Data Tier (Primary)
resource "azurerm_mssql_server" "primary" {
  name                         = "primary-sql-server"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  version                      = "12.0"
  administrator_login          = "sqladmin"
  administrator_login_password = "Password1234!"
  minimum_tls_version          = "1.2"

  identity {
    type = "SystemAssigned"
  }
}




# SQL Server for Data Tier (Secondary)
resource "azurerm_mssql_server" "secondary" {
  name                         = "secondary-sql-server"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = "West US"
  version                      = "12.0"
  administrator_login          = "sqladmin"
  administrator_login_password = "Password1234!"
  minimum_tls_version          = "1.2"

  identity {
    type = "SystemAssigned"
  }
}


# Output the public IP address of the Bastion Host
output "bastion_public_ip" {
  description = "The public IP address of the Bastion Host"
  value       = azurerm_public_ip.bastion_pip.ip_address
}

# Output the DNS name of the Bastion Host
output "bastion_dns_name" {
  description = "The DNS name of the Bastion Host"
  value       = azurerm_bastion_host.bastion.dns_name
}

# Output the ID of the Web Server VM Scale Set
output "web_vmss_id" {
  description = "The ID of the Web Server VM Scale Set"
  value       = azurerm_linux_virtual_machine_scale_set.web_servers.id
}
