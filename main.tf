provider "azurerm" {
  version = "~>0.2.2"
}

// Create Resource Group
resource "azurerm_resource_group" "network" {
  name     = "asoteloappgwdemo"
  location = "centralus"

  "tags" {
    name = "Antonio Sotelo"
  }
}

// Create Vnet
resource "azurerm_virtual_network" "vnet" {
  name                = "vnetdemo1"
  location            = "${azurerm_resource_group.network.location}"
  address_space       = ["10.0.0.0/16"]
  resource_group_name = "${azurerm_resource_group.network.name}"
  dns_servers         = ["8.8.8.8"]

  "tags" {
    name = "Antonio Sotelo"
  }
}

// Create app gw subnet
resource "azurerm_subnet" "agsubnet" {
  name                      = "subnet1"
  virtual_network_name      = "${azurerm_virtual_network.vnet.name}"
  resource_group_name       = "${azurerm_resource_group.network.name}"
  address_prefix            = "10.0.1.0/24"
}

// Create vmss subnet
resource "azurerm_subnet" "subnet" {
  name                      = "subnet2"
  virtual_network_name      = "${azurerm_virtual_network.vnet.name}"
  resource_group_name       = "${azurerm_resource_group.network.name}"
  address_prefix            = "10.0.2.0/24"
  network_security_group_id = "${azurerm_network_security_group.security_group.id}"
}

// Create NSG
resource "azurerm_network_security_group" "security_group" {
  name                = "subnet2access"
  location            = "${azurerm_resource_group.network.location}"
  resource_group_name = "${azurerm_resource_group.network.name}"

  "tags" {
    name = "Antonio Sotelo"
  }
}

// Create NSG rule for RDP

resource "azurerm_network_security_rule" "security_rule_rdp" {
  name                        = "rdp"
  priority                    = 101
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3389"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = "${azurerm_resource_group.network.name}"
  network_security_group_name = "${azurerm_network_security_group.security_group.name}"
}

resource "azurerm_public_ip" "pip" {
  name                         = "my-pip"
  location                     = "${azurerm_resource_group.network.location}"
  resource_group_name          = "${azurerm_resource_group.network.name}"
  public_ip_address_allocation = "dynamic"
}

# Create an application gateway
resource "azurerm_application_gateway" "network" {
  name                = "my-application-gateway"
  resource_group_name = "${azurerm_resource_group.network.name}"
  location            = "${azurerm_resource_group.network.location}"

  sku {
    name           = "Standard_Small"
    tier           = "Standard"
    capacity       = 2
  }

  gateway_ip_configuration {
      name         = "my-gateway-ip-configuration"
      subnet_id    = "${azurerm_virtual_network.vnet.id}/subnets/${azurerm_subnet.agsubnet.name}"
  }

  frontend_port {
      name         = "${azurerm_virtual_network.vnet.name}-feport"
      port         = 80
  }

  frontend_ip_configuration {
      name         = "${azurerm_virtual_network.vnet.name}-feip"  
      public_ip_address_id = "${azurerm_public_ip.pip.id}"
  }

  backend_address_pool {
      name = "${azurerm_virtual_network.vnet.name}-beap"
      ip_address_list = ["10.0.2.5","10.0.2.6"]
  }

  backend_http_settings {
      name                  = "${azurerm_virtual_network.vnet.name}-be-htst"
      cookie_based_affinity = "Disabled"
      port                  = 80
      protocol              = "Http"
     request_timeout        = 1
  }

  http_listener {
        name                                  = "${azurerm_virtual_network.vnet.name}-httplstn"
        frontend_ip_configuration_name        = "${azurerm_virtual_network.vnet.name}-feip"
        frontend_port_name                    = "${azurerm_virtual_network.vnet.name}-feport"
        protocol                              = "Http"
  }

  request_routing_rule {
          name                       = "${azurerm_virtual_network.vnet.name}-rqrt"
          rule_type                  = "Basic"
          http_listener_name         = "${azurerm_virtual_network.vnet.name}-httplstn"
          backend_address_pool_name  = "${azurerm_virtual_network.vnet.name}-beap"
          backend_http_settings_name = "${azurerm_virtual_network.vnet.name}-be-htst"
  }
}


