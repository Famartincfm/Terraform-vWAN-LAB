################################
# Branch vNET
################################

# Vnet 
resource "azurerm_virtual_network" "vNET_3" {
  name                = "vNET_3"
  resource_group_name = azurerm_resource_group.resourcegroup.name
  location            = var.Branch_location
  address_space       = ["172.16.0.0/16"]
}

#Subnet
resource "azurerm_subnet" "vNET_3_Sub1" {
  name                 = "vNET_3_Sub1"
  resource_group_name  = azurerm_resource_group.resourcegroup.name
  virtual_network_name = azurerm_virtual_network.vNET_3.name
  address_prefixes     = ["172.16.1.0/24"]
}

# Gateway subnet for VPN Gateway
resource "azurerm_subnet" "vNET_3_GW_Sub" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.resourcegroup.name
  virtual_network_name = azurerm_virtual_network.vNET_3.name
  address_prefixes     = ["172.16.100.0/24"]
}

################################
# NSG for Subnet 3
################################

resource "azurerm_network_security_group" "BranchNSG" {
  name                = "BranchNSG"
  location            = var.Branch_location
  resource_group_name = azurerm_resource_group.resourcegroup.name

  security_rule {
    access                                     = "Allow"
    description                                = "Allow from External IP"
    destination_address_prefix                 = "*"
    destination_port_range                     = "*"
    direction                                  = "Inbound"
    name                                       = "externalCidr"
    priority                                   = 100
    protocol                                   = "*"
    source_address_prefix                      = local.cidr
    source_port_range                          = "*"
  }
}

# Apply NSG to Subnets
resource "azurerm_subnet_network_security_group_association" "nsg_3_Sub1" {
  subnet_id                 = azurerm_subnet.vNET_3_Sub1.id
  network_security_group_id = azurerm_network_security_group.BranchNSG.id
}


################################
# Virtual Machine Network
################################

#PublicIP - to connect over RDP
resource "azurerm_public_ip" "VM3_PIP" {
  name                = "VM3_PIP"
  resource_group_name = azurerm_resource_group.resourcegroup.name
  location            = var.Branch_location
  allocation_method   = "Dynamic"
}


#NetworkInterface
resource "azurerm_network_interface" "VM3_NIC" {
  name                = "VM3_NIC"
  location            = var.Branch_location
  resource_group_name = azurerm_resource_group.resourcegroup.name

  ip_configuration {
    name                          = "VM3NIC"
    subnet_id                     = azurerm_subnet.vNET_3_Sub1.id
    private_ip_address_allocation = "Static"
	  private_ip_address            = "172.16.1.5"
    public_ip_address_id = azurerm_public_ip.VM3_PIP.id ## Associate public IP
  }
}


################################
# Virtual Machine
################################


resource "azurerm_windows_virtual_machine" "VM3" {
 

  name                = "VM3"
  resource_group_name = azurerm_resource_group.resourcegroup.name
  location            = var.Branch_location
  size                = var.vmSize
  admin_username      = var.vm_username
  admin_password      = var.vm_password

  network_interface_ids = [
      azurerm_network_interface.VM3_NIC.id,
  ]

  os_disk {
      caching              = "ReadWrite"
      storage_account_type = "Standard_LRS"
      disk_size_gb = 32
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter-smalldisk"
    version   = "latest"
  }
}

################################
# VPN GW
################################

locals {
  shared-key = "123456"
  branch_asn = 65400
}

# Public IP for VPN Gateway (branch)
resource "azurerm_public_ip" "GW_Branch_PIP" {
  name                = "GW_Branch_PIP"
  location            = var.Branch_location
  resource_group_name  = azurerm_resource_group.resourcegroup.name

  allocation_method = "Dynamic"
  #tags              = var.tags
}

# VPN Gateway
resource "azurerm_virtual_network_gateway" "GW_Branch" {
  location            = var.Branch_location
  name                = "GW_Branch"
  resource_group_name  = azurerm_resource_group.resourcegroup.name
  vpn_type            = "RouteBased"
  generation          = "Generation1"
  sku                 = "VpnGw1"
  type                = "Vpn"
  enable_bgp          = true
  active_active       = false
  bgp_settings {
    asn = local.branch_asn
  }
  ip_configuration {
    public_ip_address_id = azurerm_public_ip.GW_Branch_PIP.id
    subnet_id            = azurerm_subnet.vNET_3_GW_Sub.id
  }
}

# Local network gateway (LNG) to define the vWAN HQ Hub VPN
#tunnel_ips - The list of tunnel public IP addresses which belong to the pre-defined VPN Gateway IP configuration.
#default_ips - The list of default BGP peering addresses which belong to the pre-defined VPN Gateway IP configuration
resource "azurerm_local_network_gateway" "HQ_HUB_VPN" {

  address_space       = ["10.0.0.0/8"]
  gateway_address     = tolist(azurerm_vpn_gateway.VPNGW-HUB-HQ.bgp_settings[0].instance_0_bgp_peering_address[0].tunnel_ips)[1]
  location            = var.Branch_location
  name                = "HQ_HUB_VPN"
  resource_group_name  = azurerm_resource_group.resourcegroup.name
  bgp_settings {
    asn                 = azurerm_vpn_gateway.VPNGW-HUB-HQ.bgp_settings[0].asn
    bgp_peering_address = tolist(azurerm_vpn_gateway.VPNGW-HUB-HQ.bgp_settings[0].instance_0_bgp_peering_address[0].default_ips)[0]
  }
}

# VPN Connection
resource "azurerm_virtual_network_gateway_connection" "Branch-to-HubHQ" {
  name                = "Branch-to-HubHQ"
  location            = var.Branch_location
  resource_group_name = azurerm_resource_group.resourcegroup.name

  type       = "IPsec"
  enable_bgp = true

  virtual_network_gateway_id = azurerm_virtual_network_gateway.GW_Branch.id
  local_network_gateway_id   = azurerm_local_network_gateway.HQ_HUB_VPN.id

  shared_key = local.shared-key
}





