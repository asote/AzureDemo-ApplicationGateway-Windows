provider "azurerm" {}

# Create a resource group
resource "azurerm_resource_group" "network" {
  name     = "asotelovmssdemo"
  location = "centralus"

  "tags" {
    name = "Antonio Sotelo"
  }
}

# Create virtual network
resource "azurerm_virtual_network" "vnet" {
  name                = "vnetdemo1"
  resource_group_name = "${azurerm_resource_group.network.name}"
  address_space       = ["10.0.0.0/16"]
  location            = "${azurerm_resource_group.network.location}"

  "tags" {
    name = "Antonio Sotelo"
  }
}

resource "azurerm_subnet" "sub1" {
  name                 = "subnet1"
  resource_group_name  = "${azurerm_resource_group.network.name}"
  virtual_network_name = "${azurerm_virtual_network.vnet.name}"
  address_prefix       = "10.0.1.0/24"
}

resource "azurerm_subnet" "sub2" {
  name                      = "subnet2"
  resource_group_name       = "${azurerm_resource_group.network.name}"
  virtual_network_name      = "${azurerm_virtual_network.vnet.name}"
  address_prefix            = "10.0.2.0/24"
  network_security_group_id = "${azurerm_network_security_group.security_group.id}"
}

resource "azurerm_public_ip" "pip" {
  name                         = "my-pip"
  location                     = "${azurerm_resource_group.network.location}"
  resource_group_name          = "${azurerm_resource_group.network.name}"
  public_ip_address_allocation = "dynamic"

  "tags" {
    name = "Antonio Sotelo"
  }
}

# Create an application gateway
resource "azurerm_application_gateway" "network" {
  name                = "my-application-gateway"
  resource_group_name = "${azurerm_resource_group.network.name}"
  location            = "${azurerm_resource_group.network.location}"

  sku {
    name     = "Standard_Small"
    tier     = "Standard"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "my-gateway-ip-configuration"
    subnet_id = "${azurerm_virtual_network.vnet.id}/subnets/${azurerm_subnet.sub1.name}"
  }

  frontend_port {
    name = "${azurerm_virtual_network.vnet.name}-feport"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "${azurerm_virtual_network.vnet.name}-feip"
    public_ip_address_id = "${azurerm_public_ip.pip.id}"
  }

  backend_address_pool {
    name            = "${azurerm_virtual_network.vnet.name}-beap"
    ip_address_list = ["10.0.2.4", "10.0.2.5"]
  }

  backend_http_settings {
    name                  = "${azurerm_virtual_network.vnet.name}-be-htst"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 1
  }

  http_listener {
    name                           = "${azurerm_virtual_network.vnet.name}-httplstn"
    frontend_ip_configuration_name = "${azurerm_virtual_network.vnet.name}-feip"
    frontend_port_name             = "${azurerm_virtual_network.vnet.name}-feport"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "${azurerm_virtual_network.vnet.name}-rqrt"
    rule_type                  = "Basic"
    http_listener_name         = "${azurerm_virtual_network.vnet.name}-httplstn"
    backend_address_pool_name  = "${azurerm_virtual_network.vnet.name}-beap"
    backend_http_settings_name = "${azurerm_virtual_network.vnet.name}-be-htst"
  }

  "tags" {
    name = "Antonio Sotelo"
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
      name      = "IPConfiguration"
      subnet_id = "${azurerm_subnet.sub2.id}"

      #load_balancer_backend_address_pool_ids = ["${module.loadbalancer.azurerm_lb_backend_address_pool_id}"]
    }
  }

  extension {
    name                 = "vmssextension"
    publisher            = "Microsoft.Compute"
    type                 = "CustomScriptExtension"
    type_handler_version = "1.8"

    settings = <<SETTINGS
    {
        "fileUris": [ "https://raw.githubusercontent.com/asote/AzureDemo-ApplicationGateway-Windows/master/Configure-WebServer.ps1" ],
        "commandToExecute": "powershell -ExecutionPolicy Unrestricted -File Configure-WebServer.ps1"
    }
    SETTINGS
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

//Outputs

output "sql_server_fqdn" {
  value = "${azurerm_sql_server.server.fully_qualified_domain_name}"
}

output "application_gateway_public_IP" {
  value = "${azurerm_public_ip.pip.ip_address}"
}