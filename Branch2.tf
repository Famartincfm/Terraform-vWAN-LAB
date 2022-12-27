################################
# Branch2 vNET
################################

# Vnet 
resource "azurerm_virtual_network" "vNET_4" {
  count = "${var.VHUB_IPsec == "2" ? 1 : 0}"
  name                = "vNET_4"
  resource_group_name = azurerm_resource_group.resourcegroup.name
  location            = var.Remote_branch_location
  address_space       = ["172.17.0.0/16"]
}

#Subnet
resource "azurerm_subnet" "vNET_4_Sub1" {
 
 count = "${var.VHUB_IPsec == "2" ? 1 : 0}"
  name                 = "vNET_4_Sub1"
  resource_group_name  = azurerm_resource_group.resourcegroup.name
  virtual_network_name = azurerm_virtual_network.vNET_4[count.index].name
  address_prefixes     = ["172.17.1.0/24"]
}

# Gateway subnet for VPN Gateway
resource "azurerm_subnet" "vNET_4_GW_Sub" {
 
 count = "${var.VHUB_IPsec == "2" ? 1 : 0}"
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.resourcegroup.name
  virtual_network_name = azurerm_virtual_network.vNET_4[count.index].name
  address_prefixes     = ["172.17.100.0/24"]
}

################################
# NSG
################################

resource "azurerm_network_security_group" "Branch2NSG" {
  count = "${var.VHUB_IPsec == "2" ? 1 : 0}"
  name                = "Branch2NSG"
  location            = var.Remote_branch_location
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
    source_address_prefix                      = "${local.ifconfig_co_json.ip}/32"
    source_port_range                          = "*"
  }
}

# Apply NSG to Subnets
resource "azurerm_subnet_network_security_group_association" "nsg_4_Sub1" {
  count = "${var.VHUB_IPsec == "2" ? 1 : 0}"
  depends_on = [azurerm_network_security_group.Branch2NSG]
  subnet_id                 = azurerm_subnet.vNET_4_Sub1[count.index].id
  network_security_group_id = azurerm_network_security_group.Branch2NSG[0].id
}


################################
# Virtual Machine Network
################################

#PublicIP - to connect over RDP
resource "azurerm_public_ip" "VM4_PIP" {

  count = "${var.vm_Username != "" && var.VHUB_IPsec == "2" ? 1 : 0}"

  name                = "VM4_PIP"
  resource_group_name = azurerm_resource_group.resourcegroup.name
  location            = var.Remote_branch_location
  allocation_method   = "Dynamic"
}


#NetworkInterface
resource "azurerm_network_interface" "VM4_NIC" {
  count = "${var.vm_Username != "" && var.VHUB_IPsec == "2" ? 1 : 0}"
  name                = "VM4_NIC"
  location            = var.Remote_branch_location
  resource_group_name = azurerm_resource_group.resourcegroup.name

  ip_configuration {
    name                          = "VM3NIC"
    subnet_id                     = azurerm_subnet.vNET_4_Sub1[count.index].id
    private_ip_address_allocation = "Static"
	  private_ip_address            = "172.17.1.5"
    public_ip_address_id = azurerm_public_ip.VM4_PIP[0].id ## Associate public IP
  }
}


################################
# Virtual Machine
################################


resource "azurerm_windows_virtual_machine" "VM4" {
 
count = "${var.vm_Username != "" && var.VHUB_IPsec == "2" ? 1 : 0}"
  name                = "VM4"
  resource_group_name = azurerm_resource_group.resourcegroup.name
  location            = var.Remote_branch_location
  size                = var.vmSize
  admin_username      = var.vm_Username
  admin_password      = var.vm_password

  network_interface_ids = [
      azurerm_network_interface.VM4_NIC[0].id,
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
  shared-key2 = "123456"
  branch2_asn = 65401
}

# Public IP for VPN Gateway (branch)
resource "azurerm_public_ip" "GW_Branch2_PIP" {
  count = "${var.VHUB_IPsec == "2" ? 1 : 0}"
  name                = "GW_Branch2_PIP"
  location            = var.Remote_branch_location
  resource_group_name  = azurerm_resource_group.resourcegroup.name

  allocation_method = "Dynamic"
  #tags              = var.tags
}

# VPN Gateway
resource "azurerm_virtual_network_gateway" "GW_Branch2" {
  count = "${var.VHUB_IPsec == "2" ? 1 : 0}"
  location            = var.Remote_branch_location
  name                = "GW_Branch2"
  resource_group_name  = azurerm_resource_group.resourcegroup.name
  vpn_type            = "RouteBased"
  generation          = "Generation1"
  sku                 = "VpnGw1"
  type                = "Vpn"
  enable_bgp          = true
  active_active       = false
  bgp_settings {
    asn = local.branch2_asn
  }
  ip_configuration {
    public_ip_address_id = azurerm_public_ip.GW_Branch2_PIP[0].id
    subnet_id            = azurerm_subnet.vNET_4_GW_Sub[count.index].id
  }
}

# Local network gateway (LNG) to define the vWAN HQ Hub VPN
#tunnel_ips - The list of tunnel public IP addresses which belong to the pre-defined VPN Gateway IP configuration.
#default_ips - The list of default BGP peering addresses which belong to the pre-defined VPN Gateway IP configuration

## LNG is already created from Branch1
/*
resource "azurerm_local_network_gateway" "HQ_HUB_VPN_2" {

  count = "${var.VHUB_IPsec == "2" ? 1 : 0}"
  address_space       = ["10.0.0.0/8"]
  gateway_address     = tolist(azurerm_vpn_gateway.VPNGW-HUB-HQ.bgp_settings[0].instance_0_bgp_peering_address[0].tunnel_ips)[1]
  location            = var.Remote_branch_location
  name                = "HQ_HUB_VPN_2"
  resource_group_name  = azurerm_resource_group.resourcegroup.name
  bgp_settings {
    asn                 = azurerm_vpn_gateway.VPNGW-HUB-HQ.bgp_settings[0].asn
    bgp_peering_address = tolist(azurerm_vpn_gateway.VPNGW-HUB-HQ.bgp_settings[0].instance_0_bgp_peering_address[0].default_ips)[0]
  }
}
*/

# VPN Connection
resource "azurerm_virtual_network_gateway_connection" "Branch2-to-HubHQ" {
count = "${var.VHUB_IPsec == "2" ? 1 : 0}"  
  name                = "Branch2-to-HubHQ"
  location            = var.Remote_branch_location
  resource_group_name = azurerm_resource_group.resourcegroup.name

  type       = "IPsec"
  enable_bgp = true

  virtual_network_gateway_id = azurerm_virtual_network_gateway.GW_Branch2[0].id
  local_network_gateway_id   = azurerm_local_network_gateway.HQ_HUB_VPN[0].id

  shared_key = local.shared-key2
}