// Add virtual machine scale set
resource "azurerm_virtual_machine_scale_set" "vm-windows" {
  name                = "vmscaleset1"
  location            = "${azurerm_resource_group.network.location}"
  resource_group_name = "${azurerm_resource_group.network.name}"
  upgrade_policy_mode = "Manual"

  tags {
    name = "Antonio Sotelo"
  }

  sku {
    name     = "Standard_DS2"
    tier     = "Standard"
    capacity = "2"
  }

  storage_profile_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }

  storage_profile_os_disk {
    name              = ""
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  storage_profile_data_disk {
    lun           = 0
    caching       = "ReadWrite"
    create_option = "Empty"
    disk_size_gb  = 40
  }

  os_profile {
    computer_name_prefix = "vmss-"
    admin_username       = "azureuser"
    admin_password       = "T3rr@f0rm1$C00l!"
  }

  network_profile {
    name    = "vmssetworkprofile"
    primary = true

    ip_configuration {
      name                                   = "IPConfiguration"
      subnet_id                              = "${azurerm_subnet.agsubnet.id}"
    }
  }

  extension {
    name                 = "vmssextension"
    publisher            = "Microsoft.Compute"
    type                 = "CustomScriptExtension"
    type_handler_version = "1.8"

    settings = <<SETTINGS
    {
        "fileUris": [ "https://raw.githubusercontent.com/asote/AzureDemo-VMSS-Windows/master/configurations/Configure-WebServer.ps1" ],
        "commandToExecute": "powershell -ExecutionPolicy Unrestricted -File Configure-WebServer.ps1"
    }
    SETTINGS
  }
}

// Add jumpbox
module "windowsservers" {
  source              = "Azure/compute/azurerm"
  resource_group_name = "${azurerm_resource_group.network.name}"
  location            = "${azurerm_resource_group.network.location}"
  vm_hostname         = "jumpbox1"
  admin_password      = "C0mplxP@s$w0rd!"
  public_ip_dns       = ["jumpbox1"]
  nb_public_ip        = "1"
  remote_port         = "3389"
  nb_instances        = "1"
  vm_os_publisher     = "MicrosoftWindowsServer"
  vm_os_offer         = "WindowsServer"
  vm_os_sku           = "2012-R2-Datacenter"
  vm_size             = "Standard_DS2_V2"
  vnet_subnet_id      = "${azurerm_subnet.subnet.id}"

  tags {
    name = "Antonio Sotelo"
  }
}

// Add Azure SQL Database
resource "azurerm_sql_database" "db" {
  name                = "Demo"
  resource_group_name = "${azurerm_resource_group.network.name}"
  location            = "${azurerm_resource_group.network.location}"
  edition             = "Basic"
  server_name         = "${azurerm_sql_server.server.name}"

  tags {
    name = "Antonio Sotelo"
  }
}

resource "azurerm_sql_server" "server" {
  name                         = "dbdemo01"
  resource_group_name          = "${azurerm_resource_group.network.name}"
  location                     = "${azurerm_resource_group.network.location}"
  version                      = "12.0"
  administrator_login          = "dbuser"
  administrator_login_password = "T3rr@f0rm!P0w3r"

  tags {
    name = "Antonio Sotelo"
  }
}

resource "azurerm_sql_firewall_rule" "fw" {
  name                = "dbdemo1firewallrules"
  resource_group_name = "${azurerm_resource_group.network.name}"
  server_name         = "${azurerm_sql_server.server.name}"
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "0.0.0.0"
}

//Outputs
output "jumpbox_public_name" {
  value = "${module.windowsservers.public_ip_dns_name}"
}

output "jumpbox_public_ip" {
  value = "${module.windowsservers.public_ip_address}"
}

output "jumpbox_private_ips" {
  value = "${module.windowsservers.network_interface_private_ip}"
}

output "sql_server_fqdn" {
  value = "${azurerm_sql_server.server.fully_qualified_domain_name}"
}
