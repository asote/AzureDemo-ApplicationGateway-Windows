# AzureDemo-ApplicationGateway-Windows
Azure Application Gateway -Windows VMs - using Terraform v0.11.2

This will create a resource group containing 1 vnet, 1 subnet, 1 application gateway, 1 virtual machine scale set with 2 Windows instances configured with IIS, an Azure SQL database and a Windows jumbox.

IIS is configured with an ASP.Net application to run a CPU load and database connectivity tests.


# Note:
To clear the following error:

module.windowsservers.output.public_ip_address: Resource 'azurerm_public_ip.vm' does not have attribute 'ip_address' for variable 'azurerm_public_ip.vm.*.ip_address'

Set environment variable TF_WARN_OUTPUT_ERRORS=1. This was added in Terraform 0.11.1 and referenced by https://github.com/hashicorp/terraform/blob/v0.11.2/CHANGELOG.md#0111-november-30-2017.
