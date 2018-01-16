provider "azurerm" {}

# Create a resource group
resource "azurerm_resource_group" "rg" {
  name     = "my-rg-application-gateway-12345"
  location = "West US"
}

# Create a application gateway in the web_servers resource group
resource "azurerm_virtual_network" "vnet" {
  name                = "my-vnet-12345"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  address_space       = ["10.254.0.0/16"]
  location            = "${azurerm_resource_group.rg.location}"
}

resource "azurerm_subnet" "sub1" {
  name                 = "my-subnet-1"
  resource_group_name  = "${azurerm_resource_group.rg.name}"
  virtual_network_name = "${azurerm_virtual_network.vnet.name}"
  address_prefix       = "10.254.0.0/24"
}

resource "azurerm_subnet" "sub2" {
  name                 = "my-subnet-2"
  resource_group_name  = "${azurerm_resource_group.rg.name}"
  virtual_network_name = "${azurerm_virtual_network.vnet.name}"
  address_prefix       = "10.254.2.0/24"
}

resource "azurerm_public_ip" "pip" {
  name                         = "my-pip-12345"
  location                     = "${azurerm_resource_group.rg.location}"
  resource_group_name          = "${azurerm_resource_group.rg.name}"
  public_ip_address_allocation = "dynamic"
}

# Create an application gateway
resource "azurerm_application_gateway" "network" {
  name                = "my-application-gateway-12345"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  location            = "West US"

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
    name = "${azurerm_virtual_network.vnet.name}-beap"
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
}
